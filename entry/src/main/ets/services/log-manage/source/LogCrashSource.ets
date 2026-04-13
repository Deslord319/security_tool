import hiAppEvent from '@ohos.hiviewdfx.hiAppEvent'
import { LogEntry } from '../../../models/DataModels'
import { LogUtils } from '../../../utils/LogUtils'
import { CommonErrorUtils } from '../../../utils/CommonErrorUtils'
import { CrashSubscribeResult, SourceStatus } from '../common/LogManagePorts'
import { mapCrashInfoToLogEntry } from './LogCrashEventMapper'

const TAG = 'LogCrashSource'
const WATCHER_NAME = 'securityCrashWatcher1'

type CrashEntryCallback = (entry: LogEntry) => void

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
      LogCrashSource.lastErrorCode = CommonErrorUtils.extractErrorCode(err as Object)
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
        const entry = mapCrashInfoToLogEntry(info)
        if (LogCrashSource.callback) {
          LogCrashSource.callback(entry)
        }
      }
    }
  }
}
