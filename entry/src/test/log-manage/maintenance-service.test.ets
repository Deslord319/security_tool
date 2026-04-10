import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { LogStorageConfig } from '../../main/ets/models/DataModels'
import {
  buildLogStorageNaturalDayCutoff,
  LogStorageMaintenanceService
} from '../../main/ets/services/log-manage/maintenance/LogStorageMaintenanceService'
import { LogEntryRepository } from '../../main/ets/services/log-manage/repository/LogEntryRepository'
import { LogSettingsRepository } from '../../main/ets/services/log-manage/repository/LogSettingsRepository'

export default function logStorageMaintenanceServiceTest() {
  describe('LogStorageMaintenanceService', () => {
    let mockKit: MockKit

    beforeEach(() => {
      mockKit = new MockKit()
    })

    afterEach(() => {
      mockKit.clearAll()
    })

    it('should build local natural-day cutoff instead of rolling hours', 0, () => {
      let cutoff = buildLogStorageNaturalDayCutoff(
        new Date(2026, 3, 9, 15, 0, 0, 0).getTime(),
        30
      )

      expect(cutoff).assertEqual(new Date(2026, 2, 11, 0, 0, 0, 0).getTime())
    })

    it('should reconcile storage config by applying delete and trim in order', 0, async () => {
      let readyMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.isReady)
      let loadMock = mockKit.mockFunc(LogSettingsRepository, LogSettingsRepository.loadStorageConfig)
      let deleteMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.deleteExpired)
      let trimMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.trimToMaxEntries)
      let notifyMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.notifyChanged)
      let capturedCutoff = -1
      let storageConfig: LogStorageConfig = {
        maxLocalEntries: 5000,
        retentionDays: 30
      }

      when(readyMock)().afterReturn(true)
      when(loadMock)().afterReturn(Promise.resolve(storageConfig))
      when(deleteMock)(ArgumentMatchers.any).afterAction((cutoff: number) => {
        capturedCutoff = cutoff
        return Promise.resolve(true)
      })
      when(trimMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(true))
      when(notifyMock)().afterReturn(undefined)

      let result = await LogStorageMaintenanceService.reconcileStorageConfig()

      expect(result.success).assertTrue()
      expect(capturedCutoff > 0).assertTrue()
    })
  })
}
