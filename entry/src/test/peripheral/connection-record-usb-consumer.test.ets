import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { commonEventManager } from '@kit.BasicServicesKit'
import { MockKit, when } from '@ohos/hamock'
import {
  LogEventResult,
  OperationResult,
  PeripheralDevicePolicyRecord,
  PeripheralType,
  UsbStoragePolicy
} from '../../main/ets/models/DataModels'
import { PeripheralDevicePolicyRepository } from '../../main/ets/services/peripheral/device-policy/PeripheralDevicePolicyRepository'
import { PeripheralService } from '../../main/ets/services/peripheral/interface-control/PeripheralService'
import { PeripheralConnectionRecordUsbConsumer } from '../../main/ets/services/peripheral/connection-record/peripheral_connection_record_usb_consumer'
import { PeripheralConnectionRecordProducerEvent } from '../../main/ets/services/peripheral/connection-record/peripheral_connection_record_producer_contract'

interface UsbEventParameters {
  vendorId: number
  productId: number
  deviceName: string
  productName: string
  manufacturerName: string
  baseClass: number
  class: number
  timestamp: number
}

interface UsbEventParameterOverrides {
  vendorId?: number
  productId?: number
  deviceName?: string
  productName?: string
  manufacturerName?: string
  baseClass?: number
  class?: number
  timestamp?: number
}

interface UsbEventRawData {
  event: string
  parameters: Object
}

interface UsbEventRawDataOverrides {
  parameters?: Object
}

interface UsbTypeCase {
  baseClass: number
  expectedType: PeripheralType
}

class EmptyUsbParameters {
}

class MissingRawDataUsbEvent implements PeripheralConnectionRecordProducerEvent {
  source: 'runtime' = 'runtime'
  channel: 'usb' = 'usb'
  eventName: string
  rawData: Object = undefined as never as Object

  constructor(eventName: string) {
    this.eventName = eventName
  }
}

class BooleanOperationResult implements OperationResult<boolean> {
  success: boolean = true
  data?: boolean
}

class UsbPolicyOperationResult implements OperationResult<number> {
  success: boolean = true
  data?: number
}

function buildUsbEventParameters(overrides?: UsbEventParameterOverrides): UsbEventParameters {
  let parameters: UsbEventParameters = {
    vendorId: 0x1234,
    productId: 0x5678,
    deviceName: 'USB Storage',
    productName: 'USB Storage',
    manufacturerName: 'ACME',
    baseClass: 0x08,
    class: 0x08,
    timestamp: 100
  }
  if (!overrides) {
    return parameters
  }
  if (overrides.vendorId !== undefined) {
    parameters.vendorId = overrides.vendorId
  }
  if (overrides.productId !== undefined) {
    parameters.productId = overrides.productId
  }
  if (overrides.deviceName !== undefined) {
    parameters.deviceName = overrides.deviceName
  }
  if (overrides.productName !== undefined) {
    parameters.productName = overrides.productName
  }
  if (overrides.manufacturerName !== undefined) {
    parameters.manufacturerName = overrides.manufacturerName
  }
  if (overrides.baseClass !== undefined) {
    parameters.baseClass = overrides.baseClass
  }
  if (overrides.class !== undefined) {
    parameters.class = overrides.class
  }
  if (overrides.timestamp !== undefined) {
    parameters.timestamp = overrides.timestamp
  }
  return parameters
}

function buildUsbEvent(
  eventName: string = commonEventManager.Support.COMMON_EVENT_USB_DEVICE_ATTACHED,
  parameterOverrides?: UsbEventParameterOverrides,
  rawDataOverrides?: UsbEventRawDataOverrides
): PeripheralConnectionRecordProducerEvent {
  let rawData: UsbEventRawData = {
    event: eventName,
    parameters: buildUsbEventParameters(parameterOverrides) as Object
  }
  if (rawDataOverrides?.parameters !== undefined) {
    rawData.parameters = rawDataOverrides.parameters
  }
  let event: PeripheralConnectionRecordProducerEvent = {
    source: 'runtime',
    channel: 'usb',
    eventName: eventName,
    rawData: rawData as Object
  }
  return event
}

