import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'

import {
  DEFAULT_LOG_STORAGE_CONFIG,
  PREF_KEY_LOG_MAX_ENTRIES,
  PREF_KEY_LOG_RETENTION_DAYS
} from '../../main/ets/models/LogModels'
import { PreferencesAccessor } from '../../main/ets/storage/preferences/PreferencesAccessor'
import { LogSettingsRepository } from '../../main/ets/services/log-manage/repository/LogSettingsRepository'

interface FakePrefWriteItem {
  key: string
  value: Object
}

class FakePreferencesAccessor {
  private values: Map<string, Object> = new Map<string, Object>()
  setManyResult: boolean = true

  async getBoolean(key: string, defaultValue: boolean): Promise<boolean> {
    let val = this.values.get(key)
    return val !== undefined ? val as boolean : defaultValue
  }

  async getNumber(key: string, defaultValue: number): Promise<number> {
    let val = this.values.get(key)
    return val !== undefined ? val as number : defaultValue
  }

  async getJsonArray<T>(key: string, defaultValue: T[]): Promise<T[]> {
    let val = this.values.get(key)
    return Array.isArray(val) ? val as T[] : defaultValue
  }

  async setMany(items: FakePrefWriteItem[]): Promise<boolean> {
    if (!this.setManyResult) {
      return false
    }
    for (let item of items) {
      this.values.set(item.key, item.value)
    }
    return true
  }

  set(key: string, value: Object): void {
    this.values.set(key, value)
  }

  get(key: string): Object | undefined {
    return this.values.get(key)
  }
}

export default function logSettingsRepositoryTest() {
  describe('LogSettingsRepository', () => {
    let mockKit: MockKit
    let fakeAccessor: FakePreferencesAccessor

    beforeEach(() => {
      mockKit = new MockKit()
      fakeAccessor = new FakePreferencesAccessor()
      let ofMock = mockKit.mockFunc(PreferencesAccessor, PreferencesAccessor.of)
      when(ofMock)(ArgumentMatchers.any).afterReturn(fakeAccessor as never as PreferencesAccessor)
    })

    afterEach(() => {
      mockKit.clearAll()
    })

    it('should load default storage config after init when store is empty', 0, async () => {
      let initResult = await LogSettingsRepository.init({} as common.UIAbilityContext)
      let config = await LogSettingsRepository.loadStorageConfig()

      expect(initResult.success).assertTrue()
      expect(config.maxLocalEntries).assertEqual(DEFAULT_LOG_STORAGE_CONFIG.maxLocalEntries)
      expect(config.retentionDays).assertEqual(DEFAULT_LOG_STORAGE_CONFIG.retentionDays)
    })

    it('should save supported max entries option after init', 0, async () => {
      await LogSettingsRepository.init({} as common.UIAbilityContext)

      let result = await LogSettingsRepository.saveStorageConfig({
        maxLocalEntries: 100000,
        retentionDays: 0
      })

      expect(result.success).assertTrue()
      expect(fakeAccessor.get(PREF_KEY_LOG_MAX_ENTRIES) as number).assertEqual(100000)
      expect(fakeAccessor.get(PREF_KEY_LOG_RETENTION_DAYS) as number)
        .assertEqual(DEFAULT_LOG_STORAGE_CONFIG.retentionDays)
    })

    it('should migrate removed max entries option to default on load', 0, async () => {
      await LogSettingsRepository.init({} as common.UIAbilityContext)
      fakeAccessor.set(PREF_KEY_LOG_MAX_ENTRIES, 1000)

      let config = await LogSettingsRepository.loadStorageConfig()

      expect(config.maxLocalEntries).assertEqual(DEFAULT_LOG_STORAGE_CONFIG.maxLocalEntries)
    })

  })
}
