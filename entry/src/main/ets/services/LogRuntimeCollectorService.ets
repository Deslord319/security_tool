import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { AppInfo } from '../constants/AppConstants'
import { LogEntry, LogEventType } from '../models/DataModels'
import { LogAuditService } from './LogAuditService'
import { LogStorageService } from './LogStorageService'

const TAG = 'LogRuntimeCollector'
const DOMAIN = 0x0006

export interface LogRuntimeCollectorStatus {
  running: boolean
  subscribed: boolean
}

export class LogRuntimeCollectorService {
  private static context: common.UIAbilityContext | null = null
  private static initialized: boolean = false
  private static running: boolean = false

  private static pendingEntries: LogEntry[] = []
  private static flushTimerId: number = -1
  private static isFlushingEntries: boolean = false

  private static readonly BATCH_FLUSH_INTERVAL_MS: number = 500
  private static readonly MAX_PENDING_ENTRIES: number = 1200
  private static setTimerFn: (task: () => void, delayMs: number) => number =
    (task: () => void, delayMs: number): number => setTimeout(task, delayMs)
  private static clearTimerFn: (timerId: number) => void =
    (timerId: number): void => clearTimeout(timerId)
  private static persistEntriesFn: (entries: LogEntry[]) => Promise<boolean> =
    (entries: LogEntry[]): Promise<boolean> => LogStorageService.addEntries(entries)
  private static subscribeFn:
    (cb: (entry: LogEntry) => void, eventTypes?: LogEventType[]) => boolean =
      (cb: (entry: LogEntry) => void, eventTypes?: LogEventType[]): boolean =>
        LogAuditService.subscribe(cb, eventTypes)
  private static unsubscribeFn: () => boolean = (): boolean => LogAuditService.unsubscribe()
  private static readonly INTERNAL_LOG_PATH_KEYWORDS: string[] = [
    'preferences/log_settings',
    'preferences/theme_preferences',
    'files/hiappevent/',
    'databases/appevent.db',
    'files/securitylog/'
  ]

  static async init(context: common.UIAbilityContext): Promise<boolean> {
    LogRuntimeCollectorService.context = context

    if (LogRuntimeCollectorService.initialized) {
      return true
    }

    let ready = await LogStorageService.init(context)
    if (!ready) {
      hilog.error(DOMAIN, TAG, 'init failed: storage init failed')
      return false
    }

    LogRuntimeCollectorService.initialized = true
    return true
  }

  static async start(): Promise<boolean> {
    if (LogRuntimeCollectorService.running) {
      return true
    }

    if (!LogRuntimeCollectorService.initialized) {
      if (!LogRuntimeCollectorService.context) {
        hilog.error(DOMAIN, TAG, 'start failed: collector not initialized')
        return false
      }
      let ready = await LogRuntimeCollectorService.init(LogRuntimeCollectorService.context)
      if (!ready) {
        return false
      }
    }

    let subscribeConfig = await LogStorageService.loadSubscriptionConfig()
    let eventTypes = subscribeConfig.subscribeAll ? undefined : subscribeConfig.subscribedTypes

    let success = LogRuntimeCollectorService.subscribeFn((entry: LogEntry) => {
      LogRuntimeCollectorService.handleIncomingEntry(entry)
    }, eventTypes)

    LogRuntimeCollectorService.running = success

    if (success) {
      let failed = LogAuditService.getLastSubscribeFailedEventIds()
      hilog.info(
        DOMAIN,
        TAG,
        `subscribe mode=${LogAuditService.getSubscribeMode()}, fallback=${LogAuditService.getFallbackReason()}`
      )
      if (failed.length > 0) {
        hilog.warn(DOMAIN, TAG, `start with partial subscribe success, failed eventIds=${failed.join(',')}`)
      }
      if (LogRuntimeCollectorService.pendingEntries.length > 0) {
        LogRuntimeCollectorService.scheduleFlushPendingEntries()
      }
      return true
    }

    let code = LogAuditService.getLastSubscribeErrorCode()
    hilog.error(DOMAIN, TAG, `start failed: subscribe failed, code=${code}`)
    return false
  }

  static async stop(): Promise<void> {
    LogRuntimeCollectorService.running = false
    LogRuntimeCollectorService.unsubscribeFn()

    if (LogRuntimeCollectorService.flushTimerId >= 0) {
      LogRuntimeCollectorService.clearTimerFn(LogRuntimeCollectorService.flushTimerId)
      LogRuntimeCollectorService.flushTimerId = -1
    }

    await LogRuntimeCollectorService.flushPendingEntries()
  }

