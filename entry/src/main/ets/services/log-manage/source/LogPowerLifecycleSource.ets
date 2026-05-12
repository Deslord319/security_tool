import { common } from '@kit.AbilityKit'
import { BusinessError, commonEventManager } from '@kit.BasicServicesKit'
import {
  generateLogEntryId,
  LogEntry,
  LogEventType
} from '../../../models/LogModels'
import { LogDeviceLifecycleStrings } from '../../../constants/modules/LogManageStrings'
import { LogStorageMaintenanceService } from '../maintenance/LogStorageMaintenanceService'
import { LogUtils } from '../../../utils/LogUtils'
import { PreferencesAccessor } from '../../../storage/preferences/PreferencesAccessor'

const TAG = 'LogPowerLifecycle'
const SHUTDOWN_EVENT = 'usual.event.SHUTDOWN'
const BOOT_EVENT = 'app.boot'
const POWER_LIFECYCLE_STORE = 'power_lifecycle'
const PENDING_SHUTDOWN_AT_KEY = 'pending_shutdown_at'
const PENDING_SHUTDOWN_LOGGED_KEY = 'pending_shutdown_logged'

export class LogPowerLifecycleSource {
  private static initialized: boolean = false
  private static subscriber: commonEventManager.CommonEventSubscriber | null = null
  private static context: common.UIAbilityContext | null = null

  static async init(context: common.UIAbilityContext): Promise<void> {
    LogPowerLifecycleSource.context = context
    if (LogPowerLifecycleSource.initialized) {
      return
    }
    let initialized = await LogStorageMaintenanceService.initialize(context)
    if (!initialized.success) {
      LogUtils.warn(TAG, 'init skipped: storage initialize failed, code=%{public}s', initialized.code)
      return
    }
    LogPowerLifecycleSource.initialized = true
    let recoveredShutdown = await LogPowerLifecycleSource.recordPendingShutdownIfNeeded()
    await LogPowerLifecycleSource.appendBootEntry(recoveredShutdown ? 'startup_recovery' : 'app_start')
    LogPowerLifecycleSource.subscribeShutdownEvent()
  }

  static destroy(): void {
    if (!LogPowerLifecycleSource.subscriber) {
      LogPowerLifecycleSource.initialized = false
      LogPowerLifecycleSource.context = null
      return
    }
    commonEventManager.unsubscribe(LogPowerLifecycleSource.subscriber, (err?: BusinessError) => {
      if (err) {
        LogUtils.warn(TAG, 'unsubscribe shutdown event failed: %{public}s', JSON.stringify(err))
      }
    })
    LogPowerLifecycleSource.subscriber = null
    LogPowerLifecycleSource.initialized = false
    LogPowerLifecycleSource.context = null
  }

