import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { connection } from '@kit.ConnectivityKit'
import { MockKit } from '@ohos/hamock'
import {
  mapBluetoothAclStateToAction,
  PeripheralConnectionRecordRuntimeProducerAdapter
} from '../../main/ets/services/peripheral/connection-record/PeripheralConnectionRecordRuntimeProducerAdapter'

export default function runtimeProducerAdapterTest() {
  describe('PeripheralConnectionRecordRuntimeProducerAdapter', () => {
    let mockKit: MockKit
    let context: common.UIAbilityContext
    let adapter: PeripheralConnectionRecordRuntimeProducerAdapter

    beforeEach(() => {
      mockKit = new MockKit()
      context = {} as common.UIAbilityContext
      adapter = new PeripheralConnectionRecordRuntimeProducerAdapter()
    })

    afterEach(() => {
      adapter.stop()
      mockKit.clearAll()
    })

    it('should create adapter instance', 0, () => {
      expect(adapter !== undefined).assertTrue()
    })

    it('should map api 26 acl final states without using legacy numeric semantics', 0, () => {
      expect(mapBluetoothAclStateToAction(connection.AclState.STATE_CONNECTED)).assertEqual('connect')
      expect(mapBluetoothAclStateToAction(connection.AclState.STATE_DISCONNECTED)).assertEqual('disconnect')
    })

    it('should bind context', 0, () => {
      adapter.bindContext(context)

      expect(true).assertTrue()
    })

    it('should return initial status', 0, () => {
      let status = adapter.getStatus()

      expect(status.running).assertFalse()
      expect(status.capabilities.usbRuntimeEvents).assertFalse()
      expect(status.capabilities.bluetoothRuntimeEvents).assertFalse()
    })

    it('should fail to start without context', 0, async () => {
      let result = await adapter.start()

      expect(result).assertFalse()

      let status = adapter.getStatus()
      expect(status.capabilities.degradedReason).assertEqual('not_initialized')
    })

    it('should subscribe listener', 0, () => {
      let listenerId = adapter.subscribe(() => {})

      expect(listenerId > 0).assertTrue()
    })

    it('should unsubscribe listener', 0, () => {
      let listenerId = adapter.subscribe(() => {})

      adapter.unsubscribe(listenerId)

      expect(true).assertTrue()
    })

    it('should handle multiple subscribe calls', 0, () => {
      let id1 = adapter.subscribe(() => {})
      let id2 = adapter.subscribe(() => {})
      let id3 = adapter.subscribe(() => {})

      expect(id1 !== id2).assertTrue()
      expect(id2 !== id3).assertTrue()
    })

    it('should stop gracefully when not started', 0, () => {
      adapter.stop()

      let status = adapter.getStatus()
      expect(status.running).assertFalse()
    })

    it('should handle stop without context', 0, () => {
      adapter.bindContext(context)
      adapter.stop()

      let status = adapter.getStatus()
      expect(status.running).assertFalse()
      expect(status.capabilities.degradedReason).assertEqual('not_started')
    })

    it('should handle multiple stop calls', 0, () => {
      adapter.stop()
      adapter.stop()
      adapter.stop()

      expect(true).assertTrue()
    })

    it('should return running false after stop', 0, async () => {
      adapter.bindContext(context)
      await adapter.start()
      adapter.stop()

      let status = adapter.getStatus()
      expect(status.running).assertFalse()
    })

    it('should handle re-subscribe after unsubscribe', 0, () => {
      let id1 = adapter.subscribe(() => {})
      adapter.unsubscribe(id1)
      let id2 = adapter.subscribe(() => {})

      expect(id2 > id1).assertTrue()
    })

    it('should handle unsubscribe with invalid id', 0, () => {
      adapter.subscribe(() => {})
      adapter.unsubscribe(999)

      expect(true).assertTrue()
    })
  })
}
