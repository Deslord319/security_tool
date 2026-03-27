import hiAppEvent from '@ohos.hiviewdfx.hiAppEvent'
import { hilog } from '@kit.PerformanceAnalysisKit'
import {
  LogEntry,
  LogEventResult,
  LogEventType,
  generateLogEntryId
} from '../models/DataModels'

const TAG = 'LogCrashService'
const DOMAIN = 0x0006
const WATCHER_NAME = 'securityCrashWatcher1'

export type CrashEntryCallback = (entry: LogEntry) => void

type CrashParamValue = string | number | boolean | Object | undefined
type CrashParamMap = Record<string, CrashParamValue>

export class LogCrashService {
  private static callback: CrashEntryCallback | null = null
  private static subscribed: boolean = false
  private static lastErrorCode: number | undefined = undefined
  private static readonly watcher: hiAppEvent.Watcher = {
    name: WATCHER_NAME,
    appEventFilters: [{
      domain: hiAppEvent.domain.OS,
      names: [hiAppEvent.event.APP_CRASH, hiAppEvent.event.APP_FREEZE]
    }],
    onReceive: (_domain: string, appEventGroups: Array<hiAppEvent.AppEventGroup>) => {
      LogCrashService.handleReceive(appEventGroups)
    }
  }

  static subscribe(onCrashEntry: CrashEntryCallback): boolean {
    if (LogCrashService.subscribed) {
      LogCrashService.callback = onCrashEntry
      return true
    }

    try {
      LogCrashService.callback = onCrashEntry
      hiAppEvent.addWatcher(LogCrashService.watcher)
      LogCrashService.subscribed = true
      LogCrashService.lastErrorCode = undefined
      return true
    } catch (err) {
      LogCrashService.lastErrorCode = LogCrashService.extractErrorCode(err as Object)
      hilog.error(DOMAIN, TAG, `addWatcher failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static unsubscribe(): boolean {
    if (!LogCrashService.subscribed) {
      return true
    }

    try {
      hiAppEvent.removeWatcher(LogCrashService.watcher)
      LogCrashService.subscribed = false
      LogCrashService.callback = null
      return true
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `removeWatcher failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static getSubscriptionStatus(): boolean {
    return LogCrashService.subscribed
  }

  private static handleReceive(appEventGroups: Array<hiAppEvent.AppEventGroup>): void {
    for (let group of appEventGroups) {
      for (let info of group.appEventInfos) {
        let entry = LogCrashService.mapCrashInfo(info)
        if (LogCrashService.callback) {
          LogCrashService.callback(entry)
        }
      }
    }
  }

  private static mapCrashInfo(info: hiAppEvent.AppEventInfo): LogEntry {
    let params = info.params as CrashParamMap
    let processName = LogCrashService.pickString(params, [
      'bundleName', 'bundle_name', 'processName', 'process_name', 'moduleName', 'module_name', 'abilityName'
    ])
    let reason = LogCrashService.pickString(params, [
      'exception', 'reason', 'message', 'summary', 'errorMessage', 'error_message'
    ])
    let stack = LogCrashService.pickString(params, ['stackTrace', 'stack_trace', 'stack', 'logPath', 'log_path'])
    let rawAction = LogCrashService.pickString(params, ['state', 'lifecycle', 'stage'])
    let detailParts: string[] = []
    if (reason) {
      detailParts.push(reason)
    }
    if (stack) {
      detailParts.push(stack)
    }
    if (detailParts.length === 0) {
      detailParts.push(info.name)
    }

    return {
      id: generateLogEntryId(),
      timestamp: Date.now(),
      eventType: LogEventType.CRASH,
      detail: detailParts.join(' | '),
      processName: processName,
      pid: LogCrashService.pickNumber(params, ['pid', 'processId', 'process_id']),
      uid: LogCrashService.pickNumber(params, ['uid', 'userId', 'user_id']),
      sourceEventId: undefined,
      rawEventName: info.name,
      rawOutcome: info.name === hiAppEvent.event.APP_FREEZE ? 'freeze' : 'crash',
      rawAction: rawAction,
      result: LogEventResult.FAILED
    }
  }

  private static pickString(params: CrashParamMap, keys: string[]): string | undefined {
    for (let key of keys) {
      let value = params[key]
      if (typeof value === 'string' && value.trim().length > 0) {
        return value.trim()
      }
    }
    return undefined
  }

  private static pickNumber(params: CrashParamMap, keys: string[]): number | undefined {
    for (let key of keys) {
      let value = params[key]
      if (typeof value === 'number' && Number.isFinite(value)) {
        return value
      }
      if (typeof value === 'string') {
        let parsed = Number(value)
        if (Number.isFinite(parsed)) {
          return parsed
        }
      }
    }
    return undefined
  }

  private static extractErrorCode(err: Object): number | undefined {
    let codeValue = (err as Record<string, Object>)['code']
    if (typeof codeValue === 'number') {
      return codeValue
    }
    if (typeof codeValue === 'string') {
      let parsed = Number(codeValue)
      return Number.isNaN(parsed) ? undefined : parsed
    }
    return undefined
  }
}
