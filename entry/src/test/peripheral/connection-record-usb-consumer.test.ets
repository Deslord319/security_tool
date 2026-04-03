import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { commonEventManager } from '@kit.BasicServicesKit'
import {
  LogEventResult,
  PeripheralDevicePolicyRecord,
  PeripheralType,
  UsbStoragePolicy
} from '../../main/ets/models/DataModels'
import { PeripheralDevicePolicyRepository } from '../../main/ets/services/PeripheralDevicePolicyRepository'
import { PeripheralService } from '../../main/ets/services/PeripheralService'
import { PeripheralConnectionRecordUsbConsumer } from '../../main/ets/services/peripheral/connection-record/peripheral_connection_record_usb_consumer'
import { PeripheralConnectionRecordProducerEvent } from '../../main/ets/services/peripheral/connection-record/peripheral_connection_record_producer_contract'

type EventField = Object | string | number | boolean

function buildUsbEvent(
  eventName: string = commonEventManager.Support.COMMON_EVENT_USB_DEVICE_ATTACHED,
  parameterOverrides: Record<string, EventField> = {},
  rawDataOverrides: Record<string, EventField> = {}
): PeripheralConnectionRecordProducerEvent {
  return {
    source: 'runtime',
    channel: 'usb',
    eventName: eventName,
    rawData: {
      event: eventName,
      parameters: {
        vendorId: 0x1234,
        productId: 0x5678,
        deviceName: 'USB Storage',
        productName: 'USB Storage',
        manufacturerName: 'ACME',
        baseClass: 0x08,
        class: 0x08,
        timestamp: 100,
        ...parameterOverrides
      },
      ...rawDataOverrides
    }
  }
}

