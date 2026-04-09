import hiAppEvent from '@ohos.hiviewdfx.hiAppEvent'
import {
  generateLogEntryId,
  LogEntry,
  LogEventResult,
  LogEventType
} from '../../../models/DataModels'
import { LogUtils } from '../../../utils/LogUtils'
import { CrashSubscribeResult, SourceStatus } from '../common/LogManagePorts'

const TAG = 'LogCrashSource'
const WATCHER_NAME = 'securityCrashWatcher1'

type CrashEntryCallback = (entry: LogEntry) => void
type CrashParamValue = string | number | boolean | Object | undefined
type CrashParamMap = Record<string, CrashParamValue>

export class LogCrashSource {
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
      LogCrashSource.handleReceive(appEventGroups)
    }
  }

  static subscribe(onEntry: (entry: LogEntry) => void): CrashSubscribeResult {
    if (LogCrashSource.subscribed) {
      LogCrashSource.callback = onEntry
      return { success: true, code: 'ok' }
    }

    try {
      LogCrashSource.callback = onEntry
      hiAppEvent.addWatcher(LogCrashSource.watcher)
      LogCrashSource.subscribed = true
      LogCrashSource.lastErrorCode = undefined
      return { success: true, code: 'ok' }
    } catch (err) {
      LogCrashSource.lastErrorCode = LogCrashSource.extractErrorCode(err as Object)
      LogUtils.error(TAG, `addWatcher failed: ${JSON.stringify(err)}`)
      return { success: false, code: 'unsupported' }
    }
  }

  static unsubscribe(): boolean {
    if (!LogCrashSource.subscribed) {
      return true
    }

    try {
      hiAppEvent.removeWatcher(LogCrashSource.watcher)
      LogCrashSource.subscribed = false
      LogCrashSource.callback = null
      return true
    } catch (err) {
      LogUtils.warn(TAG, `removeWatcher failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static getStatus(): SourceStatus {
    return {
      subscribed: LogCrashSource.subscribed,
      errorCode: LogCrashSource.lastErrorCode
    }
  }

  private static handleReceive(appEventGroups: Array<hiAppEvent.AppEventGroup>): void {
    for (const group of appEventGroups) {
      for (const info of group.appEventInfos) {
        const entry = LogCrashSource.mapCrashInfo(info)
        if (LogCrashSource.callback) {
          LogCrashSource.callback(entry)
        }
      }
    }
  }

  private static mapCrashInfo(info: hiAppEvent.AppEventInfo): LogEntry {
    const params = info.params as CrashParamMap
    const processName = LogCrashSource.pickString(params, [
      'bundleName', 'bundle_name', 'processName', 'process_name', 'moduleName', 'module_name', 'abilityName'
    ])
    const reason = LogCrashSource.pickString(params, [
      'exception', 'reason', 'message', 'summary', 'errorMessage', 'error_message'
    ])
    const stack = LogCrashSource.pickString(params, ['stackTrace', 'stack_trace', 'stack', 'logPath', 'log_path'])
    const rawAction = LogCrashSource.pickString(params, ['state', 'lifecycle', 'stage'])
    const detailParts: string[] = []
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
      pid: LogCrashSource.pickNumber(params, ['pid', 'processId', 'process_id']),
      uid: LogCrashSource.pickNumber(params, ['uid', 'userId', 'user_id']),
      sourceEventId: undefined,
      rawEventName: info.name,
      rawOutcome: info.name === hiAppEvent.event.APP_FREEZE ? 'freeze' : 'crash',
      rawAction: rawAction,
      result: LogEventResult.FAILED
    }
  }

  private static pickString(params: CrashParamMap, keys: string[]): string | undefined {
    for (const key of keys) {
      const value = params[key]
      if (typeof value === 'string' && value.trim().length > 0) {
        return value.trim()
      }
    }
    return undefined
  }

  private static pickNumber(params: CrashParamMap, keys: string[]): number | undefined {
    for (const key of keys) {
      const value = params[key]
      if (typeof value === 'number' && Number.isFinite(value)) {
        return value
      }
      if (typeof value === 'string') {
        const parsed = Number(value)
        if (Number.isFinite(parsed)) {
          return parsed
        }
      }
    }
    return undefined
  }

  private static extractErrorCode(err: Object): number | undefined {
    const codeValue = (err as Record<string, Object>)['code']
    if (typeof codeValue === 'number') {
      return codeValue
    }
    if (typeof codeValue === 'string') {
      const parsed = Number(codeValue)
      return Number.isNaN(parsed) ? undefined : parsed
    }
    return undefined
  }

  static mapCrashInfoForTest(info: hiAppEvent.AppEventInfo): LogEntry {
    return LogCrashSource.mapCrashInfo(info)
  }

}
