import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { SecurityEventResult } from '../../main/ets/models/CommonModels'
import {
  PeripheralTraceRecord,
  PeripheralType
} from '../../main/ets/models/PeripheralModels'
import {
  BluetoothPolicySnapshotTraceService
} from '../../main/ets/services/peripheral/connection-record/BluetoothPolicySnapshotTraceService'
import {
  PeripheralTraceMaintenanceService,
  PeripheralTraceMutationResult
} from '../../main/ets/services/peripheral/connection-record/PeripheralTraceMaintenanceService'

function successMutationResult(): PeripheralTraceMutationResult {
  return { success: true, code: 'ok' } as PeripheralTraceMutationResult
}

export default function bluetoothPolicySnapshotTraceServiceTest() {
  describe('BluetoothPolicySnapshotTraceService', () => {
    let mockKit: MockKit
    let savedRecords: PeripheralTraceRecord[]

    beforeEach(() => {
      mockKit = new MockKit()
      savedRecords = []
      BluetoothPolicySnapshotTraceService.setNowProviderForTest(() => 1700000000000)
      let appendMock = mockKit.mockFunc(PeripheralTraceMaintenanceService, PeripheralTraceMaintenanceService.appendEntries)
      when(appendMock)(ArgumentMatchers.any).afterAction((records: PeripheralTraceRecord[]) => {
        savedRecords = records
        return Promise.resolve(successMutationResult())
      })
    })

    afterEach(() => {
      BluetoothPolicySnapshotTraceService.resetForTest()
      mockKit.clearAll()
    })

    it('should append blocked bluetooth policy snapshot for cached connected devices', 0, async () => {
      BluetoothPolicySnapshotTraceService.rememberRuntimeConnectedDevice(
        '11:22:33:44:55:66',
        '{"source":"acl"}'
      )
      const snapshots = BluetoothPolicySnapshotTraceService.captureCurrentConnectedDevices()

      const result = await BluetoothPolicySnapshotTraceService.appendBluetoothDisabledPolicySnapshotForCachedDevices(snapshots)

      expect(result.success).assertTrue()
      expect(savedRecords.length).assertEqual(1)
      expect(savedRecords[0].source).assertEqual('policy_snapshot')
      expect(savedRecords[0].action).assertEqual('discover')
      expect(savedRecords[0].deviceType).assertEqual(PeripheralType.BLUETOOTH)
      expect(savedRecords[0].deviceId).assertEqual('MAC: 11:22:33:44:55:66')
      expect(savedRecords[0].deviceName).assertEqual('未命名蓝牙设备')
      expect(savedRecords[0].decision).assertEqual('deny')
      expect(savedRecords[0].result).assertEqual(SecurityEventResult.BLOCKED)
      expect(savedRecords[0].rawEventName).assertEqual('bluetooth_global_policy')
      expect(savedRecords[0].matchedPolicyKind).assertEqual('bluetooth_disabled')
    })

    it('should deduplicate current bluetooth connection snapshots by normalized mac', 0, () => {
      BluetoothPolicySnapshotTraceService.rememberRuntimeConnectedDevice(
        '11:22:33:44:55:66',
        '{"source":"first"}'
      )
      BluetoothPolicySnapshotTraceService.rememberRuntimeConnectedDevice(
        '11-22-33-44-55-66',
        '{"source":"second"}'
      )

      const snapshots = BluetoothPolicySnapshotTraceService.captureCurrentConnectedDevices()

      expect(snapshots.length).assertEqual(1)
      expect(snapshots[0].deviceId).assertEqual('MAC: 11:22:33:44:55:66')
    })

    it('should avoid appending when no connected bluetooth devices are captured', 0, async () => {
      const snapshots = BluetoothPolicySnapshotTraceService.captureCurrentConnectedDevices()

      const result = await BluetoothPolicySnapshotTraceService.appendBluetoothDisabledPolicySnapshotForCachedDevices(snapshots)

      expect(result.success).assertTrue()
      expect(savedRecords.length).assertEqual(0)
    })

    it('should use runtime acl connected cache as the snapshot source', 0, async () => {
      BluetoothPolicySnapshotTraceService.rememberRuntimeConnectedDevice(
        'AA:BB:CC:DD:EE:FF',
        '{"source":"acl"}'
      )
      const snapshots = BluetoothPolicySnapshotTraceService.captureCurrentConnectedDevices()

      const result = await BluetoothPolicySnapshotTraceService.appendBluetoothDisabledPolicySnapshotForCachedDevices(snapshots)

      expect(result.success).assertTrue()
      expect(savedRecords.length).assertEqual(1)
      expect(savedRecords[0].deviceId).assertEqual('MAC: AA:BB:CC:DD:EE:FF')
      expect(savedRecords[0].deviceName).assertEqual('未命名蓝牙设备')
    })

    it('should suppress one matching disconnect after successful snapshot append', 0, async () => {
      BluetoothPolicySnapshotTraceService.rememberRuntimeConnectedDevice(
        'AA:BB:CC:DD:EE:FF',
        '{}'
      )
      const snapshots = BluetoothPolicySnapshotTraceService.captureCurrentConnectedDevices()

      await BluetoothPolicySnapshotTraceService.appendBluetoothDisabledPolicySnapshot(snapshots)

      expect(BluetoothPolicySnapshotTraceService.shouldSuppressPolicyDisconnect('MAC: AA:BB:CC:DD:EE:FF')).assertTrue()
      expect(BluetoothPolicySnapshotTraceService.shouldSuppressPolicyDisconnect('MAC: AA:BB:CC:DD:EE:FF')).assertFalse()
    })

    it('should expire suppressed bluetooth disconnects after ttl', 0, async () => {
      let now = 1700000000000
      BluetoothPolicySnapshotTraceService.setNowProviderForTest(() => now)
      BluetoothPolicySnapshotTraceService.rememberRuntimeConnectedDevice(
        'AA:BB:CC:DD:EE:FF',
        '{}'
      )
      const snapshots = BluetoothPolicySnapshotTraceService.captureCurrentConnectedDevices()
      await BluetoothPolicySnapshotTraceService.appendBluetoothDisabledPolicySnapshot(snapshots)
      now += 31000

      expect(BluetoothPolicySnapshotTraceService.shouldSuppressPolicyDisconnect('MAC: AA:BB:CC:DD:EE:FF')).assertFalse()
    })
  })
}
