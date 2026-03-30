import { common } from '@kit.AbilityKit'
import { BusinessError, commonEventManager } from '@kit.BasicServicesKit'
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
  getUsbStoragePolicyLabel,
  inferPeripheralTypeFromBaseClass
} from '../models/DataModels'
import { PeripheralDevicePolicyRepository } from './PeripheralDevicePolicyRepository'
import { PeripheralTraceRepository } from './PeripheralTraceRepository'
import { PeripheralService } from './PeripheralService'

const TAG = 'PeripheralRuntimeEvent'
const DOMAIN = 0x000A

interface PeripheralRuntimeCapabilities {
  usbRuntimeEvents: boolean
  degradedReason?: string
}

interface PeripheralRuntimeStatus {
  running: boolean
  capabilities: PeripheralRuntimeCapabilities
}

export interface UsbRuntimeEvent {
  action: UsbEventAction
  deviceId: string
  deviceName: string
  deviceType: PeripheralType
  occurAt: number
}

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

export class PeripheralRuntimeEventService {
  private static context: common.UIAbilityContext | null = null
  private static initialized: boolean = false
  private static running: boolean = false
  private static subscriber: commonEventManager.CommonEventSubscriber | null = null
  private static capabilities: PeripheralRuntimeCapabilities = {
    usbRuntimeEvents: false,
    degradedReason: 'not_started'
  }
  private static lastSeenByKey: Map<string, number> = new Map()
  private static nextListenerId: number = 1
  private static listeners: Map<number, (event: UsbRuntimeEvent) => void> = new Map()

  static async init(context: common.UIAbilityContext): Promise<boolean> {
    PeripheralRuntimeEventService.context = context
    const traceInited = await PeripheralTraceRepository.init(context)
    const policyInited = await PeripheralDevicePolicyRepository.init(context)
    PeripheralRuntimeEventService.initialized = traceInited && policyInited
    if (!PeripheralRuntimeEventService.initialized) {
      PeripheralRuntimeEventService.capabilities = {
        usbRuntimeEvents: false,
        degradedReason: traceInited ? 'device_policy_repo_init_failed' : 'trace_repo_init_failed'
      }
    }
    return PeripheralRuntimeEventService.initialized
  }

  static async start(): Promise<boolean> {
    if (PeripheralRuntimeEventService.running) {
      return true
    }
    if (!PeripheralRuntimeEventService.initialized) {
      if (!PeripheralRuntimeEventService.context) {
        PeripheralRuntimeEventService.capabilities = {
          usbRuntimeEvents: false,
          degradedReason: 'not_initialized'
        }
        return false
      }
      const ok = await PeripheralRuntimeEventService.init(PeripheralRuntimeEventService.context)
      if (!ok) {
        return false
      }
    }

    PeripheralRuntimeEventService.stop()
    const usbReady = await PeripheralRuntimeEventService.registerUsbRuntimeEvents()
    PeripheralRuntimeEventService.capabilities = {
      usbRuntimeEvents: usbReady,
      degradedReason: usbReady ? undefined : 'usb_common_event_subscribe_failed'
    }
    PeripheralRuntimeEventService.running = usbReady
    hilog.info(DOMAIN, TAG, `start complete, running=${PeripheralRuntimeEventService.running}, usb=${usbReady}`)
    return PeripheralRuntimeEventService.running
  }

  static stop(): void {
    PeripheralRuntimeEventService.running = false
    if (!PeripheralRuntimeEventService.subscriber) {
      return
    }
    const subscriber = PeripheralRuntimeEventService.subscriber
    PeripheralRuntimeEventService.subscriber = null
    commonEventManager.unsubscribe(subscriber, (err?: BusinessError) => {
      if (err) {
        hilog.warn(DOMAIN, TAG, `unsubscribe failed: code=${err.code}, message=${err.message}`)
      }
    })
  }

  static addUsbEventListener(listener: (event: UsbRuntimeEvent) => void): number {
    const id = PeripheralRuntimeEventService.nextListenerId++
    PeripheralRuntimeEventService.listeners.set(id, listener)
    return id
  }

  static removeUsbEventListener(listenerId: number): void {
    PeripheralRuntimeEventService.listeners.delete(listenerId)
  }

  static getStatus(): PeripheralRuntimeStatus {
    return {
      running: PeripheralRuntimeEventService.running,
      capabilities: PeripheralRuntimeEventService.capabilities
    }
  }

  static probeCapabilities(): PeripheralRuntimeCapabilities {
    return {
      usbRuntimeEvents: PeripheralRuntimeEventService.capabilities.usbRuntimeEvents,
      degradedReason: PeripheralRuntimeEventService.capabilities.degradedReason
    }
  }

