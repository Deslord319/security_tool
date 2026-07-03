import hiAppEvent from '@ohos.hiviewdfx.hiAppEvent'
import { LogEntry } from '../../../models/LogModels'
import { LogUtils } from '../../../utils/LogUtils'
import { CrashSubscribeResult, LogEntryCallback } from '../common/LogManagePorts'
import { mapCrashInfoToLogEntry } from './LogCrashEventMapper'

const TAG = 'LogCrashSource'
const WATCHER_NAME = 'securityCrashWatcher1'

export class LogCrashSource {
  private static callback: LogEntryCallback | null = null
  private static subscribed: boolean = false
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
      return { success: true, code: 'ok' }
    } catch (err) {
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
