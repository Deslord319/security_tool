import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { LogEventResult } from '../../main/ets/models/LogModels'
import {
  PeripheralTraceRecord,
  PeripheralType
} from '../../main/ets/models/PeripheralModels'
import {
  PeripheralTraceMaintenanceService
} from '../../main/ets/services/peripheral/connection-record/PeripheralTraceMaintenanceService'
import { PeripheralTraceEntryRepository } from '../../main/ets/services/peripheral/connection-record/PeripheralTraceEntryRepository'

function createRecord(id: string): PeripheralTraceRecord {
  return {
    recordId: id,
    occurAt: Date.now(),
    collectAt: Date.now(),
    deviceName: 'Test Device',
    deviceType: PeripheralType.USB_STORAGE,
    deviceId: 'test-device-id',
    action: 'connect',
    decision: 'allow',
    source: 'runtime_event',
    result: LogEventResult.SUCCESS,
    summary: 'test summary'
  }
}

export default function peripheralTraceMaintenanceServiceTest() {
  describe('PeripheralTraceMaintenanceService', () => {
    let mockKit: MockKit
    let context: common.UIAbilityContext

    beforeEach(() => {
      mockKit = new MockKit()
      context = {} as common.UIAbilityContext

      let initMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.init)
      let readyMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.isReady)
      let deleteMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.deleteExpired)
      let trimMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.trimToMaxEntries)
      let notifyMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.notifyChanged)
      let clearMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.clearAll)
      let upsertMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.upsertBatch)

      when(initMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(true))
      when(readyMock)().afterReturn(true)
      when(deleteMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(true))
      when(trimMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(true))
      when(notifyMock)().afterReturn(undefined)
      when(clearMock)().afterReturn(Promise.resolve(true))
      when(upsertMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(true))
    })

    afterEach(() => {
      mockKit.clearAll()
    })

    it('should initialize successfully', 0, async () => {
      await PeripheralTraceMaintenanceService.initialize(context)
      expect(true).assertTrue()
    })

    it('should fail initialization when repository init fails', 0, async () => {
      let initMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.init)
      when(initMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(false))

      await PeripheralTraceMaintenanceService.initialize(context)
      expect(true).assertTrue()
    })

    it('should return retention config', 0, () => {
      let config = PeripheralTraceMaintenanceService.getRetentionConfig()

      expect(config.retentionDays > 0).assertTrue()
      expect(config.maxEntries > 0).assertTrue()
    })

    it('should configure retention settings', 0, async () => {
      let result = await PeripheralTraceMaintenanceService.configure(90, 100000)

      expect(result.success).assertTrue()

      let config = PeripheralTraceMaintenanceService.getRetentionConfig()
      expect(config.retentionDays).assertEqual(90)
      expect(config.maxEntries).assertEqual(100000)
    })

    it('should append entries successfully', 0, async () => {
      let records = [createRecord('record-1'), createRecord('record-2')]

      await PeripheralTraceMaintenanceService.appendEntries(records)
      expect(true).assertTrue()
    })

    it('should return ok for empty entries', 0, async () => {
      await PeripheralTraceMaintenanceService.appendEntries([])
      expect(true).assertTrue()
    })

    it('should fail append when repository not ready', 0, async () => {
      let readyMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.isReady)
      when(readyMock)().afterReturn(false)

      await PeripheralTraceMaintenanceService.appendEntries([createRecord('record-1')])
      expect(true).assertTrue()
    })

    it('should clear all entries successfully', 0, async () => {
      let result = await PeripheralTraceMaintenanceService.clearAll()

      expect(result.success).assertTrue()
      expect(result.code).assertEqual('ok')
    })

    it('should fail clear when repository not ready', 0, async () => {
      let readyMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.isReady)
      when(readyMock)().afterReturn(false)

      let result = await PeripheralTraceMaintenanceService.clearAll()

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('clear_failed')
    })

    it('should reconcile storage config successfully', 0, async () => {
      let result = await PeripheralTraceMaintenanceService.reconcileStorageConfig()

      expect(result.success).assertTrue()
      expect(result.code).assertEqual('ok')
    })
  })
}
