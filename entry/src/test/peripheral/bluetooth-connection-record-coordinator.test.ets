import { afterEach, describe, expect, it } from '@ohos/hypium'
import { connection } from '@kit.ConnectivityKit'
import { BluetoothConnectionRecordCoordinator } from '../../main/ets/services/peripheral/connection-record/BluetoothConnectionRecordCoordinator'
import { BluetoothDeviceNameResolver } from '../../main/ets/services/peripheral/connection-record/BluetoothDeviceNameResolver'
import { BluetoothRuntimeConnectionStore } from '../../main/ets/services/peripheral/connection-record/BluetoothRuntimeConnectionStore'
import { PeripheralConnectionRecordProducerEvent } from '../../main/ets/services/peripheral/connection-record/PeripheralConnectionRecordProducerContract'

function buildAclEvent(
  deviceId: string,
  action: 'connect' | 'disconnect',
  occurAt: number = Date.now()
): PeripheralConnectionRecordProducerEvent {
  return {
    source: 'runtime',
    channel: 'bluetooth_acl',
    eventName: 'bluetooth_acl_state_change',
    bluetoothAcl: {
      deviceId: deviceId,
      action: action,
      occurAt: occurAt
    }
  }
}

function buildBondEvent(
  deviceId: string,
  state: connection.BondState
): PeripheralConnectionRecordProducerEvent {
  return {
    source: 'runtime',
    channel: 'bluetooth_bond',
    eventName: 'bluetooth_bond_state_change',
    bluetoothBond: {
      deviceId: deviceId,
      state: state,
      occurAt: Date.now()
    }
  }
}

async function wait(delayMs: number): Promise<void> {
  await new Promise<void>((resolve) => setTimeout(resolve, delayMs))
}

