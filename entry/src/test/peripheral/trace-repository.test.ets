import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { PeripheralTraceEntryRepository } from '../../main/ets/services/peripheral/connection-record/PeripheralTraceEntryRepository'
import {
  PeripheralTraceMaintenanceService,
  PeripheralTraceRetentionConfig
} from '../../main/ets/services/peripheral/connection-record/PeripheralTraceMaintenanceService'

export default function peripheralTraceRepositoryTest() {
  describe('PeripheralTraceMaintenanceService', () => {
    let mockKit: MockKit
    let originalRetentionDays: number
    let originalMaxEntries: number

    beforeEach(() => {
      mockKit = new MockKit()
      let originalConfig: PeripheralTraceRetentionConfig = PeripheralTraceMaintenanceService.getRetentionConfig()
      originalRetentionDays = originalConfig.retentionDays
      originalMaxEntries = originalConfig.maxEntries
    })

    afterEach(async (done: Function) => {
      let readyMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.isReady)
      let deleteExpiredMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.deleteExpired)
      let trimMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.trimToMaxEntries)
      when(readyMock)().afterReturn(true)
      when(deleteExpiredMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(true))
      when(trimMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(true))
      await PeripheralTraceMaintenanceService.configure(originalRetentionDays, originalMaxEntries)
      mockKit.clearAll()
      done()
    })

    it('should expose configured retention values through public config api', 0, async () => {
      let readyMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.isReady)
      let deleteExpiredMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.deleteExpired)
      let trimMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.trimToMaxEntries)
      when(readyMock)().afterReturn(true)
      when(deleteExpiredMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(true))
      when(trimMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(true))

      let result = await PeripheralTraceMaintenanceService.configure(2, 5)
      let config: PeripheralTraceRetentionConfig = PeripheralTraceMaintenanceService.getRetentionConfig()

      expect(result.success).assertTrue()
      expect(config.retentionDays).assertEqual(2)
      expect(config.maxEntries).assertEqual(5)
    })
  })

  describe('PeripheralTraceEntryRepository', () => {
    it('should notify listeners on change and stop after removal', 0, () => {
      let notificationCount = 0
      let listenerId = PeripheralTraceEntryRepository.addChangeListener(() => {
        notificationCount++
      })

      PeripheralTraceEntryRepository.notifyChanged()
      PeripheralTraceEntryRepository.removeChangeListener(listenerId)
      PeripheralTraceEntryRepository.notifyChanged()

      expect(notificationCount).assertEqual(1)
    })
  })
}