export default function peripheralConnectionRecordUsbConsumerTest() {
  describe('PeripheralConnectionRecordUsbConsumer', () => {
    let originalGetAll: () => PeripheralDevicePolicyRecord[]
    let originalGetInterfaceDisabledWithResult: (feature: string) => Object
    let originalGetUsbStoragePolicyWithResult: () => Object
    let usbDisabledState: boolean
    let usbStoragePolicyState: UsbStoragePolicy
    let devicePoliciesState: PeripheralDevicePolicyRecord[]

    beforeEach(() => {
      originalGetAll = PeripheralDevicePolicyRepository.getAll
      originalGetInterfaceDisabledWithResult = PeripheralService.getInterfaceDisabledWithResult
      originalGetUsbStoragePolicyWithResult = PeripheralService.getUsbStoragePolicyWithResult
      usbDisabledState = false
      usbStoragePolicyState = UsbStoragePolicy.READ_ONLY
      devicePoliciesState = []

      PeripheralDevicePolicyRepository.getAll = (): PeripheralDevicePolicyRecord[] => devicePoliciesState
      PeripheralService.getInterfaceDisabledWithResult = (_feature: string): Object => ({ data: usbDisabledState })
      PeripheralService.getUsbStoragePolicyWithResult = (): Object => ({ data: usbStoragePolicyState })
    })

    afterEach(() => {
      PeripheralDevicePolicyRepository.getAll = originalGetAll
      PeripheralService.getInterfaceDisabledWithResult = originalGetInterfaceDisabledWithResult
      PeripheralService.getUsbStoragePolicyWithResult = originalGetUsbStoragePolicyWithResult
    })

    it('U-USB-001 should map usb attached event to blocked record when usb interface is disabled', 0, async () => {
      const consumer = new PeripheralConnectionRecordUsbConsumer()
      usbDisabledState = true

      const record = await consumer.consume(buildUsbEvent())

      expect(record !== null).assertTrue()
      expect(record?.decision).assertEqual('deny')
      expect(record?.result).assertEqual(LogEventResult.BLOCKED)
      expect(record?.matchedPolicyKind).assertEqual('usb_disabled')
      expect(record?.effectivePolicyLabel).assertEqual('已禁用')
      expect(record?.summary).assertEqual('USB 接口已禁用')
    })

    it('U-USB-002 should block usb storage event when storage policy is disabled', 0, async () => {
      const consumer = new PeripheralConnectionRecordUsbConsumer()
      usbStoragePolicyState = UsbStoragePolicy.DISABLED

      const record = await consumer.consume(buildUsbEvent())

      expect(record !== null).assertTrue()
      expect(record?.decision).assertEqual('deny')
      expect(record?.result).assertEqual(LogEventResult.BLOCKED)
      expect(record?.matchedPolicyKind).assertEqual('usb_storage_disabled')
      expect(record?.effectivePolicyLabel).assertEqual('禁止访问')
      expect(record?.summary).assertEqual('USB 存储已禁用')
    })

    it('U-USB-003 should map usb storage read only policy to allow record with readonly label', 0, async () => {
      const consumer = new PeripheralConnectionRecordUsbConsumer()
      usbStoragePolicyState = UsbStoragePolicy.READ_ONLY

      const record = await consumer.consume(buildUsbEvent())

      expect(record !== null).assertTrue()
      expect(record?.decision).assertEqual('allow')
      expect(record?.result).assertEqual(LogEventResult.SUCCESS)
      expect(record?.matchedPolicyKind).assertEqual('usb_storage_read_only')
      expect(record?.effectivePolicyLabel).assertEqual('只读')
      expect(record?.summary).assertEqual('USB 存储只读')
    })

    it('U-USB-004 should block usb attach event when device policy is deny', 0, async () => {
      const consumer = new PeripheralConnectionRecordUsbConsumer()
      usbStoragePolicyState = UsbStoragePolicy.READ_WRITE
      devicePoliciesState = [{
        deviceId: 'vid:1234 pid:5678',
        policy: 'deny',
        updatedAt: 1,
        deviceName: 'Denied Storage',
        deviceType: PeripheralType.USB_STORAGE
      }]

      const record = await consumer.consume(buildUsbEvent())

      expect(record !== null).assertTrue()
      expect(record?.decision).assertEqual('deny')
      expect(record?.result).assertEqual(LogEventResult.BLOCKED)
      expect(record?.matchedPolicyKind).assertEqual('device_deny')
      expect(record?.summary).assertEqual('命中单设备禁止接入')
    })

    it('U-USB-005 should allow usb attach event when no higher priority policy matches', 0, async () => {
      const consumer = new PeripheralConnectionRecordUsbConsumer()
      usbStoragePolicyState = UsbStoragePolicy.READ_WRITE

      const record = await consumer.consume(buildUsbEvent(
        commonEventManager.Support.COMMON_EVENT_USB_DEVICE_ATTACHED,
        {
          deviceName: 'USB Keyboard',
          productName: 'USB Keyboard',
          baseClass: 0x03,
          class: 0x03
        }
      ))

      expect(record !== null).assertTrue()
      expect(record?.decision).assertEqual('allow')
      expect(record?.result).assertEqual(LogEventResult.SUCCESS)
      expect(record?.matchedPolicyKind).assertEqual('default_allow')
      expect(record?.deviceType).assertEqual(PeripheralType.USB_HID)
      expect(record?.effectivePolicyLabel).assertEqual('已启用')
      expect(record?.summary).assertEqual('按当前策略允许接入')
    })

    it('U-USB-006 should map usb detached event to disconnect record without blocked summary', 0, async () => {
      const consumer = new PeripheralConnectionRecordUsbConsumer()
      usbStoragePolicyState = UsbStoragePolicy.DISABLED

      const record = await consumer.consume(buildUsbEvent(commonEventManager.Support.COMMON_EVENT_USB_DEVICE_DETACHED))

      expect(record !== null).assertTrue()
      expect(record?.action).assertEqual('disconnect')
      expect(record?.decision).assertEqual('unknown')
      expect(record?.result).assertEqual(LogEventResult.SUCCESS)
      expect(record?.matchedPolicyKind).assertEqual('disconnect_event')
      expect(record?.summary).assertEqual('设备已断开')
      expect(record?.detail?.includes('断开前生效策略为')).assertTrue()
    })

    it('U-USB-007 should ignore unsupported usb event names', 0, async () => {
      const consumer = new PeripheralConnectionRecordUsbConsumer()

      const record = await consumer.consume(buildUsbEvent('usb.unsupported'))

      expect(record === null).assertTrue()
    })

    it('U-USB-008 should stay stable for missing or empty raw payloads', 0, async () => {
      const consumer = new PeripheralConnectionRecordUsbConsumer()
      const missingPayloadEvent = {
        source: 'runtime',
        channel: 'usb',
        eventName: commonEventManager.Support.COMMON_EVENT_USB_DEVICE_ATTACHED,
        rawData: undefined
      } as PeripheralConnectionRecordProducerEvent
      const emptyPayloadEvent = buildUsbEvent(
        commonEventManager.Support.COMMON_EVENT_USB_DEVICE_ATTACHED,
        {},
        { parameters: {} as Object }
      )

      const missingPayloadRecord = await consumer.consume(missingPayloadEvent)
      const emptyPayloadRecord = await consumer.consume(emptyPayloadEvent)

      expect(missingPayloadRecord === null).assertTrue()
      expect(emptyPayloadRecord !== null).assertTrue()
      expect(emptyPayloadRecord?.matchedPolicyKind).assertEqual('default_allow')
      expect(emptyPayloadRecord?.deviceType).assertEqual(PeripheralType.USB_OTHER)
    })

    it('U-USB-009 should infer usb device type from baseClass matrix', 0, async () => {
      const consumer = new PeripheralConnectionRecordUsbConsumer()
      const cases = [
        { baseClass: 0x08, expectedType: PeripheralType.USB_STORAGE },
        { baseClass: 0x0E, expectedType: PeripheralType.USB_CAMERA },
        { baseClass: 0x07, expectedType: PeripheralType.USB_PRINTER },
        { baseClass: 0xFF, expectedType: PeripheralType.USB_OTHER }
      ]

      for (const testCase of cases) {
        const record = await consumer.consume(buildUsbEvent(
          commonEventManager.Support.COMMON_EVENT_USB_DEVICE_ATTACHED,
          {
            baseClass: testCase.baseClass,
            class: testCase.baseClass
          }
        ))
        expect(record !== null).assertTrue()
        expect(record?.deviceType).assertEqual(testCase.expectedType)
      }
    })

    it('U-USB-010 should serialize raw usb payload into rawPayload', 0, async () => {
      const consumer = new PeripheralConnectionRecordUsbConsumer()
      const event = buildUsbEvent()

      const record = await consumer.consume(event)

      expect(record !== null).assertTrue()
      expect((record?.rawPayload?.length ?? 0) > 0).assertTrue()
      expect(record?.rawPayload?.includes('"vendorId":4660')).assertTrue()
      expect(record?.rawPayload?.includes('"productId":22136')).assertTrue()
    })
  })
}
