import { afterEach, describe, expect, it } from '@ohos/hypium'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { SecurityEventResult } from '../../main/ets/models/CommonModels'
import { PeripheralTraceRecord, PeripheralType } from '../../main/ets/models/PeripheralModels'
import { PeripheralConnectionRecordBluetoothAclConsumer } from '../../main/ets/services/peripheral/connection-record/PeripheralConnectionRecordBluetoothAclConsumer'
import {
  PeripheralBluetoothAclAction,
  PeripheralBluetoothAclProducerPayload,
  PeripheralConnectionRecordProducerEvent
} from '../../main/ets/services/peripheral/connection-record/PeripheralConnectionRecordProducerContract'
import { BluetoothPolicySnapshotTraceService } from '../../main/ets/services/peripheral/connection-record/BluetoothPolicySnapshotTraceService'
import {
  BluetoothConnectedDeviceSnapshot,
  BluetoothRuntimeConnectionStore
} from '../../main/ets/services/peripheral/connection-record/BluetoothRuntimeConnectionStore'
import {
  PeripheralTraceMaintenanceService,
  PeripheralTraceMutationResult
} from '../../main/ets/services/peripheral/connection-record/PeripheralTraceMaintenanceService'

interface BluetoothAclOverrides {
  deviceId?: string
  action?: PeripheralBluetoothAclAction
  occurAt?: number
  deviceName?: string
}

function buildBluetoothAclEvent(overrides?: BluetoothAclOverrides): PeripheralConnectionRecordProducerEvent {
  const payload: PeripheralBluetoothAclProducerPayload = {
    deviceId: overrides?.deviceId ?? '11:22:33:44:55:66',
    action: overrides?.action ?? 'connect',
    occurAt: overrides?.occurAt ?? 200,
    deviceName: overrides?.deviceName === undefined ? 'Bluetooth Keyboard' : overrides.deviceName
  }
  return {
    source: 'runtime',
    channel: 'bluetooth_acl',
    eventName: 'bluetooth_acl_state_change',
    bluetoothAcl: payload
  }
}

