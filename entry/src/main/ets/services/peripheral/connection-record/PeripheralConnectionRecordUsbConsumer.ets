import { commonEventManager } from '@kit.BasicServicesKit'
import { SecurityEventResult } from '../../../models/CommonModels'
import {
  PeripheralMatchedPolicyKind,
  PeripheralRecordPolicyHit,
  PeripheralType,
  UsbDeviceIdentity,
  UsbStoragePolicy,
  formatUsbDeviceId,
  inferPeripheralTypeFromBaseClass
} from '../../../models/PeripheralModels'
import { PeripheralService } from '../interface-control/PeripheralService'
import {
  PeripheralConnectionRecordConsumeResult,
  PeripheralConnectionRecordConsumer,
  PeripheralConnectionRecordProducerEvent,
  PeripheralConnectionAction
} from './PeripheralConnectionRecordProducerContract'
import {
  EventPayloadRecord,
  collectPayloadSources,
  pickNumber,
  pickString,
  toRecordArray
} from './PeripheralConnectionRecordPayloadUtils'
import { LogUtils } from '../../../utils/LogUtils'
import { generateRandomSuffix } from '../../../utils/ValuePicker'
import { StatusText } from '../../../constants/StringCatalog'
import {
  PeripheralMatchedPolicyStrings,
  PeripheralConnectionRecordStrings
} from '../../../constants/modules/PeripheralStrings'
import { UsbDeviceNameResolver } from './UsbDeviceNameResolver'
import { UsbDeviceIdentityResolver } from '../device-policy/UsbDeviceIdentityResolver'
import {
  UsbDevicePolicyStateService,
  UsbPolicyStateProcessResult
} from '../device-policy/UsbDevicePolicyStateService'

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
  serialNumber: string
  description: string
  identity?: UsbDeviceIdentity
}

interface UsbPolicySnapshot {
  usbStoragePolicy: UsbStoragePolicy
}

interface UsbEventPolicyEvaluation {
  policyHit: PeripheralRecordPolicyHit
  result: SecurityEventResult
  summary: string
  detail: string
  usbPolicy?: UsbStoragePolicy
  effectivePolicyLabel: string
  matchedPolicyKind: PeripheralMatchedPolicyKind
}

export class PeripheralConnectionRecordUsbConsumer implements PeripheralConnectionRecordConsumer {
  canHandle(event: PeripheralConnectionRecordProducerEvent): boolean {
    return event.channel === 'usb'
  }

