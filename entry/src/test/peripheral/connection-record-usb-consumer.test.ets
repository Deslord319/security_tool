import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { commonEventManager } from '@kit.BasicServicesKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import {
  OperationResult,
  SecurityEventResult
} from '../../main/ets/models/CommonModels'
import {
  PeripheralDevicePolicyRecord,
  PeripheralType,
  UsbStoragePolicy
} from '../../main/ets/models/PeripheralModels'
import { PeripheralDevicePolicyRepository } from '../../main/ets/services/peripheral/device-policy/PeripheralDevicePolicyRepository'
import { PeripheralService } from '../../main/ets/services/peripheral/interface-control/PeripheralService'
import { PeripheralConnectionRecordUsbConsumer } from '../../main/ets/services/peripheral/connection-record/peripheral_connection_record_usb_consumer'
import { PeripheralConnectionRecordProducerEvent } from '../../main/ets/services/peripheral/connection-record/peripheral_connection_record_producer_contract'
import {
  PeripheralDevicePolicyDispatchService,
  PeripheralPolicyDispatchResult
} from '../../main/ets/services/peripheral/device-policy/peripheral_device_policy_dispatch_service'

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

function createDispatchResult(success: boolean, reason?: string): PeripheralPolicyDispatchResult {
  let result: PeripheralPolicyDispatchResult = {
    success: success
  }
  if (reason !== undefined) {
    result.reason = reason as never
  }
  return result
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
    rawData: rawData as commonEventManager.CommonEventData
  }
  return event
}

