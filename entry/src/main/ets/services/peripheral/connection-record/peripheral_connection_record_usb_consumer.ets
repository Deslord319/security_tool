import { commonEventManager } from '@kit.BasicServicesKit'
import {
  LogEventResult,
  PeripheralDevicePolicy,
  PeripheralMatchedPolicyKind,
  PeripheralRecordPolicyHit,
  PeripheralType,
  UsbStoragePolicy,
  formatUsbDeviceId,
  inferPeripheralTypeFromBaseClass
} from '../../../models/DataModels'
import { PeripheralDevicePolicyRepository } from '../device-policy/PeripheralDevicePolicyRepository'
import { PeripheralService } from '../interface-control/PeripheralService'
import {
  PeripheralConnectionRecordConsumeResult,
  PeripheralConnectionRecordConsumer,
  PeripheralConnectionRecordProducerEvent
} from './peripheral_connection_record_producer_contract'
import {
  PeripheralDevicePolicyDispatchService,
  PeripheralPolicyDispatchReason
} from '../device-policy/peripheral_device_policy_dispatch_service'
import {
  collectPayloadSources,
  pickNumber,
  pickString,
  toRecordArray
} from './peripheral_connection_record_payload_utils'
import { LogUtils } from '../../../utils/LogUtils'
import { generateRandomSuffix } from '../../../utils/ValuePicker'
import { StatusText } from '../../../constants/StringCatalog'
import {
  PeripheralMatchedPolicyStrings,
  PeripheralConnectionRecordStrings
} from '../../../constants/modules/PeripheralStrings'
import { LooseRecord } from '../../../types/LooseValueTypes'

const TAG = 'ConnectionRecordUsbConsumer'

interface ResolvedUsbEventInfo {
  vendorId: number
  productId: number
  baseClass: number
  subClass: number
  protocol: number
  occurAt: number
  deviceName: string
  detail: string
  deviceId: string
  deviceType: PeripheralType
}

interface UsbPolicySnapshot {
  usbDisabled: boolean
  usbStoragePolicy: UsbStoragePolicy
  devicePolicies: Map<string, PeripheralDevicePolicy>
}

interface UsbEventPolicyEvaluation {
  policyHit: PeripheralRecordPolicyHit
  result: LogEventResult
  summary: string
  detail: string
  usbPolicy?: UsbStoragePolicy
  effectivePolicyLabel: string
  matchedPolicyKind: PeripheralMatchedPolicyKind
}

type UsbEventAction = 'connect' | 'disconnect' | 'unknown'
type EventPayloadRecord = LooseRecord
type FirstConnectAutoDenyStatus =
  'not_applicable' |
  'skipped_invalid_device_id' |
  'skipped_existing_policy' |
  'saved' |
  'dispatch_failed' |
  'save_failed'

interface FirstConnectAutoDenyResult {
  status: FirstConnectAutoDenyStatus
  reason?: PeripheralPolicyDispatchReason | string
}

export class PeripheralConnectionRecordUsbConsumer implements PeripheralConnectionRecordConsumer {
  canHandle(event: PeripheralConnectionRecordProducerEvent): boolean {
    return event.channel === 'usb'
  }

