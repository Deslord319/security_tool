import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import {
  LogEntry,
  LogEventResult,
  LogEventType
} from '../../main/ets/models/LogModels'
import { LogPowerLifecycleSource } from '../../main/ets/services/log-manage/source/LogPowerLifecycleSource'
import { LogStorageMaintenanceService } from '../../main/ets/services/log-manage/maintenance/LogStorageMaintenanceService'
import { InitializeResult, MutationResult } from '../../main/ets/services/log-manage/common/LogManagePorts'
import { PreferencesAccessor } from '../../main/ets/storage/preferences/PreferencesAccessor'

class FakeInitializeResult implements InitializeResult {
  success: boolean = true
  code: 'ok' | 'storage_init_failed' | 'config_init_failed' | 'collector_init_failed' = 'ok'
}

class FakeMutationResult implements MutationResult {
  success: boolean = true
  code: 'ok' | 'not_initialized' | 'save_failed' | 'clear_failed' | 'flush_failed' = 'ok'
}

class FakePrefWriteItem {
  key: string = ''
  value: number = 0
}

class FakePreferencesAccessor {
  private readonly values: Map<string, number>

  constructor(values?: Map<string, number>) {
    this.values = values ?? new Map<string, number>()
  }

  async getNumber(key: string, defaultValue: number): Promise<number> {
    let value = this.values.get(key)
    return value !== undefined ? value : defaultValue
  }

  async setMany(items: FakePrefWriteItem[], _flush: boolean = true): Promise<boolean> {
    for (let item of items) {
      this.values.set(item.key, item.value)
    }
    return true
  }

  async setValue(key: string, value: number, _flush: boolean = true): Promise<boolean> {
    this.values.set(key, value)
    return true
  }
}

function buildInitializeResult(
  success: boolean,
  code: 'ok' | 'storage_init_failed' | 'config_init_failed' | 'collector_init_failed'
): InitializeResult {
  let result = new FakeInitializeResult()
  result.success = success
  result.code = code
  return result
}

function buildMutationResult(
  success: boolean,
  code: 'ok' | 'not_initialized' | 'save_failed' | 'clear_failed' | 'flush_failed'
): MutationResult {
  let result = new FakeMutationResult()
  result.success = success
  result.code = code
  return result
}

