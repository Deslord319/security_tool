import { commonEventManager } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import {
  LogEventResult,
  PeripheralDevicePolicy,
  PeripheralMatchedPolicyKind,
  PeripheralRecordPolicyHit,
  PeripheralTraceRecord,
  PeripheralType,
  UsbStoragePolicy,
  formatUsbDeviceId,
  inferPeripheralTypeFromBaseClass
} from '../../../models/DataModels'
import { PeripheralDevicePolicyRepository } from '../../PeripheralDevicePolicyRepository'
import { PeripheralService } from '../../PeripheralService'
import {
  PeripheralConnectionRecordConsumeResult,
  PeripheralConnectionRecordConsumer,
  PeripheralConnectionRecordProducerEvent
} from './peripheral_connection_record_producer_contract'

const DOMAIN = 0x000A
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
type EventPayloadRecord = Record<string, Object>

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
      hilog.warn(DOMAIN, TAG, `ignored unsupported usb event: ${event.eventName}`)
      return null
    }

    const info = PeripheralConnectionRecordUsbConsumer.resolveUsbEventInfo(rawData)
    const evaluation = PeripheralConnectionRecordUsbConsumer.evaluateUsbEventPolicy(info, action)
    let rawPayload = ''
    try {
      rawPayload = JSON.stringify(rawData)
    } catch (_err) {
      rawPayload = ''
    }

    return {
      recordId: `runtime_usb_${info.occurAt}_${Math.random().toString(36).substring(2, 8)}`,
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
      info.deviceType,
      snapshot
    )

    if (action === 'disconnect') {
      return {
        policyHit: 'unknown',
        result: LogEventResult.SUCCESS,
        summary: '设备已断开',
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
        summary: 'USB 接口已禁用',
        detail: 'USB 接口已被总控禁用，设备接入被阻止。',
        usbPolicy: info.deviceType === PeripheralType.USB_STORAGE ? snapshot.usbStoragePolicy : undefined,
        effectivePolicyLabel: '已禁用',
        matchedPolicyKind: 'usb_disabled'
      }
    }

    if (info.deviceType === PeripheralType.USB_STORAGE) {
      if (snapshot.usbStoragePolicy === UsbStoragePolicy.DISABLED) {
        return {
          policyHit: 'deny',
          result: LogEventResult.BLOCKED,
          summary: 'USB 存储已禁用',
          detail: 'USB 存储策略为禁止访问，设备接入被阻止。',
          usbPolicy: snapshot.usbStoragePolicy,
          effectivePolicyLabel: PeripheralConnectionRecordUsbConsumer.getUsbStoragePolicyLabel(snapshot.usbStoragePolicy),
          matchedPolicyKind: 'usb_storage_disabled'
        }
      }
      if (snapshot.usbStoragePolicy === UsbStoragePolicy.READ_ONLY) {
        return {
          policyHit: 'allow',
          result: LogEventResult.SUCCESS,
          summary: 'USB 存储只读',
          detail: 'USB 存储策略为只读模式。',
          usbPolicy: snapshot.usbStoragePolicy,
          effectivePolicyLabel: PeripheralConnectionRecordUsbConsumer.getUsbStoragePolicyLabel(snapshot.usbStoragePolicy),
          matchedPolicyKind: 'usb_storage_read_only'
        }
      }
    }

    if (snapshot.devicePolicies.get(info.deviceId.toUpperCase()) === 'deny') {
      return {
        policyHit: 'deny',
        result: LogEventResult.BLOCKED,
        summary: '命中单设备禁止接入',
        detail: `设备 ${info.deviceId} 命中禁止接入策略，已被阻止。`,
        usbPolicy: info.deviceType === PeripheralType.USB_STORAGE ? snapshot.usbStoragePolicy : undefined,
        effectivePolicyLabel: effectivePolicyLabel,
        matchedPolicyKind: 'device_deny'
      }
    }

    return {
      policyHit: 'allow',
      result: LogEventResult.SUCCESS,
      summary: '按当前策略允许接入',
      detail: '未命中更高优先级的阻断策略，按默认规则允许接入。',
      usbPolicy: info.deviceType === PeripheralType.USB_STORAGE ? snapshot.usbStoragePolicy : undefined,
      effectivePolicyLabel: effectivePolicyLabel,
      matchedPolicyKind: 'default_allow'
    }
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

  private static resolveEffectivePolicyLabel(deviceType: PeripheralType, snapshot: UsbPolicySnapshot): string {
    if (snapshot.usbDisabled) {
      return '已禁用'
    }
    if (deviceType === PeripheralType.USB_STORAGE) {
      return PeripheralConnectionRecordUsbConsumer.getUsbStoragePolicyLabel(snapshot.usbStoragePolicy)
    }
    return '已启用'
  }

  private static buildDisconnectDetail(info: ResolvedUsbEventInfo, effectivePolicyLabel: string): string {
    return `${info.deviceName} 已断开连接，断开前生效策略为：${effectivePolicyLabel}。`
  }

  private static getUsbStoragePolicyLabel(policy: UsbStoragePolicy): string {
    switch (policy) {
      case UsbStoragePolicy.READ_WRITE:
        return '读写'
      case UsbStoragePolicy.READ_ONLY:
        return '只读'
      case UsbStoragePolicy.DISABLED:
        return '禁止访问'
      default:
        return '未知'
    }
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
      deviceName = deviceNameField || (hasVidPid ? 'USB 设备' : '未识别 USB 设备')
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
    const sources: EventPayloadRecord[] = []
    const root = PeripheralConnectionRecordUsbConsumer.toRecord(data as Object)
    const parameters = PeripheralConnectionRecordUsbConsumer.toRecord(data.parameters as Object)
    const want = PeripheralConnectionRecordUsbConsumer.readObjectField(root, 'want')
    const wantParameters = PeripheralConnectionRecordUsbConsumer.readObjectField(want, 'parameters')
    const rootData = PeripheralConnectionRecordUsbConsumer.parseJsonObjectField(root, 'data')
    const wantData = PeripheralConnectionRecordUsbConsumer.parseJsonObjectField(want, 'data')

    PeripheralConnectionRecordUsbConsumer.pushRecord(sources, root)
    PeripheralConnectionRecordUsbConsumer.pushRecord(sources, parameters)
    PeripheralConnectionRecordUsbConsumer.pushRecord(sources, want)
    PeripheralConnectionRecordUsbConsumer.pushRecord(sources, wantParameters)
    PeripheralConnectionRecordUsbConsumer.pushRecord(sources, rootData)
    PeripheralConnectionRecordUsbConsumer.pushRecord(sources, wantData)

    PeripheralConnectionRecordUsbConsumer.pushRecord(sources, PeripheralConnectionRecordUsbConsumer.readDeviceField(root))
    PeripheralConnectionRecordUsbConsumer.pushRecord(sources, PeripheralConnectionRecordUsbConsumer.readDeviceField(parameters))
    PeripheralConnectionRecordUsbConsumer.pushRecord(sources, PeripheralConnectionRecordUsbConsumer.readDeviceField(want))
    PeripheralConnectionRecordUsbConsumer.pushRecord(sources, PeripheralConnectionRecordUsbConsumer.readDeviceField(wantParameters))
    PeripheralConnectionRecordUsbConsumer.pushRecord(sources, PeripheralConnectionRecordUsbConsumer.readDeviceField(rootData))
    PeripheralConnectionRecordUsbConsumer.pushRecord(sources, PeripheralConnectionRecordUsbConsumer.readDeviceField(wantData))
    return sources
  }

  private static resolveVendorId(sources: EventPayloadRecord[]): number {
    return PeripheralConnectionRecordUsbConsumer.pickNumber(sources, ['vendorId', 'vid', 'vendor_id'])
  }

  private static resolveProductId(sources: EventPayloadRecord[]): number {
    return PeripheralConnectionRecordUsbConsumer.pickNumber(sources, ['productId', 'pid', 'product_id'])
  }

  private static resolveOccurAt(sources: EventPayloadRecord[]): number {
    return PeripheralConnectionRecordUsbConsumer.pickNumber(sources, ['timestamp', 'time', 'occurAt'])
  }

  private static resolveRawDeviceName(sources: EventPayloadRecord[]): string {
    return PeripheralConnectionRecordUsbConsumer.pickString(
      sources,
      ['deviceName', 'name', 'productName', 'product', 'manufacturerName']
    )
  }

  private static resolveProductName(sources: EventPayloadRecord[]): string {
    return PeripheralConnectionRecordUsbConsumer.pickString(sources, ['productName', 'product', 'deviceName', 'name'])
  }

  private static resolveManufacturerName(sources: EventPayloadRecord[]): string {
    return PeripheralConnectionRecordUsbConsumer.pickString(sources, ['manufacturerName', 'manufacturer', 'vendorName'])
  }

  private static resolveBaseClass(sources: EventPayloadRecord[]): number {
    return PeripheralConnectionRecordUsbConsumer.pickNumber(sources, ['baseClass', 'classCode', 'deviceClass', 'clazz'])
  }

  private static resolveSubClass(sources: EventPayloadRecord[]): number {
    return PeripheralConnectionRecordUsbConsumer.pickNumber(sources, ['subClass', 'subclass', 'usbSubClass'])
  }

  private static resolveProtocol(sources: EventPayloadRecord[]): number {
    return PeripheralConnectionRecordUsbConsumer.pickNumber(sources, ['protocol', 'usbProtocol'])
  }

  private static resolveDetail(sources: EventPayloadRecord[], manufacturerName: string): string {
    return PeripheralConnectionRecordUsbConsumer.pickString(sources, ['detail', 'message', 'description']) ||
      (manufacturerName.length > 0 ? `manufacturer=${manufacturerName}` : '')
  }

  private static pickNumber(sources: EventPayloadRecord[], keys: string[]): number {
    for (const source of sources) {
      for (const key of keys) {
        const value = source[key]
        if (typeof value === 'number' && Number.isFinite(value)) {
          return value
        }
        if (typeof value === 'string') {
          const normalized = value.trim()
          if (normalized.length === 0) {
            continue
          }
          const radix = normalized.startsWith('0x') || normalized.startsWith('0X') ? 16 : 10
          const parsed = parseInt(normalized.replace(/^0x/i, ''), radix)
          if (Number.isFinite(parsed)) {
            return parsed
          }
        }
      }
    }
    return Number.NaN
  }

  private static pickString(sources: EventPayloadRecord[], keys: string[]): string {
    for (const source of sources) {
      for (const key of keys) {
        const value = source[key]
        if (typeof value === 'string' && value.trim().length > 0) {
          return value.trim()
        }
      }
    }
    return ''
  }

  private static pickInterfaceClass(sources: EventPayloadRecord[]): number {
    for (const source of sources) {
      const configs = PeripheralConnectionRecordUsbConsumer.toRecordArray(source['configs'])
      for (const config of configs) {
        const interfaces = PeripheralConnectionRecordUsbConsumer.toRecordArray(config['interfaces'])
        for (const item of interfaces) {
          const clazz = PeripheralConnectionRecordUsbConsumer.pickNumber(
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

  private static pushRecord(target: EventPayloadRecord[], value: EventPayloadRecord | undefined): void {
    if (value === undefined) {
      return
    }
    if (target.some((item: EventPayloadRecord) => item === value)) {
      return
    }
    target.push(value)
  }

  private static toRecord(value: Object | undefined | null): EventPayloadRecord | undefined {
    if (!value || typeof value !== 'object') {
      return undefined
    }
    return value as EventPayloadRecord
  }

  private static readObjectField(
    source: EventPayloadRecord | undefined,
    key: string
  ): EventPayloadRecord | undefined {
    if (source === undefined) {
      return undefined
    }
    return PeripheralConnectionRecordUsbConsumer.toRecord(source[key])
  }

  private static parseJsonObjectField(
    source: EventPayloadRecord | undefined,
    key: string
  ): EventPayloadRecord | undefined {
    if (source === undefined) {
      return undefined
    }
    const value = source[key]
    if (typeof value !== 'string') {
      return undefined
    }
    const normalized = value.trim()
    if (normalized.length === 0 || !normalized.startsWith('{')) {
      return undefined
    }
    try {
      return PeripheralConnectionRecordUsbConsumer.toRecord(JSON.parse(normalized) as Object)
    } catch (_err) {
      return undefined
    }
  }

  private static readDeviceField(source: EventPayloadRecord | undefined): EventPayloadRecord | undefined {
    if (source === undefined) {
      return undefined
    }
    return PeripheralConnectionRecordUsbConsumer.readObjectField(source, 'device') ||
      PeripheralConnectionRecordUsbConsumer.readObjectField(source, 'remoteDevice') ||
      PeripheralConnectionRecordUsbConsumer.readObjectField(source, 'remote_device') ||
      PeripheralConnectionRecordUsbConsumer.readObjectField(source, 'bluetoothDevice') ||
      PeripheralConnectionRecordUsbConsumer.readObjectField(source, 'usbDevice') ||
      PeripheralConnectionRecordUsbConsumer.readObjectField(source, 'usb_device')
  }

  private static toRecordArray(value: Object | undefined | null): EventPayloadRecord[] {
    if (!Array.isArray(value)) {
      return []
    }
    const result: EventPayloadRecord[] = []
    for (const item of value as Object[]) {
      const record = PeripheralConnectionRecordUsbConsumer.toRecord(item)
      if (record) {
        result.push(record)
      }
    }
    return result
  }
}