  async consume(event: PeripheralConnectionRecordProducerEvent): Promise<PeripheralConnectionRecordConsumeResult> {
    if (!this.canHandle(event)) {
      return null
    }
    const rawData = event.rawData as commonEventManager.CommonEventData | undefined
    if (!rawData) {
      return null
    }

    const action = PeripheralConnectionRecordUsbConsumer.resolveAction(event.eventName)
    if (action === 'unknown') {
      LogUtils.warn(TAG, `ignored unsupported usb event: ${event.eventName}`)
      return null
    }

    const info = PeripheralConnectionRecordUsbConsumer.resolveUsbEventInfo(rawData)
    const baseEvaluation = PeripheralConnectionRecordUsbConsumer.evaluateUsbEventPolicy(info, action)
    let autoDenyResult: FirstConnectAutoDenyResult = { status: 'not_applicable' }
    if (baseEvaluation.matchedPolicyKind !== 'usb_storage_disabled') {
      autoDenyResult = await PeripheralConnectionRecordUsbConsumer.applyFirstConnectAutoDeny(info, action)
    }
    const evaluation = PeripheralConnectionRecordUsbConsumer.decorateAutoDenyEvaluation(
      baseEvaluation,
      autoDenyResult
    )
    let rawPayload = ''
    try {
      rawPayload = JSON.stringify(rawData)
    } catch (_err) {
      rawPayload = ''
    }

    return {
      recordId: `runtime_usb_${info.occurAt}_${generateRandomSuffix()}`,
      occurAt: info.occurAt,
      collectAt: Date.now(),
      deviceName: info.deviceName,
      deviceType: info.deviceType,
      deviceId: info.deviceId,
      action: action,
      decision: evaluation.policyHit,
      result: evaluation.result,
      source: 'runtime_event',
      summary: evaluation.summary,
      rawEventName: event.eventName,
      rawAction: action,
      rawPayload: rawPayload,
      detail: evaluation.detail,
      usbPolicy: evaluation.usbPolicy,
      effectivePolicyLabel: evaluation.effectivePolicyLabel,
      matchedPolicyKind: evaluation.matchedPolicyKind
    }
  }

  private static resolveAction(eventName: string): UsbEventAction {
    switch (eventName) {
      case commonEventManager.Support.COMMON_EVENT_USB_DEVICE_ATTACHED:
        return 'connect'
      case commonEventManager.Support.COMMON_EVENT_USB_DEVICE_DETACHED:
        return 'disconnect'
      default:
        return 'unknown'
    }
  }

  private static evaluateUsbEventPolicy(
    info: ResolvedUsbEventInfo,
    action: UsbEventAction
  ): UsbEventPolicyEvaluation {
    const snapshot = PeripheralConnectionRecordUsbConsumer.readCurrentUsbPolicySnapshot()
    const effectivePolicyLabel = PeripheralConnectionRecordUsbConsumer.resolveEffectivePolicyLabel(
      info.deviceId,
      info.deviceType,
      snapshot
    )

    if (action === 'disconnect') {
      return {
        policyHit: 'unknown',
        result: LogEventResult.SUCCESS,
        summary: PeripheralConnectionRecordStrings.USB_DISCONNECTED,
        detail: PeripheralConnectionRecordUsbConsumer.buildDisconnectDetail(info, effectivePolicyLabel),
        usbPolicy: info.deviceType === PeripheralType.USB_STORAGE ? snapshot.usbStoragePolicy : undefined,
        effectivePolicyLabel: effectivePolicyLabel,
        matchedPolicyKind: 'disconnect_event'
      }
    }

    if (snapshot.usbDisabled) {
      return {
        policyHit: 'deny',
        result: LogEventResult.BLOCKED,
        summary: PeripheralMatchedPolicyStrings.USB_DISABLED,
        detail: PeripheralConnectionRecordStrings.USB_INTERFACE_DISABLED_DETAIL,
        usbPolicy: info.deviceType === PeripheralType.USB_STORAGE ? snapshot.usbStoragePolicy : undefined,
        effectivePolicyLabel: StatusText.DISABLED,
        matchedPolicyKind: 'usb_disabled'
      }
    }

    if (info.deviceType === PeripheralType.USB_STORAGE) {
      if (snapshot.usbStoragePolicy === UsbStoragePolicy.DISABLED) {
        return {
          policyHit: 'deny',
          result: LogEventResult.BLOCKED,
          summary: PeripheralMatchedPolicyStrings.USB_STORAGE_DISABLED,
          detail: PeripheralConnectionRecordStrings.USB_STORAGE_DISABLED_DETAIL,
          usbPolicy: snapshot.usbStoragePolicy,
          effectivePolicyLabel: StatusText.DISABLED,
          matchedPolicyKind: 'usb_storage_disabled'
        }
      }
    }

    if (snapshot.devicePolicies.get(info.deviceId.toUpperCase()) === 'deny') {
      return {
        policyHit: 'deny',
        result: LogEventResult.BLOCKED,
        summary: PeripheralMatchedPolicyStrings.DEVICE_DENY,
        detail: PeripheralConnectionRecordStrings.buildDeviceDenyDetail(info.deviceId),
        usbPolicy: info.deviceType === PeripheralType.USB_STORAGE ? snapshot.usbStoragePolicy : undefined,
        effectivePolicyLabel: StatusText.DISABLED,
        matchedPolicyKind: 'device_deny'
      }
    }

    if (info.deviceType === PeripheralType.USB_STORAGE && snapshot.usbStoragePolicy === UsbStoragePolicy.READ_ONLY) {
      return {
        policyHit: 'allow',
        result: LogEventResult.SUCCESS,
        summary: PeripheralMatchedPolicyStrings.USB_STORAGE_READ_ONLY,
        detail: PeripheralConnectionRecordStrings.USB_STORAGE_READ_ONLY_DETAIL,
        usbPolicy: snapshot.usbStoragePolicy,
        effectivePolicyLabel: StatusText.ENABLED,
        matchedPolicyKind: 'usb_storage_read_only'
      }
    }

    return {
      policyHit: 'allow',
      result: LogEventResult.SUCCESS,
      summary: PeripheralConnectionRecordStrings.DEFAULT_ALLOW,
      detail: PeripheralConnectionRecordStrings.DEFAULT_ALLOW_DETAIL,
      usbPolicy: info.deviceType === PeripheralType.USB_STORAGE ? snapshot.usbStoragePolicy : undefined,
      effectivePolicyLabel: effectivePolicyLabel,
      matchedPolicyKind: 'default_allow'
    }
  }