export default function peripheralConnectionRecordUsbConsumerTest() {
  describe('PeripheralConnectionRecordUsbConsumer', () => {
    let mockKit: MockKit

    beforeEach(() => {
      mockKit = new MockKit()
      PeripheralDevicePolicyRepository.setRecordsForTest([])
      let usbDisabledResult = new BooleanOperationResult()
      usbDisabledResult.data = false
      let usbStorageResult = new UsbPolicyOperationResult()
      usbStorageResult.data = UsbStoragePolicy.READ_WRITE
      let getInterfaceMock = mockKit.mockFunc(PeripheralService, PeripheralService.getInterfaceDisabledWithResult)
      let getUsbStorageMock = mockKit.mockFunc(PeripheralService, PeripheralService.getUsbStoragePolicyWithResult)
      when(getInterfaceMock)(PeripheralService.FEATURE_USB).afterReturn(usbDisabledResult)
      when(getUsbStorageMock)().afterReturn(usbStorageResult)
    })

    afterEach(() => {
      mockKit.clearAll()
    })

    it('U-USB-001 should map usb attached event to blocked record when usb interface is disabled', 0, async () => {
      const consumer = new PeripheralConnectionRecordUsbConsumer()
      let usbDisabledResult = new BooleanOperationResult()
      usbDisabledResult.data = true
      let getInterfaceMock = mockKit.mockFunc(PeripheralService, PeripheralService.getInterfaceDisabledWithResult)
      when(getInterfaceMock)(PeripheralService.FEATURE_USB).afterReturn(usbDisabledResult)

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
      let usbStorageResult = new UsbPolicyOperationResult()
      usbStorageResult.data = UsbStoragePolicy.DISABLED
      let getUsbStorageMock = mockKit.mockFunc(PeripheralService, PeripheralService.getUsbStoragePolicyWithResult)
      when(getUsbStorageMock)().afterReturn(usbStorageResult)

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
      let usbStorageResult = new UsbPolicyOperationResult()
      usbStorageResult.data = UsbStoragePolicy.READ_ONLY
      let getUsbStorageMock = mockKit.mockFunc(PeripheralService, PeripheralService.getUsbStoragePolicyWithResult)
      when(getUsbStorageMock)().afterReturn(usbStorageResult)

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
      let deniedPolicy: PeripheralDevicePolicyRecord = {
        deviceId: 'vid:1234 pid:5678',
        policy: 'deny',
        updatedAt: 1,
        deviceName: 'Denied Storage',
        deviceType: PeripheralType.USB_STORAGE
      }
      PeripheralDevicePolicyRepository.setRecordsForTest([deniedPolicy])

      const record = await consumer.consume(buildUsbEvent())

      expect(record !== null).assertTrue()
      expect(record?.decision).assertEqual('deny')
      expect(record?.result).assertEqual(LogEventResult.BLOCKED)
      expect(record?.matchedPolicyKind).assertEqual('device_deny')
      expect(record?.summary).assertEqual('命中单设备禁止接入')
    })

    it('U-USB-005 should allow usb attach event when no higher priority policy matches', 0, async () => {
      const consumer = new PeripheralConnectionRecordUsbConsumer()
      let hidOverrides: UsbEventParameterOverrides = {
        deviceName: 'USB Keyboard',
        productName: 'USB Keyboard',
        baseClass: 0x03,
        class: 0x03
      }

      const record = await consumer.consume(buildUsbEvent(
        commonEventManager.Support.COMMON_EVENT_USB_DEVICE_ATTACHED,
        hidOverrides
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
      const missingPayloadEvent = new MissingRawDataUsbEvent(commonEventManager.Support.COMMON_EVENT_USB_DEVICE_ATTACHED)
      let emptyParameters: Object = new EmptyUsbParameters()
      let rawDataOverrides: UsbEventRawDataOverrides = {
        parameters: emptyParameters
      }
      const emptyPayloadEvent = buildUsbEvent(
        commonEventManager.Support.COMMON_EVENT_USB_DEVICE_ATTACHED,
        undefined,
        rawDataOverrides
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
      const cases: UsbTypeCase[] = [
        { baseClass: 0x08, expectedType: PeripheralType.USB_STORAGE },
        { baseClass: 0x0E, expectedType: PeripheralType.USB_CAMERA },
        { baseClass: 0x07, expectedType: PeripheralType.USB_PRINTER },
        { baseClass: 0xFF, expectedType: PeripheralType.USB_OTHER }
      ]

      for (const testCase of cases) {
        let typeOverrides: UsbEventParameterOverrides = {
          baseClass: testCase.baseClass,
          class: testCase.baseClass
        }
        const record = await consumer.consume(buildUsbEvent(
          commonEventManager.Support.COMMON_EVENT_USB_DEVICE_ATTACHED,
          typeOverrides
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
