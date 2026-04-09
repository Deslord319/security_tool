import { beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'

import {
  ALL_LOG_EVENT_TYPES,
  DEFAULT_LOG_STORAGE_CONFIG,
  DEFAULT_SUBSCRIPTION_CONFIG,
  LogStorageConfig
} from '../../main/ets/models/DataModels'
import { LogConfigRepository } from '../../main/ets/services/log-manage/repository/LogConfigRepository'

interface LogConfigRepositoryContractAccess {
  context: common.UIAbilityContext | null
  storageConfig: LogStorageConfig
  sanitizeSubscribedTypes(types: number[]): number[]
}

export default function logConfigRepositoryTest() {
  describe('LogConfigRepository', () => {
    let access: LogConfigRepositoryContractAccess

    beforeEach(() => {
      access = LogConfigRepository as Object as LogConfigRepositoryContractAccess
      access.context = null
      access.storageConfig = {
        maxLocalEntries: DEFAULT_LOG_STORAGE_CONFIG.maxLocalEntries,
        retentionDays: DEFAULT_LOG_STORAGE_CONFIG.retentionDays
      }
    })

    it('should expose current storage config synchronously', 0, () => {
      let config = LogConfigRepository.getStorageConfigSync()

      expect(config.maxLocalEntries).assertEqual(DEFAULT_LOG_STORAGE_CONFIG.maxLocalEntries)
      expect(config.retentionDays).assertEqual(DEFAULT_LOG_STORAGE_CONFIG.retentionDays)
    })

    it('should reject save when repository is not initialized', 0, async () => {
      let result = await LogConfigRepository.saveStorageConfig({
        maxLocalEntries: 2000,
        retentionDays: 14
      })

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('not_initialized')
    })

    it('should return default subscription config without context', 0, async () => {
      let result = await LogConfigRepository.loadSubscriptionConfig()

      expect(result.subscribeAll).assertEqual(DEFAULT_SUBSCRIPTION_CONFIG.subscribeAll)
      expect(result.subscribedTypes.length).assertEqual(DEFAULT_SUBSCRIPTION_CONFIG.subscribedTypes.length)
    })

    it('should keep current storage config when load runs without context', 0, async () => {
      access.storageConfig = {
        maxLocalEntries: 3000,
        retentionDays: 60
      }

      let result = await LogConfigRepository.loadStorageConfig()

      expect(result.maxLocalEntries).assertEqual(3000)
      expect(result.retentionDays).assertEqual(60)
    })

    it('should sanitize subscribed types by filtering invalid and duplicate values', 0, () => {
      let sanitized = access.sanitizeSubscribedTypes([
        ALL_LOG_EVENT_TYPES[0],
        ALL_LOG_EVENT_TYPES[1],
        ALL_LOG_EVENT_TYPES[0],
        999
      ])

      expect(sanitized.length).assertEqual(2)
      expect(sanitized[0]).assertEqual(ALL_LOG_EVENT_TYPES[0])
      expect(sanitized[1]).assertEqual(ALL_LOG_EVENT_TYPES[1])
    })

    it('should return stable results when initialized with a fake context', 0, async () => {
      access.context = {} as common.UIAbilityContext

      let initResult = await LogConfigRepository.init({} as common.UIAbilityContext)
      let subscriptionResult = await LogConfigRepository.loadSubscriptionConfig()
      let saveResult = await LogConfigRepository.saveStorageConfig({
        maxLocalEntries: 7000,
        retentionDays: 999
      })

      expect(typeof initResult.success === 'boolean').assertTrue()
      expect(subscriptionResult.subscribedTypes.length > 0).assertTrue()
      expect(typeof saveResult.success === 'boolean').assertTrue()
    })
  })
}