export default function peripheralConnectionRecordUsbConsumerTest() {
  describe('PeripheralConnectionRecordUsbConsumer', () => {
    let mockKit: MockKit
    let dispatchResult: PeripheralPolicyDispatchResult
    let dispatchCount: number
    let usbDisabledResult: BooleanOperationResult
    let usbStorageResult: UsbPolicyOperationResult

    beforeEach(async () => {
      mockKit = new MockKit()
      dispatchResult = createDispatchResult(true)
      dispatchCount = 0
      await PeripheralDevicePolicyRepository.clearAll()
      usbDisabledResult = new BooleanOperationResult()
      usbDisabledResult.data = false
      usbStorageResult = new UsbPolicyOperationResult()
      usbStorageResult.data = UsbStoragePolicy.READ_WRITE
      let getInterfaceMock: Function =
        mockKit.mockFunc(PeripheralService, PeripheralService.getInterfaceDisabledWithResult)
      let getUsbStorageMock: Function =
        mockKit.mockFunc(PeripheralService, PeripheralService.getUsbStoragePolicyWithResult)
      let dispatchMock: Function =
        mockKit.mockFunc(PeripheralDevicePolicyDispatchService, PeripheralDevicePolicyDispatchService.dispatch)
      when(getInterfaceMock)(PeripheralService.FEATURE_USB).afterReturn(usbDisabledResult)
      when(getUsbStorageMock)().afterReturn(usbStorageResult)
      when(dispatchMock)(ArgumentMatchers.any).afterAction(() => {
        dispatchCount += 1
        return Promise.resolve(dispatchResult)
      })
    })

    afterEach(async () => {
      mockKit.clear(PeripheralService)
      mockKit.clear(PeripheralDevicePolicyDispatchService)
      mockKit.clearAll()
      await PeripheralDevicePolicyRepository.clearAll()
    })

    it('U-USB-001 should map usb attached event to blocked record when usb interface is disabled', 0, async () => {
      const consumer = new PeripheralConnectionRecordUsbConsumer()
      usbDisabledResult.data = true
      await PeripheralDevicePolicyRepository.set({
        deviceId: 'VID:1234 PID:5678',
        policy: 'allow',
        updatedAt: 1,
        deviceName: 'Allowed Storage',
        deviceType: PeripheralType.USB_STORAGE
      })
      dispatchCount = 0

      const record = await consumer.consume(buildUsbEvent())

      expect(record !== null).assertTrue()
      expect(record?.decision).assertEqual('deny')
      expect(record?.result).assertEqual(SecurityEventResult.BLOCKED)
      expect(record?.matchedPolicyKind).assertEqual('usb_disabled')
      expect(record?.effectivePolicyLabel).assertEqual('已禁用')
      expect(record?.summary).assertEqual('USB 接口已禁用')
      expect(dispatchCount).assertEqual(0)
    })

    it('U-USB-002 should block usb storage event without auto deny when storage policy is disabled', 0, async () => {
      const consumer = new PeripheralConnectionRecordUsbConsumer()
      usbStorageResult.data = UsbStoragePolicy.DISABLED
      dispatchCount = 0

      const record = await consumer.consume(buildUsbEvent())

      expect(record !== null).assertTrue()
      expect(record?.decision).assertEqual('deny')
      expect(record?.result).assertEqual(SecurityEventResult.BLOCKED)
      expect(record?.matchedPolicyKind).assertEqual('usb_storage_disabled')
      expect(record?.effectivePolicyLabel).assertEqual('已禁用')
      expect(record?.summary).assertEqual('USB 存储已禁用')
      expect(record?.detail?.includes('首次接入已自动加入黑名单')).assertFalse()
      expect(dispatchCount).assertEqual(0)
      expect(PeripheralDevicePolicyRepository.get('VID:1234 PID:5678') === null).assertTrue()
    })

    it('U-USB-003 should map usb storage read only policy to allow record with enabled label', 0, async () => {
      const consumer = new PeripheralConnectionRecordUsbConsumer()
      usbStorageResult.data = UsbStoragePolicy.READ_ONLY
      await PeripheralDevicePolicyRepository.set({
        deviceId: 'VID:1234 PID:5678',
        policy: 'allow',
        updatedAt: 1,
        deviceName: 'Allowed Storage',
        deviceType: PeripheralType.USB_STORAGE
      })
      dispatchCount = 0

      const record = await consumer.consume(buildUsbEvent())

      expect(record !== null).assertTrue()
      expect(record?.decision).assertEqual('allow')
      expect(record?.result).assertEqual(SecurityEventResult.SUCCESS)
      expect(record?.matchedPolicyKind).assertEqual('usb_storage_read_only')
      expect(record?.effectivePolicyLabel).assertEqual('已启用')
      expect(record?.summary).assertEqual('USB 存储只读')
      expect(dispatchCount).assertEqual(0)
    })

    it('U-USB-003A should prefer device deny over usb storage read only on attach', 0, async () => {
      const consumer = new PeripheralConnectionRecordUsbConsumer()
      usbStorageResult.data = UsbStoragePolicy.READ_ONLY
      await PeripheralDevicePolicyRepository.set({
        deviceId: 'VID:1234 PID:5678',
        policy: 'deny',
        updatedAt: 1,
        deviceName: 'Denied Storage',
        deviceType: PeripheralType.USB_STORAGE
      })
      dispatchCount = 0

      const record = await consumer.consume(buildUsbEvent())

      expect(record !== null).assertTrue()
      expect(record?.decision).assertEqual('deny')
      expect(record?.result).assertEqual(SecurityEventResult.BLOCKED)
      expect(record?.matchedPolicyKind).assertEqual('device_deny')
      expect(record?.effectivePolicyLabel).assertEqual('已禁用')
      expect(record?.summary).assertEqual('命中单设备禁止接入')
      expect(dispatchCount).assertEqual(0)
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
      await PeripheralDevicePolicyRepository.set(deniedPolicy)

      const record = await consumer.consume(buildUsbEvent())

      expect(record !== null).assertTrue()
      expect(record?.decision).assertEqual('deny')
      expect(record?.result).assertEqual(SecurityEventResult.BLOCKED)
      expect(record?.matchedPolicyKind).assertEqual('device_deny')
      expect(record?.effectivePolicyLabel).assertEqual('已禁用')
      expect(record?.summary).assertEqual('命中单设备禁止接入')
    })

    it('U-USB-005 should auto deny first usb attach event when no explicit policy exists', 0, async () => {
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
      expect(record?.decision).assertEqual('deny')
      expect(record?.result).assertEqual(SecurityEventResult.BLOCKED)
      expect(record?.matchedPolicyKind).assertEqual('device_deny')
      expect(record?.deviceType).assertEqual(PeripheralType.USB_HID)
      expect(record?.effectivePolicyLabel).assertEqual('已禁用')
      expect(record?.summary).assertEqual('命中单设备禁止接入')
      expect(record?.detail?.includes('首次接入已自动加入黑名单')).assertTrue()
      expect(dispatchCount).assertEqual(1)
      expect(PeripheralDevicePolicyRepository.get('VID:1234 PID:5678')?.policy).assertEqual('deny')
    })

    it('U-USB-006 should map usb detached event to disconnect record without blocked summary', 0, async () => {
      const consumer = new PeripheralConnectionRecordUsbConsumer()

      const record = await consumer.consume(buildUsbEvent(commonEventManager.Support.COMMON_EVENT_USB_DEVICE_DETACHED))

      expect(record !== null).assertTrue()
      expect(record?.action).assertEqual('disconnect')
      expect(record?.decision).assertEqual('unknown')
      expect(record?.result).assertEqual(SecurityEventResult.SUCCESS)
      expect(record?.matchedPolicyKind).assertEqual('disconnect_event')
      expect(record?.summary).assertEqual('设备已断开')
      expect(record?.detail?.includes('断开前生效策略为')).assertTrue()
    })

    it('U-USB-006A should keep detached usb record disabled when device policy is deny', 0, async () => {
      const consumer = new PeripheralConnectionRecordUsbConsumer()
      const deniedPolicy: PeripheralDevicePolicyRecord = {
        deviceId: 'vid:1234 pid:5678',
        policy: 'deny',
        updatedAt: 1,
        deviceName: 'Denied Storage',
        deviceType: PeripheralType.USB_STORAGE
      }
      await PeripheralDevicePolicyRepository.set(deniedPolicy)

      const record = await consumer.consume(buildUsbEvent(commonEventManager.Support.COMMON_EVENT_USB_DEVICE_DETACHED))

      expect(record !== null).assertTrue()
      expect(record?.action).assertEqual('disconnect')
      expect(record?.decision).assertEqual('unknown')
      expect(record?.matchedPolicyKind).assertEqual('disconnect_event')
      expect(record?.effectivePolicyLabel).assertEqual('已禁用')
      expect(record?.detail?.includes('断开前生效策略为：已禁用')).assertTrue()
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

    it('U-USB-011 should keep explicit allow policy and skip auto deny dispatch', 0, async () => {
      const consumer = new PeripheralConnectionRecordUsbConsumer()
      await PeripheralDevicePolicyRepository.set({
        deviceId: 'VID:1234 PID:5678',
        policy: 'allow',
        updatedAt: 1,
        deviceName: 'Allowed Storage',
        deviceType: PeripheralType.USB_STORAGE
      })
      dispatchCount = 0

      const record = await consumer.consume(buildUsbEvent())

      expect(record !== null).assertTrue()
      expect(record?.decision).assertEqual('allow')
      expect(record?.matchedPolicyKind).assertEqual('default_allow')
      expect(dispatchCount).assertEqual(0)
      expect(PeripheralDevicePolicyRepository.get('VID:1234 PID:5678')?.policy).assertEqual('allow')
    })

    it('U-USB-012 should keep explicit deny policy and skip repeated auto deny dispatch', 0, async () => {
      const consumer = new PeripheralConnectionRecordUsbConsumer()
      await PeripheralDevicePolicyRepository.set({
        deviceId: 'VID:1234 PID:5678',
        policy: 'deny',
        updatedAt: 1,
        deviceName: 'Denied Storage',
        deviceType: PeripheralType.USB_STORAGE
      })
      dispatchCount = 0

      const record = await consumer.consume(buildUsbEvent())

      expect(record !== null).assertTrue()
      expect(record?.decision).assertEqual('deny')
      expect(record?.matchedPolicyKind).assertEqual('device_deny')
      expect(dispatchCount).assertEqual(0)
      expect(PeripheralDevicePolicyRepository.get('VID:1234 PID:5678')?.policy).assertEqual('deny')
    })

    it('U-USB-013 should not save local deny when auto deny dispatch fails', 0, async () => {
      const consumer = new PeripheralConnectionRecordUsbConsumer()
      dispatchResult = createDispatchResult(false, 'usb_dispatch_failed')

      const record = await consumer.consume(buildUsbEvent())

      expect(record !== null).assertTrue()
      expect(record?.decision).assertEqual('allow')
      expect(record?.matchedPolicyKind).assertEqual('default_allow')
      expect(record?.detail?.includes('自动加入黑名单失败：usb_dispatch_failed')).assertTrue()
      expect(dispatchCount).assertEqual(1)
      expect(PeripheralDevicePolicyRepository.get('VID:1234 PID:5678') === null).assertTrue()
    })

    it('U-USB-014 should not trigger auto deny for detached usb events', 0, async () => {
      const consumer = new PeripheralConnectionRecordUsbConsumer()

      const record = await consumer.consume(buildUsbEvent(commonEventManager.Support.COMMON_EVENT_USB_DEVICE_DETACHED))

      expect(record !== null).assertTrue()
      expect(record?.action).assertEqual('disconnect')
      expect(dispatchCount).assertEqual(0)
      expect(PeripheralDevicePolicyRepository.get('VID:1234 PID:5678') === null).assertTrue()
    })
  })
}