  private static async applyFirstConnectAutoDeny(
    info: ResolvedUsbEventInfo,
    action: UsbEventAction
  ): Promise<FirstConnectAutoDenyResult> {
    if (action !== 'connect') {
      return { status: 'not_applicable' }
    }
    if (!Number.isFinite(info.vendorId) || !Number.isFinite(info.productId)) {
      return { status: 'skipped_invalid_device_id' }
    }
    if (PeripheralDevicePolicyRepository.get(info.deviceId)) {
      return { status: 'skipped_existing_policy' }
    }

    const dispatchResult = await PeripheralDevicePolicyDispatchService.dispatch({
      deviceId: info.deviceId,
      deviceType: info.deviceType,
      policy: 'deny'
    })
    if (!dispatchResult.success) {
      return {
        status: 'dispatch_failed',
        reason: dispatchResult.reason ?? dispatchResult.errorMessage ?? 'unknown'
      }
    }

    const saved = await PeripheralDevicePolicyRepository.set({
      deviceId: info.deviceId,
      deviceName: info.deviceName,
      deviceType: info.deviceType,
      policy: 'deny',
      updatedAt: Date.now()
    })
    if (!saved) {
      return { status: 'save_failed', reason: 'repository_set_failed' }
    }
    return { status: 'saved' }
  }

  private static decorateAutoDenyEvaluation(
    evaluation: UsbEventPolicyEvaluation,
    autoDenyResult: FirstConnectAutoDenyResult
  ): UsbEventPolicyEvaluation {
    if (autoDenyResult.status === 'saved') {
      return {
        policyHit: 'deny',
        result: LogEventResult.BLOCKED,
        summary: PeripheralMatchedPolicyStrings.DEVICE_DENY,
        detail: `${evaluation.detail}; 首次接入已自动加入黑名单`,
        usbPolicy: evaluation.usbPolicy,
        effectivePolicyLabel: StatusText.DISABLED,
        matchedPolicyKind: 'device_deny'
      }
    }
    if (autoDenyResult.status === 'dispatch_failed' || autoDenyResult.status === 'save_failed') {
      return {
        policyHit: evaluation.policyHit,
        result: evaluation.result,
        summary: evaluation.summary,
        detail: `${evaluation.detail}; 自动加入黑名单失败：${autoDenyResult.reason ?? 'unknown'}`,
        usbPolicy: evaluation.usbPolicy,
        effectivePolicyLabel: evaluation.effectivePolicyLabel,
        matchedPolicyKind: evaluation.matchedPolicyKind
      }
    }
    return evaluation
  }