  private static subscribeShutdownEvent(): void {
    if (LogPowerLifecycleSource.subscriber) {
      return
    }
    let subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
      events: [SHUTDOWN_EVENT]
    }
    commonEventManager.createSubscriber(subscribeInfo, (err: BusinessError, subscriber) => {
      if (err) {
        LogUtils.warn(TAG, 'create shutdown subscriber failed: %{public}s', JSON.stringify(err))
        return
      }
      LogPowerLifecycleSource.subscriber = subscriber
      commonEventManager.subscribe(subscriber, async (callbackErr: BusinessError) => {
        if (callbackErr) {
          LogUtils.warn(TAG, 'shutdown event callback failed: %{public}s', JSON.stringify(callbackErr))
          return
        }
        try {
          await LogPowerLifecycleSource.markPendingShutdown()
          await LogPowerLifecycleSource.appendShutdownEntry(Date.now(), 'common_event', true)
        } catch (err) {
          LogUtils.warn(TAG, 'shutdown event handling exception: %{public}s', JSON.stringify(err))
        }
      })
    })
  }

  private static async recordPendingShutdownIfNeeded(): Promise<boolean> {
    let timestamp = await LogPowerLifecycleSource.getPendingShutdownTimestamp()
    if (timestamp <= 0) {
      return false
    }
    let logged = await LogPowerLifecycleSource.isPendingShutdownLogged()
    if (!logged) {
      let recovered = await LogPowerLifecycleSource.appendShutdownEntry(timestamp, 'startup_recovery', true)
      if (!recovered) {
        LogUtils.warn(TAG, 'recordPendingShutdownIfNeeded keep marker: recovery append failed')
        return true
      }
    }
    await LogPowerLifecycleSource.clearPendingShutdownMarker()
    return true
  }

  private static async markPendingShutdown(): Promise<void> {
    let context = LogPowerLifecycleSource.context
    if (!context) {
      LogUtils.warn(TAG, 'markPendingShutdown skipped: context unavailable')
      return
    }
    let timestamp = Date.now()
    let pref = PreferencesAccessor.of(context, POWER_LIFECYCLE_STORE)
    let saved = await pref.setMany([
      { key: PENDING_SHUTDOWN_AT_KEY, value: timestamp },
      { key: PENDING_SHUTDOWN_LOGGED_KEY, value: 0 }
    ])
    if (!saved) {
      LogUtils.warn(TAG, 'markPendingShutdown failed: timestamp=%{public}d', timestamp)
      return
    }
  }

  private static async getPendingShutdownTimestamp(): Promise<number> {
    let context = LogPowerLifecycleSource.context
    if (!context) {
      LogUtils.warn(TAG, 'getPendingShutdownTimestamp skipped: context unavailable')
      return 0
    }
    let pref = PreferencesAccessor.of(context, POWER_LIFECYCLE_STORE)
    return pref.getNumber(PENDING_SHUTDOWN_AT_KEY, 0)
  }

  private static async isPendingShutdownLogged(): Promise<boolean> {
    let context = LogPowerLifecycleSource.context
    if (!context) {
      LogUtils.warn(TAG, 'isPendingShutdownLogged skipped: context unavailable')
      return false
    }
    let pref = PreferencesAccessor.of(context, POWER_LIFECYCLE_STORE)
    return (await pref.getNumber(PENDING_SHUTDOWN_LOGGED_KEY, 0)) > 0
  }

  private static async markPendingShutdownLogged(): Promise<boolean> {
    let context = LogPowerLifecycleSource.context
    if (!context) {
      LogUtils.warn(TAG, 'markPendingShutdownLogged skipped: context unavailable')
      return false
    }
    let pref = PreferencesAccessor.of(context, POWER_LIFECYCLE_STORE)
    let saved = await pref.setValue(PENDING_SHUTDOWN_LOGGED_KEY, 1)
    if (!saved) {
      LogUtils.warn(TAG, 'markPendingShutdownLogged failed')
      return false
    }
    return true
  }

  private static async clearPendingShutdownMarker(): Promise<void> {
    let context = LogPowerLifecycleSource.context
    if (!context) {
      LogUtils.warn(TAG, 'clearPendingShutdownMarker skipped: context unavailable')
      return
    }
    let pref = PreferencesAccessor.of(context, POWER_LIFECYCLE_STORE)
    let cleared = await pref.setMany([
      { key: PENDING_SHUTDOWN_AT_KEY, value: 0 },
      { key: PENDING_SHUTDOWN_LOGGED_KEY, value: 0 }
    ])
    if (!cleared) {
      LogUtils.warn(TAG, 'clearPendingShutdownMarker failed')
    }
  }

  private static async appendShutdownEntry(timestamp: number, source: string, preservePendingMarker: boolean = false): Promise<boolean> {
    let entry: LogEntry = {
      id: generateLogEntryId(),
      timestamp,
      eventType: LogEventType.POWER,
      detail: LogDeviceLifecycleStrings.SHUTDOWN_REQUESTED,
      rawEventName: SHUTDOWN_EVENT,
      detailRows: [
        { key: 'event', label: '事件', value: SHUTDOWN_EVENT },
        { key: 'source', label: '来源', value: source }
      ]
    }
    let saved = await LogStorageMaintenanceService.appendEntries([entry])
    if (!saved.success) {
      LogUtils.warn(TAG, 'appendShutdownEntry failed: source=%{public}s, code=%{public}s', source, saved.code)
      return false
    }
    if (preservePendingMarker) {
      let marked = await LogPowerLifecycleSource.markPendingShutdownLogged()
      if (!marked) {
        LogUtils.warn(TAG, 'appendShutdownEntry marker logged flag not updated: source=%{public}s', source)
        return false
      }
    }
    return true
  }

  private static async appendBootEntry(source: string): Promise<boolean> {
    let timestamp = Date.now()
    let entry: LogEntry = {
      id: generateLogEntryId(),
      timestamp,
      eventType: LogEventType.POWER,
      detail: LogDeviceLifecycleStrings.BOOT,
      rawEventName: BOOT_EVENT,
      detailRows: [
        { key: 'event', label: '事件', value: BOOT_EVENT },
        { key: 'source', label: '来源', value: source }
      ]
    }
    let saved = await LogStorageMaintenanceService.appendEntries([entry])
    if (!saved.success) {
      LogUtils.warn(TAG, 'appendBootEntry failed: source=%{public}s, code=%{public}s', source, saved.code)
      return false
    }
    return true
  }
}