  private static async registerUsbRuntimeEvents(): Promise<boolean> {
    try {
      const subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
        events: [
          commonEventManager.Support.COMMON_EVENT_USB_DEVICE_ATTACHED,
          commonEventManager.Support.COMMON_EVENT_USB_DEVICE_DETACHED
        ]
      }
      const subscriber = await PeripheralRuntimeEventService.createSubscriber(subscribeInfo)
      const ok = await PeripheralRuntimeEventService.subscribe(subscriber)
      if (!ok) {
        return false
      }
      PeripheralRuntimeEventService.subscriber = subscriber
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, `registerUsbRuntimeEvents failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  private static createSubscriber(
    subscribeInfo: commonEventManager.CommonEventSubscribeInfo
  ): Promise<commonEventManager.CommonEventSubscriber> {
    return new Promise((resolve, reject) => {
      commonEventManager.createSubscriber(subscribeInfo, (err: BusinessError, subscriber) => {
        if (err) {
          reject(err)
          return
        }
        resolve(subscriber)
      })
    })
  }

  private static subscribe(subscriber: commonEventManager.CommonEventSubscriber): Promise<boolean> {
    return new Promise((resolve) => {
      try {
        commonEventManager.subscribe(subscriber, (err: BusinessError, data: commonEventManager.CommonEventData) => {
          if (err) {
            hilog.error(DOMAIN, TAG, `common event callback failed: code=${err.code}, message=${err.message}`)
            return
          }
          PeripheralRuntimeEventService.consumeUsbCommonEvent(data)
        })
        resolve(true)
      } catch (err) {
        hilog.error(DOMAIN, TAG, `subscribe failed: ${JSON.stringify(err)}`)
        resolve(false)
      }
    })
  }

  private static consumeUsbCommonEvent(data: commonEventManager.CommonEventData): void {
    const action = PeripheralRuntimeEventService.resolveAction(data.event)
    if (action === 'unknown') {
      hilog.warn(DOMAIN, TAG, `ignored unsupported usb event: ${data.event}`)
      return
    }
    const info = PeripheralRuntimeEventService.resolveUsbEventInfo(data)
    let rawPayload = ''
    try {
      rawPayload = JSON.stringify(data)
    } catch (_err) {
      rawPayload = ''
    }
    const evaluation = PeripheralRuntimeEventService.evaluateUsbEventPolicy(info, action)
    PeripheralRuntimeEventService.persistRuntimeRecord({
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
      rawEventName: data.event,
      rawAction: action,
      rawPayload: rawPayload,
      detail: evaluation.detail,
      usbPolicy: evaluation.usbPolicy,
      effectivePolicyLabel: evaluation.effectivePolicyLabel,
      matchedPolicyKind: evaluation.matchedPolicyKind
    })
  }

  private static evaluateUsbEventPolicy(
    info: ResolvedUsbEventInfo,
    action: UsbEventAction
  ): UsbEventPolicyEvaluation {
    const snapshot = PeripheralRuntimeEventService.readCurrentUsbPolicySnapshot()
    const effectivePolicyLabel = PeripheralRuntimeEventService.resolveEffectivePolicyLabel(info.deviceType, snapshot)
    PeripheralRuntimeEventService.logUsbPolicySnapshot(info, action, snapshot, effectivePolicyLabel)

    if (action === 'disconnect') {
      return {
        policyHit: 'unknown',
        result: LogEventResult.SUCCESS,
        summary: '设备已断开',
        detail: PeripheralRuntimeEventService.buildDisconnectDetail(info, effectivePolicyLabel),
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
          effectivePolicyLabel: getUsbStoragePolicyLabel(snapshot.usbStoragePolicy),
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
          effectivePolicyLabel: getUsbStoragePolicyLabel(snapshot.usbStoragePolicy),
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

  private static readCurrentUsbPolicySnapshot(): UsbPolicySnapshot {
    const devicePolicies: Map<string, PeripheralDevicePolicy> = new Map()
    PeripheralDevicePolicyRepository.getAll().forEach((item) => {
      devicePolicies.set(item.deviceId.toUpperCase(), item.policy)
    })
    return {
      usbDisabled: PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_USB).data ?? false,
      usbStoragePolicy: PeripheralRuntimeEventService.readCurrentUsbStoragePolicy(),
      devicePolicies: devicePolicies
    }
  }

  private static logUsbPolicySnapshot(
    info: ResolvedUsbEventInfo,
    action: UsbEventAction,
    snapshot: UsbPolicySnapshot,
    effectivePolicyLabel: string
  ): void {
    hilog.info(
      DOMAIN,
      TAG,
      `usb policy snapshot: action=${action}, deviceId=${info.deviceId}, deviceType=${info.deviceType}, usbDisabled=${snapshot.usbDisabled}, usbStoragePolicy=${snapshot.usbStoragePolicy}, devicePolicyCount=${snapshot.devicePolicies.size}, effectivePolicy=${effectivePolicyLabel}`
    )
  }

  private static resolveEffectivePolicyLabel(
    deviceType: PeripheralType,
    snapshot: UsbPolicySnapshot
  ): string {
    if (snapshot.usbDisabled) {
      return '已禁用'
    }
    if (deviceType === PeripheralType.USB_STORAGE) {
      return getUsbStoragePolicyLabel(snapshot.usbStoragePolicy)
    }
    return '已启用'
  }

  private static buildDisconnectDetail(info: ResolvedUsbEventInfo, effectivePolicyLabel: string): string {
    return `${info.deviceName} 已断开连接，断开前生效策略为：${effectivePolicyLabel}。`
  }

  private static resolveUsbEventInfo(data: commonEventManager.CommonEventData): ResolvedUsbEventInfo {
    const payloads = PeripheralRuntimeEventService.collectPayloadSources(data)
    const vendorId = PeripheralRuntimeEventService.pickNumber(payloads, ['vendorId', 'vid', 'vendor_id'])
    const productId = PeripheralRuntimeEventService.pickNumber(payloads, ['productId', 'pid', 'product_id'])
    const resolvedOccurAt = PeripheralRuntimeEventService.pickNumber(payloads, ['timestamp', 'time', 'occurAt'])
    const occurAt = Number.isFinite(resolvedOccurAt) && resolvedOccurAt > 0 ? resolvedOccurAt : Date.now()
    const deviceNameField = PeripheralRuntimeEventService.pickString(
      payloads,
      ['deviceName', 'name', 'productName', 'product', 'manufacturerName']
    )
    const productName = PeripheralRuntimeEventService.pickString(
      payloads,
      ['productName', 'product', 'deviceName', 'name']
    )
    const manufacturerName = PeripheralRuntimeEventService.pickString(
      payloads,
      ['manufacturerName', 'manufacturer', 'vendorName']
    )
    let baseClass = PeripheralRuntimeEventService.pickNumber(payloads, ['baseClass', 'classCode', 'deviceClass', 'clazz'])
    if (!Number.isFinite(baseClass) || baseClass <= 0) {
      baseClass = PeripheralRuntimeEventService.pickInterfaceClass(payloads)
    }
    const resolvedSubClass = PeripheralRuntimeEventService.pickNumber(payloads, ['subClass', 'subclass', 'usbSubClass'])
    const resolvedProtocol = PeripheralRuntimeEventService.pickNumber(payloads, ['protocol', 'usbProtocol'])
    const subClass = Number.isFinite(resolvedSubClass) ? resolvedSubClass : 0
    const protocol = Number.isFinite(resolvedProtocol) ? resolvedProtocol : 0

    const hasVidPid = Number.isFinite(vendorId) && Number.isFinite(productId)
    const deviceId = hasVidPid
      ? formatUsbDeviceId(vendorId, productId)
      : `UNKNOWN-USB-${occurAt}`
    let deviceName = PeripheralRuntimeEventService.buildUsbDisplayName(manufacturerName, productName)
    if (deviceName.length === 0) {
      deviceName = deviceNameField || (hasVidPid ? 'USB 设备' : '未识别 USB 设备')
    }

    const detail = PeripheralRuntimeEventService.pickString(payloads, ['detail', 'message', 'description']) ||
      (manufacturerName.length > 0 ? `manufacturer=${manufacturerName}` : '')

    return {
      vendorId: hasVidPid ? vendorId : Number.NaN,
      productId: hasVidPid ? productId : Number.NaN,
      baseClass: Number.isFinite(baseClass) ? baseClass : Number.NaN,
      subClass: subClass,
      protocol: protocol,
      occurAt: occurAt,
      deviceName: deviceName,
      detail: detail,
      deviceId: deviceId,
      deviceType: Number.isFinite(baseClass)
        ? inferPeripheralTypeFromBaseClass(baseClass)
        : PeripheralType.USB_OTHER
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

  private static persistRuntimeRecord(record: PeripheralTraceRecord): void {
    const now = Date.now()
    const dedupeKey = `${record.deviceId}|${record.action}|${record.rawEventName || ''}`
    const lastSeen = PeripheralRuntimeEventService.lastSeenByKey.get(dedupeKey) || 0
    if (now - lastSeen < 1500) {
      return
    }
    PeripheralRuntimeEventService.lastSeenByKey.set(dedupeKey, now)
    const appendPromise = PeripheralTraceRepository.append(record)
    appendPromise.then((ok: boolean) => {
      if (!ok) {
        hilog.warn(DOMAIN, TAG, `append runtime record failed, deviceId=${record.deviceId}`)
      }
    })
    PeripheralRuntimeEventService.notifyUsbEventListeners({
      action: record.action as UsbEventAction,
      deviceId: record.deviceId,
      deviceName: record.deviceName,
      deviceType: record.deviceType,
      occurAt: record.occurAt
    })
  }

  private static notifyUsbEventListeners(event: UsbRuntimeEvent): void {
    if (PeripheralRuntimeEventService.listeners.size <= 0) {
      return
    }
    PeripheralRuntimeEventService.listeners.forEach((listener: (event: UsbRuntimeEvent) => void) => {
      try {
        listener(event)
      } catch (err) {
        hilog.warn(DOMAIN, TAG, `usb event listener failed: ${JSON.stringify(err)}`)
      }
    })
  }

  private static collectPayloadSources(data: commonEventManager.CommonEventData): Record<string, Object>[] {
    const sources: Record<string, Object>[] = []
    const root = PeripheralRuntimeEventService.toRecord(data as Object)
    PeripheralRuntimeEventService.pushRecord(sources, root)
    PeripheralRuntimeEventService.pushRecord(sources, PeripheralRuntimeEventService.toRecord(data.parameters as Object))

    const want = PeripheralRuntimeEventService.readNestedRecord(root, 'want')
    PeripheralRuntimeEventService.pushRecord(sources, want)
    PeripheralRuntimeEventService.pushRecord(sources, PeripheralRuntimeEventService.readNestedRecord(want, 'parameters'))

    for (let index = 0; index < sources.length; index++) {
      const source = sources[index]
      PeripheralRuntimeEventService.pushRecord(sources, PeripheralRuntimeEventService.parseJsonObjectRecord(source['data']))
      PeripheralRuntimeEventService.pushRecord(sources, PeripheralRuntimeEventService.readNestedRecord(source, 'device'))
      PeripheralRuntimeEventService.pushRecord(sources, PeripheralRuntimeEventService.readNestedRecord(source, 'usbDevice'))
      PeripheralRuntimeEventService.pushRecord(sources, PeripheralRuntimeEventService.readNestedRecord(source, 'usb_device'))
    }
    return sources
  }

  private static pickNumber(sources: Record<string, Object>[], keys: string[]): number {
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

  private static pickString(sources: Record<string, Object>[], keys: string[]): string {
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

  private static pickInterfaceClass(sources: Record<string, Object>[]): number {
    for (const source of sources) {
      const configs = PeripheralRuntimeEventService.toRecordArray(source['configs'])
      for (const config of configs) {
        const interfaces = PeripheralRuntimeEventService.toRecordArray(config['interfaces'])
        for (const item of interfaces) {
          const clazz = PeripheralRuntimeEventService.pickNumber([item], ['clazz', 'baseClass', 'classCode', 'deviceClass'])
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

  private static pushRecord(target: Record<string, Object>[], value: Record<string, Object> | undefined): void {
    if (value === undefined) {
      return
    }
    target.push(value)
  }

  private static toRecord(value: Object | undefined | null): Record<string, Object> | undefined {
    if (!value || typeof value !== 'object') {
      return undefined
    }
    return value as Record<string, Object>
  }

  private static readNestedRecord(
    source: Record<string, Object> | undefined,
    key: string
  ): Record<string, Object> | undefined {
    if (source === undefined) {
      return undefined
    }
    return PeripheralRuntimeEventService.toRecord(source[key])
  }

  private static parseJsonObjectRecord(value: Object | undefined | null): Record<string, Object> | undefined {
    if (typeof value !== 'string') {
      return undefined
    }
    const normalized = value.trim()
    if (normalized.length === 0 || !normalized.startsWith('{')) {
      return undefined
    }
    try {
      return PeripheralRuntimeEventService.toRecord(JSON.parse(normalized) as Object)
    } catch (_err) {
      return undefined
    }
  }

  private static toRecordArray(value: Object | undefined | null): Record<string, Object>[] {
    if (!Array.isArray(value)) {
      return []
    }
    const result: Record<string, Object>[] = []
    for (const item of value as Object[]) {
      const record = PeripheralRuntimeEventService.toRecord(item)
      if (record) {
        result.push(record)
      }
    }
    return result
  }
}