  private static readCurrentUsbPolicySnapshot(): UsbPolicySnapshot {
    const devicePolicies: Map<string, PeripheralDevicePolicy> = new Map()
    PeripheralDevicePolicyRepository.getAll().forEach((item) => {
      devicePolicies.set(item.deviceId.toUpperCase(), item.policy)
    })
    return {
      usbDisabled: PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_USB).data ?? false,
      usbStoragePolicy: PeripheralConnectionRecordUsbConsumer.readCurrentUsbStoragePolicy(),
      devicePolicies: devicePolicies
    }
  }

  private static readCurrentUsbStoragePolicy(): UsbStoragePolicy {
    const result = PeripheralService.getUsbStoragePolicyWithResult()
    const policyValue = result.data as number | undefined
    switch (policyValue) {
      case UsbStoragePolicy.READ_ONLY:
        return UsbStoragePolicy.READ_ONLY
      case UsbStoragePolicy.DISABLED:
        return UsbStoragePolicy.DISABLED
      case UsbStoragePolicy.READ_WRITE:
      default:
        return UsbStoragePolicy.READ_WRITE
    }
  }

  private static resolveEffectivePolicyLabel(
    deviceId: string,
    deviceType: PeripheralType,
    snapshot: UsbPolicySnapshot
  ): string {
    if (snapshot.usbDisabled) {
      return StatusText.DISABLED
    }
    if (snapshot.devicePolicies.get(deviceId.toUpperCase()) === 'deny') {
      return StatusText.DISABLED
    }
    if (deviceType === PeripheralType.USB_STORAGE && snapshot.usbStoragePolicy === UsbStoragePolicy.DISABLED) {
      return StatusText.DISABLED
    }
    return StatusText.ENABLED
  }

  private static buildDisconnectDetail(info: ResolvedUsbEventInfo, effectivePolicyLabel: string): string {
    return PeripheralConnectionRecordStrings.buildDisconnectDetail(info.deviceName, effectivePolicyLabel)
  }

  private static resolveUsbEventInfo(data: commonEventManager.CommonEventData): ResolvedUsbEventInfo {
    const payloads = PeripheralConnectionRecordUsbConsumer.collectPayloadSources(data)
    const vendorId = PeripheralConnectionRecordUsbConsumer.resolveVendorId(payloads)
    const productId = PeripheralConnectionRecordUsbConsumer.resolveProductId(payloads)
    const resolvedOccurAt = PeripheralConnectionRecordUsbConsumer.resolveOccurAt(payloads)
    const occurAt = Number.isFinite(resolvedOccurAt) && resolvedOccurAt > 0 ? resolvedOccurAt : Date.now()
    const deviceNameField = PeripheralConnectionRecordUsbConsumer.resolveRawDeviceName(payloads)
    const productName = PeripheralConnectionRecordUsbConsumer.resolveProductName(payloads)
    const manufacturerName = PeripheralConnectionRecordUsbConsumer.resolveManufacturerName(payloads)
    let baseClass = PeripheralConnectionRecordUsbConsumer.resolveBaseClass(payloads)
    if (!Number.isFinite(baseClass) || baseClass <= 0) {
      baseClass = PeripheralConnectionRecordUsbConsumer.pickInterfaceClass(payloads)
    }
    const resolvedSubClass = PeripheralConnectionRecordUsbConsumer.resolveSubClass(payloads)
    const resolvedProtocol = PeripheralConnectionRecordUsbConsumer.resolveProtocol(payloads)
    const subClass = Number.isFinite(resolvedSubClass) ? resolvedSubClass : 0
    const protocol = Number.isFinite(resolvedProtocol) ? resolvedProtocol : 0

    const hasVidPid = Number.isFinite(vendorId) && Number.isFinite(productId)
    const deviceId = hasVidPid ? formatUsbDeviceId(vendorId, productId) : `UNKNOWN-USB-${occurAt}`
    let deviceName = PeripheralConnectionRecordUsbConsumer.buildUsbDisplayName(manufacturerName, productName)
    if (deviceName.length === 0) {
      deviceName = deviceNameField || (hasVidPid ? PeripheralConnectionRecordStrings.USB_DEVICE : PeripheralConnectionRecordStrings.UNRECOGNIZED_USB_DEVICE)
    }

    return {
      vendorId: hasVidPid ? vendorId : Number.NaN,
      productId: hasVidPid ? productId : Number.NaN,
      baseClass: Number.isFinite(baseClass) ? baseClass : Number.NaN,
      subClass: subClass,
      protocol: protocol,
      occurAt: occurAt,
      deviceName: deviceName,
      detail: PeripheralConnectionRecordUsbConsumer.resolveDetail(payloads, manufacturerName),
      deviceId: deviceId,
      deviceType: Number.isFinite(baseClass)
        ? inferPeripheralTypeFromBaseClass(baseClass)
        : PeripheralType.USB_OTHER
    }
  }

  private static collectPayloadSources(data: commonEventManager.CommonEventData): EventPayloadRecord[] {
    return collectPayloadSources(data as Object)
  }

  private static resolveVendorId(sources: EventPayloadRecord[]): number {
    return pickNumber(sources, ['vendorId', 'vid', 'vendor_id'])
  }

  private static resolveProductId(sources: EventPayloadRecord[]): number {
    return pickNumber(sources, ['productId', 'pid', 'product_id'])
  }

  private static resolveOccurAt(sources: EventPayloadRecord[]): number {
    return pickNumber(sources, ['timestamp', 'time', 'occurAt'])
  }

  private static resolveRawDeviceName(sources: EventPayloadRecord[]): string {
    return pickString(
      sources,
      ['deviceName', 'name', 'productName', 'product', 'manufacturerName']
    )
  }

  private static resolveProductName(sources: EventPayloadRecord[]): string {
    return pickString(sources, ['productName', 'product', 'deviceName', 'name'])
  }

  private static resolveManufacturerName(sources: EventPayloadRecord[]): string {
    return pickString(sources, ['manufacturerName', 'manufacturer', 'vendorName'])
  }

  private static resolveBaseClass(sources: EventPayloadRecord[]): number {
    return pickNumber(sources, ['baseClass', 'classCode', 'deviceClass', 'clazz'])
  }

  private static resolveSubClass(sources: EventPayloadRecord[]): number {
    return pickNumber(sources, ['subClass', 'subclass', 'usbSubClass'])
  }

  private static resolveProtocol(sources: EventPayloadRecord[]): number {
    return pickNumber(sources, ['protocol', 'usbProtocol'])
  }

  private static resolveDetail(sources: EventPayloadRecord[], manufacturerName: string): string {
    return pickString(sources, ['detail', 'message', 'description']) ||
      (manufacturerName.length > 0 ? `manufacturer=${manufacturerName}` : '')
  }

  private static pickInterfaceClass(sources: EventPayloadRecord[]): number {
    for (const source of sources) {
      const configs = toRecordArray(source['configs'])
      for (const config of configs) {
        const interfaces = toRecordArray(config['interfaces'])
        for (const item of interfaces) {
          const clazz = pickNumber(
            [item],
            ['clazz', 'baseClass', 'classCode', 'deviceClass']
          )
          if (Number.isFinite(clazz) && clazz > 0) {
            return clazz
          }
        }
      }
    }
    return Number.NaN
  }

  private static buildUsbDisplayName(manufacturerName: string, productName: string): string {
    const manufacturer = manufacturerName.trim()
    const product = productName.trim()
    if (manufacturer.length > 0 && product.length > 0) {
      return `${manufacturer} ${product}`
    }
    if (manufacturer.length > 0) {
      return manufacturer
    }
    if (product.length > 0) {
      return product
    }
    return ''
  }
}
