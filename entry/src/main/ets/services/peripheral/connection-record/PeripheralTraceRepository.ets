import { LogUtils } from '../../../utils/LogUtils'
import { common } from '@kit.AbilityKit'

import {
  LogEventResult,
  PeripheralRecordAction,
  PeripheralRecordPolicyHit,
  PeripheralRecordSource,
  PeripheralTraceQuery,
  PeripheralTraceRecord,
  PeripheralTraceStats,
  PeripheralType
} from '../../../models/DataModels'
import { PeripheralTraceEntryRepository } from './PeripheralTraceEntryRepository'

const TAG = 'PeripheralTraceRepo'
const RETENTION_DAYS_DEFAULT = 180
const MAX_TRACE_ENTRIES_DEFAULT = 200000

interface TraceChangeEvent {
  totalCount: number
  addedCount: number
  timestamp: number
}

type TraceChangeListener = (event: TraceChangeEvent) => void

export class PeripheralTraceRepository {
  private static context: common.UIAbilityContext | null = null
  private static initPromise: Promise<boolean> | null = null
  private static initialized: boolean = false
  private static nextListenerId: number = 1
  private static listeners: Map<number, TraceChangeListener> = new Map()
  private static retentionDays: number = RETENTION_DAYS_DEFAULT
  private static maxEntries: number = MAX_TRACE_ENTRIES_DEFAULT
  private static nowProvider: () => number = () => Date.now()

  static async init(context: common.UIAbilityContext): Promise<boolean> {
    PeripheralTraceRepository.context = context
    if (PeripheralTraceRepository.initialized) {
      return true
    }
    if (PeripheralTraceRepository.initPromise) {
      return PeripheralTraceRepository.initPromise
    }
    PeripheralTraceRepository.initPromise = PeripheralTraceRepository.doInit()
    let ok = await PeripheralTraceRepository.initPromise
    PeripheralTraceRepository.initPromise = null
    return ok
  }

  static async configure(retentionDays?: number, maxEntries?: number): Promise<void> {
    if (retentionDays !== undefined && Number.isFinite(retentionDays) && retentionDays > 0) {
      PeripheralTraceRepository.retentionDays = Math.floor(retentionDays)
    }
    if (maxEntries !== undefined && Number.isFinite(maxEntries) && maxEntries > 0) {
      PeripheralTraceRepository.maxEntries = Math.floor(maxEntries)
    }
    await PeripheralTraceRepository.reconcileStorage()
  }

  static addChangeListener(listener: TraceChangeListener): number {
    let id = PeripheralTraceRepository.nextListenerId++
    PeripheralTraceRepository.listeners.set(id, listener)
    return id
  }

  static removeChangeListener(listenerId: number): void {
    PeripheralTraceRepository.listeners.delete(listenerId)
  }

  static async append(record: PeripheralTraceRecord): Promise<boolean> {
    return PeripheralTraceRepository.appendBatch([record])
  }