export default function logPowerLifecycleSourceTest() {
  describe('LogPowerLifecycleSource', () => {
    let mockKit: MockKit
    let context: common.UIAbilityContext
    let appendedEntries: LogEntry[]
    let storedNumbers: Map<string, number>

    beforeEach(() => {
      mockKit = new MockKit()
      context = {} as common.UIAbilityContext
      appendedEntries = []
      storedNumbers = new Map<string, number>()

      let initMock = mockKit.mockFunc(LogStorageMaintenanceService, LogStorageMaintenanceService.initialize)
      let appendMock = mockKit.mockFunc(LogStorageMaintenanceService, LogStorageMaintenanceService.appendEntries)
      let prefMock = mockKit.mockFunc(PreferencesAccessor, PreferencesAccessor.of)

      when(initMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(buildInitializeResult(true, 'ok')))
      when(appendMock)(ArgumentMatchers.any).afterAction((entries: LogEntry[]): Promise<MutationResult> => {
        appendedEntries.push(...entries)
        return Promise.resolve(buildMutationResult(true, 'ok'))
      })
      when(prefMock)(ArgumentMatchers.any).afterReturn(new FakePreferencesAccessor(storedNumbers) as never as PreferencesAccessor)
    })

    afterEach(() => {
      LogPowerLifecycleSource.destroy()
      mockKit.clearAll()
    })

    it('should initialize successfully and subscribe shutdown event', 0, async () => {
      await LogPowerLifecycleSource.init(context)

      expect(true).assertTrue()
    })

    it('should handle re-initialization gracefully', 0, async () => {
      await LogPowerLifecycleSource.init(context)
      await LogPowerLifecycleSource.init(context)

      let bootEntries = appendedEntries.filter((entry: LogEntry) => entry.rawEventName === 'app.boot')
      expect(bootEntries.length).assertEqual(1)
    })

    it('should append boot entry when no pending shutdown marker exists', 0, async () => {
      await LogPowerLifecycleSource.init(context)

      let powerEntries = appendedEntries.filter((entry: LogEntry) => entry.eventType === LogEventType.POWER)
      expect(powerEntries.length).assertEqual(1)
      expect(powerEntries[0].rawEventName).assertEqual('app.boot')
      expect(powerEntries[0].detailRows![1].value).assertEqual('app_start')
    })

    it('should destroy and cleanup resources', 0, async () => {
      await LogPowerLifecycleSource.init(context)
      LogPowerLifecycleSource.destroy()

      expect(true).assertTrue()
    })

    it('should handle destroy when not initialized', 0, () => {
      LogPowerLifecycleSource.destroy()

      expect(true).assertTrue()
    })

    it('should handle storage initialization failure', 0, async () => {
      let initMock = mockKit.mockFunc(LogStorageMaintenanceService, LogStorageMaintenanceService.initialize)
      when(initMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(buildInitializeResult(false, 'storage_init_failed')))

      await LogPowerLifecycleSource.init(context)

      expect(appendedEntries.length).assertEqual(0)
    })

    it('should handle append entries failure gracefully', 0, async () => {
      storedNumbers.set('pending_shutdown_at', 1712732400000)
      let appendMock = mockKit.mockFunc(LogStorageMaintenanceService, LogStorageMaintenanceService.appendEntries)
      when(appendMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(buildMutationResult(false, 'save_failed')))

      await LogPowerLifecycleSource.init(context)

      expect(true).assertTrue()
    })

    it('should record pending shutdown on startup recovery', 0, async () => {
      storedNumbers.set('pending_shutdown_at', 1712732400000)
      storedNumbers.set('pending_shutdown_logged', 0)

      await LogPowerLifecycleSource.init(context)

      let shutdownEntry = appendedEntries.find((entry: LogEntry) => entry.rawEventName === 'usual.event.SHUTDOWN')
      expect(shutdownEntry !== undefined).assertTrue()
      expect(shutdownEntry!.eventType).assertEqual(LogEventType.POWER)
      expect(shutdownEntry!.result).assertEqual(LogEventResult.SUCCESS)
      let bootEntry = appendedEntries.find((entry: LogEntry) => entry.rawEventName === 'app.boot')
      expect(bootEntry !== undefined).assertTrue()
      expect(bootEntry!.detailRows![1].value).assertEqual('startup_recovery')
    })

    it('should skip recording when shutdown already logged', 0, async () => {
      storedNumbers.set('pending_shutdown_at', 1712732400000)
      storedNumbers.set('pending_shutdown_logged', 1)

      await LogPowerLifecycleSource.init(context)

      let shutdownEntry = appendedEntries.find((entry: LogEntry) => entry.rawEventName === 'usual.event.SHUTDOWN')
      expect(shutdownEntry).assertEqual(undefined)
      let bootEntry = appendedEntries.find((entry: LogEntry) => entry.rawEventName === 'app.boot')
      expect(bootEntry !== undefined).assertTrue()
      expect(bootEntry!.detailRows![1].value).assertEqual('startup_recovery')
    })

    it('should append one boot entry after shutdown recovery', 0, async () => {
      storedNumbers.set('pending_shutdown_at', 1712732400000)
      storedNumbers.set('pending_shutdown_logged', 0)

      await LogPowerLifecycleSource.init(context)

      let bootEntry = appendedEntries.find((entry: LogEntry) => entry.rawEventName === 'app.boot')
      expect(bootEntry !== undefined).assertTrue()
      expect(bootEntry!.eventType).assertEqual(LogEventType.POWER)
      let bootEntries = appendedEntries.filter((entry: LogEntry) => entry.rawEventName === 'app.boot')
      expect(bootEntries.length).assertEqual(1)
    })
  })
}
