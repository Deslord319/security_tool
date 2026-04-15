import { describe, expect, it } from '@ohos/hypium'

import { DEFAULT_LOG_STORAGE_CONFIG } from '../../main/ets/models/DataModels'
import { LogSettingsRepository } from '../../main/ets/services/log-manage/repository/LogSettingsRepository'

export default function logSettingsRepositoryTest() {
  describe('LogSettingsRepository', () => {
    it('should return default storage config before initialization', 0, async () => {
      let config = await LogSettingsRepository.loadStorageConfig()

      expect(config.maxLocalEntries).assertEqual(DEFAULT_LOG_STORAGE_CONFIG.maxLocalEntries)
      expect(config.retentionDays).assertEqual(DEFAULT_LOG_STORAGE_CONFIG.retentionDays)
    })

    it('should reject save before initialization', 0, async () => {
      let result = await LogSettingsRepository.saveStorageConfig({
        maxLocalEntries: 2000,
        retentionDays: 14
      })

      expect(result !== undefined).assertTrue()
    })
  })
}