export default function bluetoothConnectionRecordCoordinatorTest() {
  describe('BluetoothConnectionRecordCoordinator', () => {
    afterEach(() => {
      BluetoothRuntimeConnectionStore.resetForTest()
    })

    it('should query immediately then retry at 500 and 1500ms', 0, async () => {
      let queryCount = 0
      let now = 1000
      const waits: number[] = []
      BluetoothRuntimeConnectionStore.setRemoteDeviceNameProviderForTest(() => {
        queryCount++
        return queryCount === 3 ? 'Resolved Keyboard' : ''
      })
      const resolver = new BluetoothDeviceNameResolver()
      resolver.setTimingProvidersForTest(
        () => now,
        async (delayMs: number): Promise<void> => {
          waits.push(delayMs)
          now += delayMs
        }
      )

      const immediateName = resolver.resolveImmediate('11:22:33:44:55:66')
      const name = await resolver.resolve('event-1', '11:22:33:44:55:66', 1000, immediateName)

      expect(name).assertEqual('Resolved Keyboard')
      expect(queryCount).assertEqual(3)
      expect(waits.length).assertEqual(2)
      expect(waits[0]).assertEqual(500)
      expect(waits[1]).assertEqual(1000)
    })

    it('should reject generic bluetooth name', 0, () => {
      expect(BluetoothRuntimeConnectionStore.isValidResolvedDeviceName('蓝牙设备')).assertFalse()
      expect(BluetoothRuntimeConnectionStore.isValidResolvedDeviceName('Bluetooth Keyboard')).assertTrue()
    })

    it('should admit named acl immediately without waiting for bond', 0, async () => {
      BluetoothRuntimeConnectionStore.setRemoteDeviceNameProviderForTest(() => 'Bluetooth Keyboard')
      const coordinator = new BluetoothConnectionRecordCoordinator()
      coordinator.setPairStateProviderForTest(() => connection.BondState.BOND_STATE_INVALID)
      const admitted: PeripheralConnectionRecordProducerEvent[] = []
      coordinator.setRecordSink(async (event: PeripheralConnectionRecordProducerEvent): Promise<boolean> => {
        admitted.push(event)
        return true
      })

      const persisted = await coordinator.handleEvent(buildAclEvent('11:22:33:44:55:66', 'connect'))

      expect(persisted).assertTrue()
      expect(admitted.length).assertEqual(1)
      expect(admitted[0].bluetoothAcl?.deviceName).assertEqual('Bluetooth Keyboard')
      coordinator.stop()
    })

    it('should use same-address cache when immediate lookup fails', 0, async () => {
      BluetoothRuntimeConnectionStore.trackConnectedDevice('11:22:33:44:55:66', '{}', 'Cached Keyboard')
      BluetoothRuntimeConnectionStore.setRemoteDeviceNameProviderForTest(() => '')
      const coordinator = new BluetoothConnectionRecordCoordinator()
      coordinator.setPairStateProviderForTest(() => connection.BondState.BOND_STATE_INVALID)
      const admitted: PeripheralConnectionRecordProducerEvent[] = []
      coordinator.setRecordSink(async (event: PeripheralConnectionRecordProducerEvent): Promise<boolean> => {
        admitted.push(event)
        return true
      })

      await coordinator.handleEvent(buildAclEvent('11:22:33:44:55:66', 'disconnect'))

      expect(admitted.length).assertEqual(1)
      expect(admitted[0].bluetoothAcl?.deviceName).assertEqual('Cached Keyboard')
      coordinator.stop()
    })

    it('should keep connection fact with missing name but never admit record', 0, async () => {
      BluetoothRuntimeConnectionStore.setRemoteDeviceNameProviderForTest(() => '')
      let now = 1000
      const resolver = new BluetoothDeviceNameResolver()
      resolver.setTimingProvidersForTest(
        () => now,
        async (delayMs: number): Promise<void> => {
          now += delayMs
        }
      )
      const coordinator = new BluetoothConnectionRecordCoordinator(resolver)
      coordinator.setPairStateProviderForTest(() => connection.BondState.BOND_STATE_INVALID)
      const admitted: PeripheralConnectionRecordProducerEvent[] = []
      coordinator.setRecordSink(async (event: PeripheralConnectionRecordProducerEvent): Promise<boolean> => {
        admitted.push(event)
        return true
      })

      await coordinator.handleEvent(buildAclEvent('22:33:44:55:66:77', 'connect', 1000))

      expect(admitted.length).assertEqual(0)
      expect(BluetoothRuntimeConnectionStore.captureConnectedDevices().length).assertEqual(1)
      coordinator.stop()
    })

    it('should not suppress another newly connected device during bonding', 0, async () => {
      BluetoothRuntimeConnectionStore.setRemoteDeviceNameProviderForTest((deviceId: string) => {
        return deviceId === '77:88:99:AA:BB:CC' ? 'Independent Mouse' : ''
      })
      const coordinator = new BluetoothConnectionRecordCoordinator()
      coordinator.setPairStateProviderForTest((deviceId: string) => {
        return deviceId === '11:22:33:44:55:66'
          ? connection.BondState.BOND_STATE_BONDING
          : connection.BondState.BOND_STATE_INVALID
      })
      const admitted: PeripheralConnectionRecordProducerEvent[] = []
      coordinator.setRecordSink(async (event: PeripheralConnectionRecordProducerEvent): Promise<boolean> => {
        admitted.push(event)
        return true
      })

      await coordinator.handleEvent(buildBondEvent(
        '11:22:33:44:55:66',
        connection.BondState.BOND_STATE_BONDING
      ))
      await coordinator.handleEvent(buildAclEvent('77:88:99:AA:BB:CC', 'connect'))

      expect(admitted.length).assertEqual(1)
      expect(admitted[0].bluetoothAcl?.deviceName).assertEqual('Independent Mouse')
      coordinator.stop()
    })

    it('should ignore temporary addresses with missing names and admit named final address', 0, async () => {
      BluetoothRuntimeConnectionStore.setRemoteDeviceNameProviderForTest((deviceId: string) => {
        return deviceId === 'CC:DD:EE:FF:00:11' ? 'Final Mouse' : ''
      })
      let now = 1000
      const resolver = new BluetoothDeviceNameResolver()
      resolver.setTimingProvidersForTest(
        () => now,
        async (delayMs: number): Promise<void> => {
          now += delayMs
        }
      )
      const coordinator = new BluetoothConnectionRecordCoordinator(resolver)
      coordinator.setPairStateProviderForTest((deviceId: string) => {
        return deviceId === 'CC:DD:EE:FF:00:11'
          ? connection.BondState.BOND_STATE_BONDED
          : connection.BondState.BOND_STATE_BONDING
      })
      const admitted: PeripheralConnectionRecordProducerEvent[] = []
      coordinator.setRecordSink(async (event: PeripheralConnectionRecordProducerEvent): Promise<boolean> => {
        admitted.push(event)
        return true
      })

      await coordinator.handleEvent(buildBondEvent(
        'AA:BB:CC:DD:EE:FF',
        connection.BondState.BOND_STATE_BONDING
      ))
      await coordinator.handleEvent(buildAclEvent('AA:BB:CC:DD:EE:01', 'connect', 1000))
      await coordinator.handleEvent(buildAclEvent('AA:BB:CC:DD:EE:01', 'disconnect', 1100))
      await coordinator.handleEvent(buildBondEvent(
        'CC:DD:EE:FF:00:11',
        connection.BondState.BOND_STATE_BONDED
      ))
      await coordinator.handleEvent(buildAclEvent('CC:DD:EE:FF:00:11', 'connect', 1200))

      expect(admitted.length).assertEqual(1)
      expect(admitted[0].bluetoothAcl?.deviceName).assertEqual('Final Mouse')
      coordinator.stop()
    })

    it('should cancel matching pairing candidate when pairing becomes invalid', 0, async () => {
      let queryCount = 0
      let releaseRetry: () => void = () => {}
      BluetoothRuntimeConnectionStore.setRemoteDeviceNameProviderForTest(() => {
        queryCount++
        return queryCount === 2 ? 'Late Headset' : ''
      })
      const resolver = new BluetoothDeviceNameResolver()
      resolver.setTimingProvidersForTest(
        () => Date.now(),
        (_delayMs: number): Promise<void> => {
          return new Promise<void>((resolve) => {
            releaseRetry = resolve
          })
        }
      )
      const coordinator = new BluetoothConnectionRecordCoordinator(resolver)
      coordinator.setPairStateProviderForTest(() => connection.BondState.BOND_STATE_BONDING)
      const admitted: PeripheralConnectionRecordProducerEvent[] = []
      coordinator.setRecordSink(async (event: PeripheralConnectionRecordProducerEvent): Promise<boolean> => {
        admitted.push(event)
        return true
      })

      await coordinator.handleEvent(buildBondEvent(
        '33:44:55:66:77:88',
        connection.BondState.BOND_STATE_BONDING
      ))
      const aclPromise = coordinator.handleEvent(buildAclEvent('33:44:55:66:77:88', 'connect'))
      await coordinator.handleEvent(buildBondEvent(
        '33:44:55:66:77:88',
        connection.BondState.BOND_STATE_INVALID
      ))
      releaseRetry()
      await aclPromise

      expect(admitted.length).assertEqual(0)
      coordinator.stop()
    })

    it('should keep unrelated acl name task alive when another pairing becomes invalid', 0, async () => {
      let queryCount = 0
      let releaseRetry: () => void = () => {}
      BluetoothRuntimeConnectionStore.setRemoteDeviceNameProviderForTest((deviceId: string) => {
        if (deviceId !== '77:88:99:AA:BB:CC') {
          return ''
        }
        queryCount++
        return queryCount === 2 ? 'Independent Headset' : ''
      })
      const resolver = new BluetoothDeviceNameResolver()
      resolver.setTimingProvidersForTest(
        () => Date.now(),
        (_delayMs: number): Promise<void> => {
          return new Promise<void>((resolve) => {
            releaseRetry = resolve
          })
        }
      )
      const coordinator = new BluetoothConnectionRecordCoordinator(resolver)
      coordinator.setPairStateProviderForTest((deviceId: string) => {
        return deviceId === '33:44:55:66:77:88'
          ? connection.BondState.BOND_STATE_BONDING
          : connection.BondState.BOND_STATE_INVALID
      })
      const admitted: PeripheralConnectionRecordProducerEvent[] = []
      coordinator.setRecordSink(async (event: PeripheralConnectionRecordProducerEvent): Promise<boolean> => {
        admitted.push(event)
        return true
      })

      await coordinator.handleEvent(buildBondEvent(
        '33:44:55:66:77:88',
        connection.BondState.BOND_STATE_BONDING
      ))
      const aclPromise = coordinator.handleEvent(buildAclEvent('77:88:99:AA:BB:CC', 'connect'))
      await coordinator.handleEvent(buildBondEvent(
        '33:44:55:66:77:88',
        connection.BondState.BOND_STATE_INVALID
      ))
      releaseRetry()
      await aclPromise

      expect(admitted.length).assertEqual(1)
      expect(admitted[0].bluetoothAcl?.deviceName).assertEqual('Independent Headset')
      coordinator.stop()
    })

    it('should not fabricate record after bonded acl wait timeout', 0, async () => {
      BluetoothRuntimeConnectionStore.setRemoteDeviceNameProviderForTest(() => 'Late Keyboard')
      const coordinator = new BluetoothConnectionRecordCoordinator(undefined, 20, 5)
      coordinator.setPairStateProviderForTest(() => connection.BondState.BOND_STATE_BONDED)
      const admitted: PeripheralConnectionRecordProducerEvent[] = []
      coordinator.setRecordSink(async (event: PeripheralConnectionRecordProducerEvent): Promise<boolean> => {
        admitted.push(event)
        return true
      })

      await coordinator.handleEvent(buildBondEvent(
        '44:55:66:77:88:99',
        connection.BondState.BOND_STATE_BONDED
      ))
      await wait(10)
      expect(admitted.length).assertEqual(0)

      await coordinator.handleEvent(buildAclEvent('44:55:66:77:88:99', 'connect'))
      expect(admitted.length).assertEqual(1)
      coordinator.stop()
    })

    it('should not duplicate record when acl arrives before bonded callback', 0, async () => {
      BluetoothRuntimeConnectionStore.setRemoteDeviceNameProviderForTest(() => 'Early Keyboard')
      const coordinator = new BluetoothConnectionRecordCoordinator(undefined, 20, 5)
      coordinator.setPairStateProviderForTest(() => connection.BondState.BOND_STATE_BONDING)
      const admitted: PeripheralConnectionRecordProducerEvent[] = []
      coordinator.setRecordSink(async (event: PeripheralConnectionRecordProducerEvent): Promise<boolean> => {
        admitted.push(event)
        return true
      })

      const aclResult = await coordinator.handleEvent(buildAclEvent('44:55:66:77:88:99', 'connect'))
      expect(aclResult).assertTrue()
      expect(admitted.length).assertEqual(0)
      await coordinator.handleEvent(buildBondEvent(
        '44:55:66:77:88:99',
        connection.BondState.BOND_STATE_BONDED
      ))
      await wait(10)

      expect(admitted.length).assertEqual(1)
      coordinator.stop()
    })

    it('should retain explicit bonding candidate when bonding callback refreshes address', 0, async () => {
      BluetoothRuntimeConnectionStore.setRemoteDeviceNameProviderForTest(() => 'Early Mouse')
      const coordinator = new BluetoothConnectionRecordCoordinator(undefined, 20, 5)
      coordinator.setPairStateProviderForTest(() => connection.BondState.BOND_STATE_BONDING)
      const admitted: PeripheralConnectionRecordProducerEvent[] = []
      coordinator.setRecordSink(async (event: PeripheralConnectionRecordProducerEvent): Promise<boolean> => {
        admitted.push(event)
        return true
      })

      await coordinator.handleEvent(buildAclEvent('44:55:66:77:88:99', 'connect'))
      await coordinator.handleEvent(buildBondEvent(
        'AA:BB:CC:DD:EE:FF',
        connection.BondState.BOND_STATE_BONDING
      ))
      await coordinator.handleEvent(buildBondEvent(
        '44:55:66:77:88:99',
        connection.BondState.BOND_STATE_BONDED
      ))

      expect(admitted.length).assertEqual(1)
      expect(admitted[0].bluetoothAcl?.deviceName).assertEqual('Early Mouse')
      coordinator.stop()
    })

    it('should not extend total pairing timeout when bonding address refreshes', 0, async () => {
      BluetoothRuntimeConnectionStore.setRemoteDeviceNameProviderForTest(() => 'Timeout Mouse')
      const coordinator = new BluetoothConnectionRecordCoordinator(undefined, 20, 5)
      coordinator.setPairStateProviderForTest(() => connection.BondState.BOND_STATE_BONDING)
      const admitted: PeripheralConnectionRecordProducerEvent[] = []
      coordinator.setRecordSink(async (event: PeripheralConnectionRecordProducerEvent): Promise<boolean> => {
        admitted.push(event)
        return true
      })

      await coordinator.handleEvent(buildAclEvent('44:55:66:77:88:99', 'connect'))
      await wait(15)
      await coordinator.handleEvent(buildBondEvent(
        'AA:BB:CC:DD:EE:FF',
        connection.BondState.BOND_STATE_BONDING
      ))
      await wait(15)
      await coordinator.handleEvent(buildBondEvent(
        '44:55:66:77:88:99',
        connection.BondState.BOND_STATE_BONDED
      ))

      expect(admitted.length).assertEqual(0)
      coordinator.stop()
    })

    it('should not suppress acl after pairing session timeout', 0, async () => {
      BluetoothRuntimeConnectionStore.setRemoteDeviceNameProviderForTest(() => 'New Speaker')
      const coordinator = new BluetoothConnectionRecordCoordinator(undefined, 5, 5)
      coordinator.setPairStateProviderForTest((deviceId: string) => {
        return deviceId === '55:66:77:88:99:AA'
          ? connection.BondState.BOND_STATE_BONDING
          : connection.BondState.BOND_STATE_INVALID
      })
      const admitted: PeripheralConnectionRecordProducerEvent[] = []
      coordinator.setRecordSink(async (event: PeripheralConnectionRecordProducerEvent): Promise<boolean> => {
        admitted.push(event)
        return true
      })

      await coordinator.handleEvent(buildBondEvent(
        '55:66:77:88:99:AA',
        connection.BondState.BOND_STATE_BONDING
      ))
      await wait(10)
      await coordinator.handleEvent(buildAclEvent('66:77:88:99:AA:BB', 'connect'))

      expect(admitted.length).assertEqual(1)
      coordinator.stop()
    })

    it('should keep repeated named acl callbacks without generic dedupe', 0, async () => {
      BluetoothRuntimeConnectionStore.setRemoteDeviceNameProviderForTest(() => 'Bluetooth Keyboard')
      const coordinator = new BluetoothConnectionRecordCoordinator()
      coordinator.setPairStateProviderForTest(() => connection.BondState.BOND_STATE_INVALID)
      const admitted: PeripheralConnectionRecordProducerEvent[] = []
      coordinator.setRecordSink(async (event: PeripheralConnectionRecordProducerEvent): Promise<boolean> => {
        admitted.push(event)
        return true
      })

      await coordinator.handleEvent(buildAclEvent('11:22:33:44:55:66', 'connect'))
      await coordinator.handleEvent(buildAclEvent('11:22:33:44:55:66', 'connect'))

      expect(admitted.length).assertEqual(2)
      coordinator.stop()
    })

    it('should admit acl immediately when pair state is already bonded', 0, async () => {
      BluetoothRuntimeConnectionStore.setRemoteDeviceNameProviderForTest(() => 'Bonded Keyboard')
      const coordinator = new BluetoothConnectionRecordCoordinator()
      coordinator.setPairStateProviderForTest(() => connection.BondState.BOND_STATE_BONDED)
      const admitted: PeripheralConnectionRecordProducerEvent[] = []
      coordinator.setRecordSink(async (event: PeripheralConnectionRecordProducerEvent): Promise<boolean> => {
        admitted.push(event)
        return true
      })

      await coordinator.handleEvent(buildAclEvent('88:99:AA:BB:CC:DD', 'connect'))

      expect(admitted.length).assertEqual(1)
      expect(admitted[0].bluetoothAcl?.deviceName).assertEqual('Bonded Keyboard')
      coordinator.stop()
    })

    it('should keep cached name in connected snapshot when connect lookup is empty', 0, async () => {
      BluetoothRuntimeConnectionStore.trackConnectedDevice(
        '99:AA:BB:CC:DD:EE',
        '{}',
        'Cached Speaker'
      )
      BluetoothRuntimeConnectionStore.setRemoteDeviceNameProviderForTest(() => '')
      const coordinator = new BluetoothConnectionRecordCoordinator()
      coordinator.setPairStateProviderForTest(() => connection.BondState.BOND_STATE_INVALID)
      coordinator.setRecordSink(async (_event: PeripheralConnectionRecordProducerEvent): Promise<boolean> => true)

      await coordinator.handleEvent(buildAclEvent('99:AA:BB:CC:DD:EE', 'connect'))

      const snapshots = BluetoothRuntimeConnectionStore.captureConnectedDevices()
      expect(snapshots.length).assertEqual(1)
      expect(snapshots[0].deviceName).assertEqual('Cached Speaker')
      coordinator.stop()
    })
  })
}