  static async appendBatch(records: PeripheralTraceRecord[]): Promise<boolean> {
    try {
      if (records.length === 0) {
        return true
      }
      let normalized: PeripheralTraceRecord[] = []
      for (let item of records) {
        if (!item) {
          continue
        }
        normalized.push(PeripheralTraceRepository.normalizeRecord(item))
      }
      if (normalized.length === 0) {
        return true
      }
      let saved = await PeripheralTraceEntryRepository.upsertBatch(normalized)
      if (!saved) {
        return false
      }
      let reconciled = await PeripheralTraceRepository.reconcileStorage()
      if (!reconciled) {
        return false
      }
      await PeripheralTraceRepository.notifyChanged(normalized.length)
      return true
    } catch (err) {
      LogUtils.error(TAG, `appendBatch failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static async query(query?: PeripheralTraceQuery): Promise<PeripheralTraceRecord[]> {
    let pageOffset = query?.pageOffset && query.pageOffset > 0 ? Math.floor(query.pageOffset) : 0
    let pageSize = query?.pageSize && query.pageSize > 0 ? Math.floor(query.pageSize) : undefined
    return PeripheralTraceEntryRepository.listByQuery(query, pageSize, pageOffset)
  }

  static async getStats(query?: PeripheralTraceQuery): Promise<PeripheralTraceStats> {
    let records = await PeripheralTraceRepository.query(query)
    let stats: PeripheralTraceStats = {
      total: records.length,
      connects: 0,
      disconnects: 0,
      intercepts: 0,
      allows: 0,
      denies: 0,
      unknowns: 0,
      runtimeCount: 0,
      auditCount: 0,
      snapshotCount: 0
    }
    for (let record of records) {
      if (record.action === 'connect') {
        stats.connects++
      } else if (record.action === 'disconnect') {
        stats.disconnects++
      } else if (record.action === 'intercept') {
        stats.intercepts++
      }

      if (record.decision === 'allow') {
        stats.allows++
      } else if (record.decision === 'deny') {
        stats.denies++
      } else {
        stats.unknowns++
      }

      if (record.source === 'runtime_event') {
        stats.runtimeCount++
      } else if (record.source === 'audit_event') {
        stats.auditCount++
      } else {
        stats.snapshotCount++
      }
    }
    return stats
  }

  static async forceCleanup(retentionDays?: number, maxEntries?: number): Promise<number> {
    if (retentionDays !== undefined && Number.isFinite(retentionDays) && retentionDays > 0) {
      PeripheralTraceRepository.retentionDays = Math.floor(retentionDays)
    }
    if (maxEntries !== undefined && Number.isFinite(maxEntries) && maxEntries > 0) {
      PeripheralTraceRepository.maxEntries = Math.floor(maxEntries)
    }
    let before = await PeripheralTraceEntryRepository.countByQuery()
    let reconciled = await PeripheralTraceRepository.reconcileStorage()
    if (!reconciled) {
      return 0
    }
    let after = await PeripheralTraceEntryRepository.countByQuery()
    let removed = Math.max(0, before - after)
    if (removed > 0) {
      await PeripheralTraceRepository.notifyChanged(0)
    }
    return removed
  }

  static async clearAll(): Promise<boolean> {
    try {
      let cleared = await PeripheralTraceEntryRepository.clearAll()
      if (!cleared) {
        return false
      }
      await PeripheralTraceRepository.notifyChanged(0)
      LogUtils.info(TAG, 'clearAll success')
      return true
    } catch (err) {
      LogUtils.error(TAG, `clearAll failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  private static async doInit(): Promise<boolean> {
    if (!PeripheralTraceRepository.context) {
      return false
    }
    try {
      let ready = await PeripheralTraceEntryRepository.init(PeripheralTraceRepository.context)
      if (!ready) {
        return false
      }
      let reconciled = await PeripheralTraceRepository.reconcileStorage()
      if (!reconciled) {
        PeripheralTraceRepository.initialized = false
        return false
      }
      PeripheralTraceRepository.initialized = true
      let totalCount = await PeripheralTraceEntryRepository.countByQuery()
      LogUtils.info(TAG, `init complete, records=${totalCount}`)
      return true
    } catch (err) {
      PeripheralTraceRepository.initialized = false
      LogUtils.error(TAG, `init failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  private static normalizeRecord(record: PeripheralTraceRecord): PeripheralTraceRecord {
    let now = PeripheralTraceRepository.nowProvider()
    let occurAt = Number.isFinite(record.occurAt) && record.occurAt > 0 ? Math.floor(record.occurAt) : now
    let collectAt = Number.isFinite(record.collectAt) && record.collectAt > 0 ? Math.floor(record.collectAt) : now
    let result = PeripheralTraceRepository.normalizeResult(record.result)
    let action = PeripheralTraceRepository.normalizeAction(record.action)
    let decision = PeripheralTraceRepository.normalizeDecision(record.decision)
    let source = PeripheralTraceRepository.normalizeSource(record.source)
    return {
      recordId: record.recordId && record.recordId.length > 0 ?
        record.recordId :
        `ptr_${collectAt}_${Math.random().toString(36).substring(2, 8)}`,
      occurAt: occurAt,
      collectAt: collectAt,
      deviceName: record.deviceName || 'Unknown Device',
      deviceType: record.deviceType || PeripheralType.USB_OTHER,
      deviceId: PeripheralTraceRepository.normalizeDeviceId(record.deviceId),
      action: action,
      decision: decision,
      result: result,
      source: source,
      summary: record.summary || '',
      correlationId: record.correlationId,
      policyVersion: record.policyVersion,
      rawEventId: record.rawEventId,
      rawEventName: record.rawEventName,
      rawOutcome: record.rawOutcome,
      rawAction: record.rawAction,
      rawPayload: record.rawPayload,
      detail: record.detail,
      processName: record.processName,
      usbPolicy: record.usbPolicy,
      effectivePolicyLabel: record.effectivePolicyLabel,
      matchedPolicyKind: record.matchedPolicyKind || 'unknown'
    }
  }

  private static normalizeResult(result: LogEventResult): LogEventResult {
    if (
      result === LogEventResult.SUCCESS ||
      result === LogEventResult.BLOCKED ||
      result === LogEventResult.FAILED
    ) {
      return result
    }
    return LogEventResult.SUCCESS
  }

  private static normalizeAction(action: PeripheralRecordAction): PeripheralRecordAction {
    if (
      action === 'connect' ||
      action === 'disconnect' ||
      action === 'intercept' ||
      action === 'unknown'
    ) {
      return action
    }
    return 'unknown'
  }

  private static normalizeDecision(decision: PeripheralRecordPolicyHit): PeripheralRecordPolicyHit {
    if (decision === 'allow' || decision === 'deny' || decision === 'unknown') {
      return decision
    }
    return 'unknown'
  }

  private static normalizeSource(source: PeripheralRecordSource): PeripheralRecordSource {
    if (source === 'runtime_event' || source === 'audit_event' || source === 'policy_snapshot') {
      return source
    }
    return 'audit_event'
  }

  private static normalizeDeviceId(deviceId: string): string {
    let value = (deviceId || '').trim()
    if (value.length === 0) {
      return 'UNKNOWN'
    }
    return value.replace(/\s+/g, ' ').toUpperCase()
  }

  private static async reconcileStorage(): Promise<boolean> {
    try {
      let now = PeripheralTraceRepository.nowProvider()
      let retentionMs = PeripheralTraceRepository.retentionDays * 24 * 60 * 60 * 1000
      let cutoff = now - retentionMs
      let deletedExpired = await PeripheralTraceEntryRepository.deleteExpired(cutoff)
      if (!deletedExpired) {
        return false
      }
      let trimmed = await PeripheralTraceEntryRepository.trimToMaxEntries(PeripheralTraceRepository.maxEntries)
      if (!trimmed) {
        return false
      }
      return true
    } catch (err) {
      LogUtils.error(TAG, `reconcileStorage failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  private static async notifyChanged(addedCount: number): Promise<void> {
    if (PeripheralTraceRepository.listeners.size <= 0) {
      return
    }
    let totalCount = await PeripheralTraceEntryRepository.countByQuery()
    let event: TraceChangeEvent = {
      totalCount: totalCount,
      addedCount: addedCount,
      timestamp: PeripheralTraceRepository.nowProvider()
    }
    PeripheralTraceRepository.listeners.forEach((listener: TraceChangeListener) => {
      try {
        listener(event)
      } catch (err) {
        LogUtils.warn(TAG, `listener failed: ${JSON.stringify(err)}`)
      }
    })
  }
}