  static getStatus(): LogRuntimeCollectorStatus {
    return {
      running: LogRuntimeCollectorService.running,
      subscribed: LogAuditService.getSubscriptionStatus()
    } as LogRuntimeCollectorStatus
  }

  private static handleIncomingEntry(entry: LogEntry): void {
    if (!LogRuntimeCollectorService.running) {
      return
    }

    if (LogRuntimeCollectorService.shouldIgnoreInternalEntry(entry)) {
      return
    }

    LogRuntimeCollectorService.pendingEntries.push(entry)
    if (LogRuntimeCollectorService.pendingEntries.length > LogRuntimeCollectorService.MAX_PENDING_ENTRIES) {
      let dropped = LogRuntimeCollectorService.pendingEntries.length -
        LogRuntimeCollectorService.MAX_PENDING_ENTRIES
      LogRuntimeCollectorService.pendingEntries.splice(0, dropped)
      hilog.warn(DOMAIN, TAG, `Dropped ${dropped} queued log entries due to burst traffic`)
    }

    LogRuntimeCollectorService.scheduleFlushPendingEntries()
  }

  private static shouldIgnoreInternalEntry(entry: LogEntry): boolean {
    if (entry.eventType !== LogEventType.FILE) {
      return false
    }

    let process = (entry.processName || '').toLowerCase()
    let content = `${entry.filePath || ''} ${entry.detail || ''}`.toLowerCase()
    let bundleName = AppInfo.BUNDLE_NAME.toLowerCase()
    let fromSelfProcess = process.includes(bundleName)

    for (let keyword of LogRuntimeCollectorService.INTERNAL_LOG_PATH_KEYWORDS) {
      if (content.includes(keyword)) {
        return true
      }
    }

    return fromSelfProcess && content.includes(bundleName)
  }

  private static scheduleFlushPendingEntries(): void {
    if (LogRuntimeCollectorService.flushTimerId >= 0) {
      return
    }

    LogRuntimeCollectorService.flushTimerId = LogRuntimeCollectorService.setTimerFn(() => {
      LogRuntimeCollectorService.flushTimerId = -1
      LogRuntimeCollectorService.flushPendingEntries().catch((err: Object) => {
        hilog.error(DOMAIN, TAG, `flushPendingEntries timer failed: ${JSON.stringify(err)}`)
      })
    }, LogRuntimeCollectorService.BATCH_FLUSH_INTERVAL_MS)
  }

  private static async flushPendingEntries(): Promise<void> {
    if (LogRuntimeCollectorService.isFlushingEntries || LogRuntimeCollectorService.pendingEntries.length === 0) {
      return
    }

    LogRuntimeCollectorService.isFlushingEntries = true
    let batch = LogRuntimeCollectorService.pendingEntries.slice(0, LogRuntimeCollectorService.pendingEntries.length)
    LogRuntimeCollectorService.pendingEntries = []

    try {
      let saved = await LogRuntimeCollectorService.persistEntriesFn(batch)
      if (!saved) {
        LogRuntimeCollectorService.requeueFailedBatch(batch, 'flushPendingEntries failed')
      }
    } catch (err) {
      LogRuntimeCollectorService.requeueFailedBatch(batch, 'flushPendingEntries exception')
      hilog.error(DOMAIN, TAG, `flushPendingEntries exception: ${JSON.stringify(err)}`)
    } finally {
      LogRuntimeCollectorService.isFlushingEntries = false
    }

    if (LogRuntimeCollectorService.running && LogRuntimeCollectorService.pendingEntries.length > 0) {
      LogRuntimeCollectorService.scheduleFlushPendingEntries()
    }
  }

  private static requeueFailedBatch(batch: LogEntry[], reason: string): void {
    if (batch.length === 0) {
      return
    }

    LogRuntimeCollectorService.pendingEntries = batch.concat(LogRuntimeCollectorService.pendingEntries)
    if (LogRuntimeCollectorService.pendingEntries.length > LogRuntimeCollectorService.MAX_PENDING_ENTRIES) {
      let dropped = LogRuntimeCollectorService.pendingEntries.length -
        LogRuntimeCollectorService.MAX_PENDING_ENTRIES
      LogRuntimeCollectorService.pendingEntries = LogRuntimeCollectorService.pendingEntries.slice(dropped)
      hilog.warn(DOMAIN, TAG, `${reason} dropped ${dropped} queued entries`)
    }
    hilog.warn(DOMAIN, TAG, `${reason}, batch=${batch.length}`)
  }
}