export default function peripheralConnectionRecordBluetoothAclConsumerTest() {
  describe('PeripheralConnectionRecordBluetoothAclConsumer', () => {
    afterEach(() => {
      BluetoothPolicySnapshotTraceService.resetForTest()
      BluetoothRuntimeConnectionStore.resetForTest()
    })

    it('U-BT-001 should map system device address connect event to allow record', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()

      const record = await consumer.consume(buildBluetoothAclEvent())

      expect(record !== null).assertTrue()
      expect(record?.action).assertEqual('connect')
      expect(record?.decision).assertEqual('allow')
      expect(record?.result).assertEqual(SecurityEventResult.SUCCESS)
      expect(record?.summary).assertEqual('蓝牙设备已连接')
      expect(record?.matchedPolicyKind).assertEqual('bluetooth_connection')
      expect(record?.effectivePolicyLabel).assertEqual('已启用')
      expect(record?.deviceType).assertEqual(PeripheralType.BLUETOOTH)
      expect(record?.deviceName).assertEqual('Bluetooth Keyboard')
      expect(record?.deviceId).assertEqual('MAC: 11:22:33:44:55:66')
      expect(record?.detail).assertEqual('aclState=STATE_CONNECTED, reason=--')
    })

    it('U-BT-002 should not mutate runtime connection cache after coordinator admission', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()

      const record = await consumer.consume(buildBluetoothAclEvent({
        deviceId: 'AA:BB:CC:DD:EE:FF',
        deviceName: 'Cached Headset'
      }))
      const snapshots = BluetoothRuntimeConnectionStore.captureConnectedDevices()

      expect(record?.deviceName).assertEqual('Cached Headset')
      expect(snapshots.length).assertEqual(0)
    })

    it('U-BT-003 should map system device address disconnect event', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()
      await consumer.consume(buildBluetoothAclEvent())

      const record = await consumer.consume(buildBluetoothAclEvent({ action: 'disconnect' }))
      const snapshots = BluetoothRuntimeConnectionStore.captureConnectedDevices()

      expect(record !== null).assertTrue()
      expect(record?.action).assertEqual('disconnect')
      expect(record?.summary).assertEqual('蓝牙设备已断开')
      expect(record?.detail).assertEqual('aclState=STATE_DISCONNECTED, reason=--')
      expect(snapshots.length).assertEqual(0)
    })

    it('U-BT-004 should reject missing payload or system device id', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()
      const missingPayload: PeripheralConnectionRecordProducerEvent = {
        source: 'runtime',
        channel: 'bluetooth_acl',
        eventName: 'bluetooth_acl_state_change'
      }

      const missingRecord = await consumer.consume(missingPayload)
      const missingIdRecord = await consumer.consume(buildBluetoothAclEvent({ deviceId: '' }))

      expect(missingRecord === null).assertTrue()
      expect(missingIdRecord === null).assertTrue()
    })

    it('U-BT-005 should reject event when coordinator did not resolve a valid name', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()

      const record = await consumer.consume(buildBluetoothAclEvent({ deviceName: '' }))

      expect(record === null).assertTrue()
    })

    it('U-BT-006 should normalize bluetooth system address format', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()

      const record = await consumer.consume(buildBluetoothAclEvent({ deviceId: 'aa-bb-cc-dd-ee-ff' }))

      expect(record !== null).assertTrue()
      expect(record?.deviceId).assertEqual('MAC: AA:BB:CC:DD:EE:FF')
    })

    it('U-BT-007 should serialize normalized callback payload', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()

      const record = await consumer.consume(buildBluetoothAclEvent())

      expect((record?.rawPayload?.length ?? 0) > 0).assertTrue()
      expect(record?.rawPayload?.includes('"deviceId":"11:22:33:44:55:66"')).assertTrue()
      expect(record?.rawPayload?.includes('"action":"connect"')).assertTrue()
    })

    it('U-BT-008 should use coordinator-provided cached name for disconnect', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()

      const connectRecord = await consumer.consume(buildBluetoothAclEvent({
        deviceId: 'AA:BB:CC:DD:EE:FF',
        deviceName: 'Cached Headset'
      }))
      const disconnectRecord = await consumer.consume(buildBluetoothAclEvent({
        deviceId: 'AA:BB:CC:DD:EE:FF',
        action: 'disconnect',
        deviceName: 'Cached Headset'
      }))

      expect(connectRecord?.deviceName).assertEqual('Cached Headset')
      expect(disconnectRecord?.deviceName).assertEqual('Cached Headset')
    })

    it('U-BT-009 should keep real disconnect after policy snapshot', 0, async () => {
      const mockKit = new MockKit()
      try {
        BluetoothPolicySnapshotTraceService.setNowProviderForTest(() => 1700000000000)
        BluetoothRuntimeConnectionStore.markDisabledDisconnectPending('MAC: 11:22:33:44:55:66')
        const appendMock = mockKit.mockFunc(
          PeripheralTraceMaintenanceService,
          PeripheralTraceMaintenanceService.appendEntries
        )
        when(appendMock)(ArgumentMatchers.any).afterAction((_records: PeripheralTraceRecord[]) => {
          return Promise.resolve({ success: true, code: 'ok' } as PeripheralTraceMutationResult)
        })
        await BluetoothPolicySnapshotTraceService.appendBluetoothDisabledPolicySnapshot([{
          rawDeviceId: '11:22:33:44:55:66',
          deviceId: 'MAC: 11:22:33:44:55:66',
          deviceName: 'Bluetooth Keyboard',
          rawPayload: '{}'
        } as BluetoothConnectedDeviceSnapshot])
        const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()

        const record = await consumer.consume(buildBluetoothAclEvent({ action: 'disconnect' }))

        expect(record !== null).assertTrue()
        expect(record?.action).assertEqual('disconnect')
        expect(record?.summary).assertEqual('蓝牙设备已断开')
        expect(record?.decision).assertEqual('deny')
        expect(record?.result).assertEqual(SecurityEventResult.BLOCKED)
        expect(record?.effectivePolicyLabel).assertEqual('已禁用')
        expect(record?.matchedPolicyKind).assertEqual('bluetooth_disabled')

        const repeatedRecord = await consumer.consume(buildBluetoothAclEvent({ action: 'disconnect' }))
        expect(repeatedRecord?.decision).assertEqual('allow')
        expect(repeatedRecord?.effectivePolicyLabel).assertEqual('已启用')

        BluetoothRuntimeConnectionStore.markDisabledDisconnectPending('MAC: 11:22:33:44:55:66')
        BluetoothRuntimeConnectionStore.trackConnectedDevice(
          '11:22:33:44:55:66',
          '{}',
          'Bluetooth Keyboard'
        )
        await consumer.consume(buildBluetoothAclEvent({ action: 'connect' }))
        const disconnectAfterReconnect = await consumer.consume(buildBluetoothAclEvent({ action: 'disconnect' }))
        expect(disconnectAfterReconnect?.decision).assertEqual('allow')
        expect(disconnectAfterReconnect?.effectivePolicyLabel).assertEqual('已启用')
      } finally {
        BluetoothPolicySnapshotTraceService.resetForTest()
        mockKit.clearAll()
      }
    })
  })
}
