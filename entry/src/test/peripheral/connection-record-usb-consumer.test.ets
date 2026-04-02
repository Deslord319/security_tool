import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { commonEventManager } from '@kit.BasicServicesKit'
import { PeripheralType, UsbStoragePolicy } from '../../main/ets/models/DataModels'
import { PeripheralDevicePolicyRepository } from '../../main/ets/services/PeripheralDevicePolicyRepository'
import { PeripheralService } from '../../main/ets/services/PeripheralService'
import { PeripheralConnectionRecordUsbConsumer } from '../../main/ets/services/peripheral/connection-record/peripheral_connection_record_usb_consumer'
import { PeripheralConnectionRecordProducerEvent } from '../../main/ets/services/peripheral/connection-record/peripheral_connection_record_producer_contract'

export default function peripheralConnectionRecordUsbConsumerTest() {
  describe('PeripheralConnectionRecordUsbConsumer', () => {
    let originalGetAll: () => Object[]
    let originalGetInterfaceDisabledWithResult: (feature: string) => Object
    let originalGetUsbStoragePolicyWithResult: () => Object

    beforeEach(() => {
      originalGetAll = PeripheralDevicePolicyRepository.getAll
      originalGetInterfaceDisabledWithResult = PeripheralService.getInterfaceDisabledWithResult
      originalGetUsbStoragePolicyWithResult = PeripheralService.getUsbStoragePolicyWithResult

      PeripheralDevicePolicyRepository.getAll = (): Object[] => []
      PeripheralService.getInterfaceDisabledWithResult = (_feature: string): Object => ({ data: false })
      PeripheralService.getUsbStoragePolicyWithResult = (): Object => ({ data: UsbStoragePolicy.READ_ONLY })
    })

    afterEach(() => {
      PeripheralDevicePolicyRepository.getAll = originalGetAll
      PeripheralService.getInterfaceDisabledWithResult = originalGetInterfaceDisabledWithResult
      PeripheralService.getUsbStoragePolicyWithResult = originalGetUsbStoragePolicyWithResult
    })

    it('should map usb producer event to trace record with key fields', 0, async (done: Function) => {
      const consumer = new PeripheralConnectionRecordUsbConsumer()
      const event: PeripheralConnectionRecordProducerEvent = {
        source: 'runtime',
        channel: 'usb',
        eventName: commonEventManager.Support.COMMON_EVENT_USB_DEVICE_ATTACHED,
        rawData: {
          event: commonEventManager.Support.COMMON_EVENT_USB_DEVICE_ATTACHED,
          parameters: {
            vendorId: 0x1234,
            productId: 0x5678,
            deviceName: 'USB Storage',
            productName: 'USB Storage',
            manufacturerName: 'ACME',
            baseClass: 8,
            class: 8,
            timestamp: 100
          }
        }
      }

      const record = await consumer.consume(event)
      expect(record !== null).assertTrue()
      expect(record?.action).assertEqual('connect')
      expect(record?.summary).assertEqual('USB 存储只读')
      expect(record?.matchedPolicyKind).assertEqual('usb_storage_read_only')
      expect(record?.effectivePolicyLabel).assertEqual('只读')
      done()
    })
  })
}