  async consume(event: PeripheralConnectionRecordProducerEvent): Promise<PeripheralConnectionRecordConsumeResult> {
    if (!this.canHandle(event)) {
      return null
    }
    const rawData = event.rawData
    if (!rawData) {
      return null
    }

    const action = PeripheralConnectionRecordUsbConsumer.resolveAction(event.eventName)
    if (action === 'unknown') {
      LogUtils.warn(TAG, `ignored unsupported usb event: ${event.eventName}`)
      return null
    }

    const info = PeripheralConnectionRecordUsbConsumer.resolveUsbEventInfo(rawData)
    if (PeripheralConnectionRecordUsbConsumer.isUsbHubEvent(info)) {
      LogUtils.info(TAG, `ignored usb hub event: baseClass=${info.baseClass}, deviceId=${info.deviceId}`)
      return null
    }
    const snapshot = PeripheralConnectionRecordUsbConsumer.readCurrentUsbPolicySnapshot()
    const skipDeviceDenyDispatch = info.deviceType === PeripheralType.USB_STORAGE &&
      snapshot.usbStoragePolicy === UsbStoragePolicy.DISABLED
    const stateResult = await PeripheralConnectionRecordUsbConsumer.updateUsbPolicyState(
      info,
      action,
      skipDeviceDenyDispatch
    )
    const evaluation = PeripheralConnectionRecordUsbConsumer.evaluateUsbEventPolicy(
      info,
      action,
      snapshot,
      stateResult
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

  private static resolveAction(eventName: string): PeripheralConnectionAction {
    switch (eventName) {
      case commonEventManager.Support.COMMON_EVENT_USB_DEVICE_ATTACHED:
        return 'connect'
      case commonEventManager.Support.COMMON_EVENT_USB_DEVICE_DETACHED:
        return 'disconnect'
      default:
        return 'unknown'
    }
  }

  private static isUsbHubEvent(info: ResolvedUsbEventInfo): boolean {
    return info.baseClass === 0x09
  }

  private static evaluateUsbEventPolicy(
    info: ResolvedUsbEventInfo,
    action: PeripheralConnectionAction,
    snapshot: UsbPolicySnapshot,
    stateResult: UsbPolicyStateProcessResult | null
  ): UsbEventPolicyEvaluation {
    const effectivePolicyLabel = PeripheralConnectionRecordUsbConsumer.resolveEffectivePolicyLabel(
      info.deviceType,
      snapshot,
      stateResult
    )

    if (action === 'disconnect') {
      return {
        policyHit: 'unknown',
        result: SecurityEventResult.SUCCESS,
        summary: PeripheralConnectionRecordStrings.USB_DISCONNECTED,
        detail: PeripheralConnectionRecordUsbConsumer.buildDisconnectDetail(info, effectivePolicyLabel),
        usbPolicy: info.deviceType === PeripheralType.USB_STORAGE ? snapshot.usbStoragePolicy : undefined,
        effectivePolicyLabel: effectivePolicyLabel,
        matchedPolicyKind: 'disconnect_event'
      }
    }

    if (info.deviceType === PeripheralType.USB_STORAGE) {
      if (snapshot.usbStoragePolicy === UsbStoragePolicy.DISABLED) {
        return {
          policyHit: 'deny',
          result: SecurityEventResult.BLOCKED,
          summary: PeripheralMatchedPolicyStrings.USB_STORAGE_DISABLED,
          detail: PeripheralConnectionRecordStrings.USB_STORAGE_DISABLED_DETAIL,
          usbPolicy: snapshot.usbStoragePolicy,
          effectivePolicyLabel: StatusText.DISABLED,
          matchedPolicyKind: 'usb_storage_disabled'
        }
      }
    }

    if (stateResult?.desiredPolicy === 'deny') {
      if (stateResult.dispatchResult && !stateResult.dispatchResult.success) {
        return {
          policyHit: 'allow',
          result: SecurityEventResult.SUCCESS,
          summary: PeripheralConnectionRecordStrings.DEFAULT_ALLOW,
          detail: PeripheralConnectionRecordStrings.appendAutoDenyFailedDetail(
            PeripheralConnectionRecordStrings.DEFAULT_ALLOW_DETAIL,
            stateResult.dispatchResult.reason ?? stateResult.dispatchResult.errorMessage
          ),
          usbPolicy: info.deviceType === PeripheralType.USB_STORAGE ? snapshot.usbStoragePolicy : undefined,
          effectivePolicyLabel: StatusText.ENABLED,
          matchedPolicyKind: 'default_allow'
        }
      }
      return {
        policyHit: 'deny',
        result: SecurityEventResult.BLOCKED,
        summary: PeripheralMatchedPolicyStrings.DEVICE_DENY,
        detail: stateResult.autoDenyApplied
          ? PeripheralConnectionRecordStrings.appendAutoDenySavedDetail(
            PeripheralConnectionRecordStrings.buildDeviceDenyDetail(info.deviceId)
          )
          : PeripheralConnectionRecordStrings.buildDeviceDenyDetail(info.deviceId),
        usbPolicy: info.deviceType === PeripheralType.USB_STORAGE ? snapshot.usbStoragePolicy : undefined,
        effectivePolicyLabel: StatusText.DISABLED,
        matchedPolicyKind: 'device_deny'
      }
    }

    if (info.deviceType === PeripheralType.USB_STORAGE && snapshot.usbStoragePolicy === UsbStoragePolicy.READ_ONLY) {
      return {
        policyHit: 'allow',
        result: SecurityEventResult.SUCCESS,
        summary: PeripheralMatchedPolicyStrings.USB_STORAGE_READ_ONLY,
        detail: PeripheralConnectionRecordStrings.USB_STORAGE_READ_ONLY_DETAIL,
        usbPolicy: snapshot.usbStoragePolicy,
        effectivePolicyLabel: StatusText.ENABLED,
        matchedPolicyKind: 'usb_storage_read_only'
      }
    }

    return {
      policyHit: 'allow',
      result: SecurityEventResult.SUCCESS,
      summary: PeripheralConnectionRecordStrings.DEFAULT_ALLOW,
      detail: PeripheralConnectionRecordStrings.DEFAULT_ALLOW_DETAIL,
      usbPolicy: info.deviceType === PeripheralType.USB_STORAGE ? snapshot.usbStoragePolicy : undefined,
      effectivePolicyLabel: effectivePolicyLabel,
      matchedPolicyKind: 'default_allow'
    }
  }

  private static async updateUsbPolicyState(
    info: ResolvedUsbEventInfo,
    action: PeripheralConnectionAction,
    skipDeviceDenyDispatch: boolean
  ): Promise<UsbPolicyStateProcessResult | null> {
    if (!info.identity) {
      return null
    }
    if (action === 'connect') {
      return UsbDevicePolicyStateService.handleConnect(info.identity, info.occurAt, skipDeviceDenyDispatch)
    }
    if (action === 'disconnect') {
      return UsbDevicePolicyStateService.handleDisconnect(info.identity, info.occurAt)
    }
    return null
  }

  private static readCurrentUsbPolicySnapshot(): UsbPolicySnapshot {
    return {
      usbStoragePolicy: PeripheralConnectionRecordUsbConsumer.readCurrentUsbStoragePolicy()
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
    deviceType: PeripheralType,
    snapshot: UsbPolicySnapshot,
    stateResult: UsbPolicyStateProcessResult | null
  ): string {
    if (stateResult?.desiredPolicy === 'deny') {
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
    const deviceNameField = PeripheralConnectionRecordUsbConsumer.resolveDeviceName(payloads)
    const productName = PeripheralConnectionRecordUsbConsumer.resolveProductName(payloads)
    const manufacturerName = PeripheralConnectionRecordUsbConsumer.resolveManufacturerName(payloads)
    const serialNumber = PeripheralConnectionRecordUsbConsumer.resolveSerialNumber(payloads)
    const description = PeripheralConnectionRecordUsbConsumer.resolveDescription(payloads)
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
    const deviceName = UsbDeviceNameResolver.resolve({
      manufacturerName: manufacturerName,
      productName: productName,
      deviceName: deviceNameField
    }, hasVidPid ? PeripheralConnectionRecordStrings.USB_DEVICE : PeripheralConnectionRecordStrings.UNRECOGNIZED_USB_DEVICE)
    const identity = UsbDeviceIdentityResolver.resolve({
      vendorId: hasVidPid ? vendorId : Number.NaN,
      productId: hasVidPid ? productId : Number.NaN,
      baseClass: Number.isFinite(baseClass) ? baseClass : Number.NaN,
      deviceName: deviceName,
      serialNumber: serialNumber,
      description: description
    }) ?? undefined

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
        : PeripheralType.USB_OTHER,
      serialNumber: serialNumber,
      description: description,
      identity: identity
    }
  }

  private static collectPayloadSources(data: commonEventManager.CommonEventData): EventPayloadRecord[] {
    return collectPayloadSources(data)
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

  private static resolveDeviceName(sources: EventPayloadRecord[]): string {
    return pickString(sources, ['deviceName'])
  }

  private static resolveProductName(sources: EventPayloadRecord[]): string {
    return pickString(sources, ['productName', 'product'])
  }

  private static resolveManufacturerName(sources: EventPayloadRecord[]): string {
    return pickString(sources, ['manufacturerName', 'manufacturer', 'vendorName'])
  }

  private static resolveSerialNumber(sources: EventPayloadRecord[]): string {
    return pickString(sources, ['serialNumber', 'serial', 'sn'])
  }

  private static resolveDescription(sources: EventPayloadRecord[]): string {
    return pickString(sources, ['description'])
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

}
