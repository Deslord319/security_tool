import { common } from '@kit.AbilityKit'
import { BusinessError, commonEventManager } from '@kit.BasicServicesKit'
import { abilityAccessCtrl, bundleManager, Permissions } from '@kit.AbilityKit'
import { access, connection } from '@kit.ConnectivityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import {
  LogEventResult,
  PeripheralDevicePolicy,
  PeripheralMatchedPolicyKind,
  PeripheralRecordPolicyHit,
  PeripheralTraceRecord,
  PeripheralType,
  UsbStoragePolicy,
  formatBluetoothDeviceId,
  formatUsbDeviceId,
  inferPeripheralTypeFromBaseClass
} from '../models/DataModels'
import { PeripheralDevicePolicyRepository } from './PeripheralDevicePolicyRepository'
import { PeripheralTraceRepository } from './PeripheralTraceRepository'
import { PeripheralService } from './PeripheralService'

const TAG = 'PeripheralRuntimeEvent'
const DOMAIN = 0x000A
const FALLBACK_BLUETOOTH_NAME = '未命名蓝牙设备'
const BLUETOOTH_RUNTIME_PERMISSION: Permissions = 'ohos.permission.ACCESS_BLUETOOTH'
const BLUETOOTH_ACL_EVENT = commonEventManager.Support.COMMON_EVENT_BLUETOOTH_REMOTEDEVICE_ACL_STATE_CHANGE

interface PeripheralRuntimeCapabilities {
  usbRuntimeEvents: boolean
  bluetoothRuntimeEvents: boolean
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

export interface PeripheralRuntimeCommonEvent {
  channel: 'usb' | 'bluetooth_acl'
  eventName: string
  payload?: Object
  rawData: commonEventManager.CommonEventData
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
type EventPayloadRecord = Record<string, Object>
type BluetoothStateCallback = (state: access.BluetoothState) => void
type BluetoothBondStateCallback = (data: connection.BondStateParam) => void
type BluetoothAclAction = 'connect' | 'disconnect' | 'unknown'

interface BluetoothNameResolution {
  name: string
  source: 'event_payload' | 'remote_name' | 'fallback'
}

interface BluetoothAclEventInfo {
  occurAt: number
  deviceId: string
  rawDeviceId: string
  deviceName: string
  action: BluetoothAclAction
  stateLabel: string
  reasonLabel: string
  rawPayload: string
}

export class PeripheralRuntimeEventService {
  private static context: common.UIAbilityContext | null = null
  private static initialized: boolean = false
  private static running: boolean = false
  private static usbSubscriber: commonEventManager.CommonEventSubscriber | null = null
  private static bluetoothAclSubscriber: commonEventManager.CommonEventSubscriber | null = null
  private static capabilities: PeripheralRuntimeCapabilities = {
    usbRuntimeEvents: false,
    bluetoothRuntimeEvents: false,
    degradedReason: 'not_started'
  }
  private static lastSeenByKey: Map<string, number> = new Map()
  private static nextListenerId: number = 1
  private static listeners: Map<number, (event: UsbRuntimeEvent) => void> = new Map()
  private static nextRuntimeCommonListenerId: number = 1
  private static runtimeCommonListeners: Map<number, (event: PeripheralRuntimeCommonEvent) => void> = new Map()
  private static bluetoothStateListener: BluetoothStateCallback | undefined
  private static bluetoothBondStateListener: BluetoothBondStateCallback | undefined
  private static bluetoothCurrentState: access.BluetoothState = access.BluetoothState.STATE_OFF
  private static bluetoothPermissionBlocked: boolean = false
  private static bluetoothPermissionPrompted: boolean = false
  private static bluetoothPermissionRequestInFlight: boolean = false

  static async init(context: common.UIAbilityContext): Promise<boolean> {
    PeripheralRuntimeEventService.context = context
    const traceInited = await PeripheralTraceRepository.init(context)
    const policyInited = await PeripheralDevicePolicyRepository.init(context)
    PeripheralRuntimeEventService.initialized = traceInited && policyInited
    if (!PeripheralRuntimeEventService.initialized) {
      PeripheralRuntimeEventService.capabilities = {
        usbRuntimeEvents: false,
        bluetoothRuntimeEvents: false,
        degradedReason: traceInited ? 'device_policy_repo_init_failed' : 'trace_repo_init_failed'
      }
    }
    return PeripheralRuntimeEventService.initialized
  }

  static async start(): Promise<boolean> {
    if (PeripheralRuntimeEventService.running) {
      await PeripheralRuntimeEventService.resumeBluetoothAclSubscriptionIfNeeded('start-called')
      return true
    }
    if (!PeripheralRuntimeEventService.initialized) {
      if (!PeripheralRuntimeEventService.context) {
        PeripheralRuntimeEventService.capabilities = {
          usbRuntimeEvents: false,
          bluetoothRuntimeEvents: false,
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
    const bluetoothReady = await PeripheralRuntimeEventService.registerBluetoothRuntimeEvents()
    PeripheralRuntimeEventService.capabilities = {
      usbRuntimeEvents: usbReady,
      bluetoothRuntimeEvents: bluetoothReady,
      degradedReason: PeripheralRuntimeEventService.buildDegradedReason(usbReady, bluetoothReady)
    }
    PeripheralRuntimeEventService.running = usbReady || bluetoothReady
    hilog.info(
      DOMAIN,
      TAG,
      `start complete, running=${PeripheralRuntimeEventService.running}, usb=${usbReady}, bluetooth=${bluetoothReady}, degradedReason=${PeripheralRuntimeEventService.capabilities.degradedReason ?? 'none'}`
    )
    return PeripheralRuntimeEventService.running
  }

  static stop(): void {
    PeripheralRuntimeEventService.running = false
    const usbSubscriber = PeripheralRuntimeEventService.usbSubscriber
    PeripheralRuntimeEventService.usbSubscriber = null
    if (usbSubscriber) {
      commonEventManager.unsubscribe(usbSubscriber, (err?: BusinessError) => {
        if (err) {
          hilog.warn(DOMAIN, TAG, `usb unsubscribe failed: code=${err.code}, message=${err.message}`)
        }
      })
    }
    PeripheralRuntimeEventService.cleanupBluetoothRuntimeEvents()
  }

  static addUsbEventListener(listener: (event: UsbRuntimeEvent) => void): number {
    const id = PeripheralRuntimeEventService.nextListenerId++
    PeripheralRuntimeEventService.listeners.set(id, listener)
    return id
  }

  static removeUsbEventListener(listenerId: number): void {
    PeripheralRuntimeEventService.listeners.delete(listenerId)
  }

  static addRuntimeCommonEventListener(listener: (event: PeripheralRuntimeCommonEvent) => void): number {
    const id = PeripheralRuntimeEventService.nextRuntimeCommonListenerId++
    PeripheralRuntimeEventService.runtimeCommonListeners.set(id, listener)
    return id
  }

  static removeRuntimeCommonEventListener(listenerId: number): void {
    PeripheralRuntimeEventService.runtimeCommonListeners.delete(listenerId)
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
      bluetoothRuntimeEvents: PeripheralRuntimeEventService.capabilities.bluetoothRuntimeEvents,
      degradedReason: PeripheralRuntimeEventService.capabilities.degradedReason
    }
  }

  private static async registerUsbRuntimeEvents(): Promise<boolean> {
    return new Promise((resolve) => {
      try {
        const subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
          events: [
            commonEventManager.Support.COMMON_EVENT_USB_DEVICE_ATTACHED,
            commonEventManager.Support.COMMON_EVENT_USB_DEVICE_DETACHED
          ]
        }
        commonEventManager.createSubscriber(subscribeInfo, (err: BusinessError, subscriber) => {
          if (err) {
            hilog.error(DOMAIN, TAG, `createSubscriber failed: code=${err.code}, message=${err.message}`)
            resolve(false)
            return
          }
          commonEventManager.subscribe(subscriber, (callbackErr: BusinessError, data: commonEventManager.CommonEventData) => {
            if (callbackErr) {
              hilog.error(DOMAIN, TAG, `common event callback failed: code=${callbackErr.code}, message=${callbackErr.message}`)
              return
            }
            PeripheralRuntimeEventService.notifyRuntimeCommonEventListeners('usb', data)
            PeripheralRuntimeEventService.consumeUsbCommonEvent(data)
          })
          PeripheralRuntimeEventService.usbSubscriber = subscriber
          resolve(true)
        })
      } catch (err) {
        const error = err as BusinessError
        hilog.error(
          DOMAIN,
          TAG,
          `registerUsbRuntimeEvents failed: code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`
        )
        resolve(false)
      }
    })
  }

  private static async registerBluetoothRuntimeEvents(): Promise<boolean> {
    try {
      PeripheralRuntimeEventService.bluetoothStateListener = (state: access.BluetoothState): void => {
        PeripheralRuntimeEventService.handleBluetoothStateChange(state)
      }
      PeripheralRuntimeEventService.bluetoothBondStateListener = (data: connection.BondStateParam): void => {
        PeripheralRuntimeEventService.logBluetoothBondState(data)
      }

      access.on('stateChange', PeripheralRuntimeEventService.bluetoothStateListener)
      connection.on('bondStateChange', PeripheralRuntimeEventService.bluetoothBondStateListener)

      const currentState = access.getState()
      hilog.info(DOMAIN, TAG, `bluetooth state queried: state=${PeripheralRuntimeEventService.getBluetoothStateLabel(currentState)}`)
      await PeripheralRuntimeEventService.handleBluetoothStateChange(currentState)
      return true
    } catch (err) {
      const error = err as BusinessError
      hilog.error(
        DOMAIN,
        TAG,
        `registerBluetoothRuntimeEvents failed: code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`
      )
      PeripheralRuntimeEventService.cleanupBluetoothRuntimeEvents()
      return false
    }
  }

  private static consumeUsbCommonEvent(data: commonEventManager.CommonEventData): void {
    const record = PeripheralRuntimeEventService.mapUsbCommonEventToTraceRecord(data)
    if (!record) {
      return
    }
    PeripheralRuntimeEventService.persistRuntimeRecord(record, true)
  }

  static mapUsbCommonEventToTraceRecord(data: commonEventManager.CommonEventData): PeripheralTraceRecord | null {
    const action = PeripheralRuntimeEventService.resolveAction(data.event)
    if (action === 'unknown') {
      hilog.warn(DOMAIN, TAG, `ignored unsupported usb event: ${data.event}`)
      return null
    }
    const info = PeripheralRuntimeEventService.resolveUsbEventInfo(data)
    const evaluation = PeripheralRuntimeEventService.evaluateUsbEventPolicy(info, action)
    let rawPayload = ''
    try {
      rawPayload = JSON.stringify(data)
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
      rawEventName: data.event,
      rawAction: action,
      rawPayload: rawPayload,
      detail: evaluation.detail,
      usbPolicy: evaluation.usbPolicy,
      effectivePolicyLabel: evaluation.effectivePolicyLabel,
      matchedPolicyKind: evaluation.matchedPolicyKind
    }
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
          effectivePolicyLabel: PeripheralRuntimeEventService.getUsbStoragePolicyLabel(snapshot.usbStoragePolicy),
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
          effectivePolicyLabel: PeripheralRuntimeEventService.getUsbStoragePolicyLabel(snapshot.usbStoragePolicy),
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
      return PeripheralRuntimeEventService.getUsbStoragePolicyLabel(snapshot.usbStoragePolicy)
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
    const payloads = PeripheralRuntimeEventService.collectPayloadSources(data)
    const vendorId = PeripheralRuntimeEventService.resolveVendorId(payloads)
    const productId = PeripheralRuntimeEventService.resolveProductId(payloads)
    const resolvedOccurAt = PeripheralRuntimeEventService.resolveOccurAt(payloads)
    const occurAt = Number.isFinite(resolvedOccurAt) && resolvedOccurAt > 0 ? resolvedOccurAt : Date.now()
    const deviceNameField = PeripheralRuntimeEventService.resolveRawDeviceName(payloads)
    const productName = PeripheralRuntimeEventService.resolveProductName(payloads)
    const manufacturerName = PeripheralRuntimeEventService.resolveManufacturerName(payloads)
    let baseClass = PeripheralRuntimeEventService.resolveBaseClass(payloads)
    if (!Number.isFinite(baseClass) || baseClass <= 0) {
      baseClass = PeripheralRuntimeEventService.pickInterfaceClass(payloads)
    }
    const resolvedSubClass = PeripheralRuntimeEventService.resolveSubClass(payloads)
    const resolvedProtocol = PeripheralRuntimeEventService.resolveProtocol(payloads)
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

    const detail = PeripheralRuntimeEventService.resolveDetail(payloads, manufacturerName)

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

  private static persistRuntimeRecord(
    record: PeripheralTraceRecord,
    notifyUsbListeners: boolean = false,
    applyDedupe: boolean = true
  ): void {
    if (applyDedupe) {
      const now = Date.now()
      const dedupeKey = `${record.deviceId}|${record.action}|${record.rawEventName || ''}`
      const lastSeen = PeripheralRuntimeEventService.lastSeenByKey.get(dedupeKey) || 0
      if (now - lastSeen < 1500) {
        return
      }
      PeripheralRuntimeEventService.lastSeenByKey.set(dedupeKey, now)
    }
    void PeripheralTraceRepository.append(record).then((ok: boolean) => {
      if (!ok) {
        hilog.warn(DOMAIN, TAG, `append runtime record failed, deviceId=${record.deviceId}`)
      }
    })
    if (notifyUsbListeners) {
      PeripheralRuntimeEventService.notifyUsbEventListeners({
        action: record.action as UsbEventAction,
        deviceId: record.deviceId,
        deviceName: record.deviceName,
        deviceType: record.deviceType,
        occurAt: record.occurAt
      })
    }
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

  private static notifyRuntimeCommonEventListeners(
    channel: 'usb' | 'bluetooth_acl',
    data: commonEventManager.CommonEventData
  ): void {
    if (PeripheralRuntimeEventService.runtimeCommonListeners.size <= 0) {
      return
    }
    const commonEvent: PeripheralRuntimeCommonEvent = {
      channel: channel,
      eventName: data.event ?? '',
      rawData: data
    }
    const payload = data.parameters as Object | undefined
    if (payload !== undefined) {
      commonEvent.payload = payload
    }
    PeripheralRuntimeEventService.runtimeCommonListeners.forEach(
      (listener: (event: PeripheralRuntimeCommonEvent) => void) => {
        try {
          listener(commonEvent)
        } catch (_err) {
        }
      }
    )
  }

  private static cleanupBluetoothRuntimeEvents(): void {
    PeripheralRuntimeEventService.cleanupBluetoothAclSubscriber('service-stop')
    if (PeripheralRuntimeEventService.bluetoothStateListener) {
      try {
        access.off('stateChange', PeripheralRuntimeEventService.bluetoothStateListener)
      } catch (_err) {
      }
    }
    if (PeripheralRuntimeEventService.bluetoothBondStateListener) {
      try {
        connection.off('bondStateChange', PeripheralRuntimeEventService.bluetoothBondStateListener)
      } catch (_err) {
      }
    }
    PeripheralRuntimeEventService.bluetoothStateListener = undefined
    PeripheralRuntimeEventService.bluetoothBondStateListener = undefined
    PeripheralRuntimeEventService.bluetoothCurrentState = access.BluetoothState.STATE_OFF
  }

  private static async handleBluetoothStateChange(state: access.BluetoothState): Promise<void> {
    PeripheralRuntimeEventService.bluetoothCurrentState = state
    const stateLabel = PeripheralRuntimeEventService.getBluetoothStateLabel(state)
    hilog.info(DOMAIN, TAG, `bluetooth state change: state=${stateLabel}`)
    if (state === access.BluetoothState.STATE_ON || state === access.BluetoothState.STATE_BLE_ON) {
      await PeripheralRuntimeEventService.resumeBluetoothAclSubscriptionIfNeeded(`state=${stateLabel}`)
    }
  }

  private static async resumeBluetoothAclSubscriptionIfNeeded(trigger: string): Promise<void> {
    if (!PeripheralRuntimeEventService.running && !PeripheralRuntimeEventService.bluetoothStateListener) {
      return
    }
    if (!PeripheralRuntimeEventService.isBluetoothRuntimeActive()) {
      hilog.info(
        DOMAIN,
        TAG,
        `skip resumeBluetoothAclSubscriptionIfNeeded: trigger=${trigger}, state=${PeripheralRuntimeEventService.getBluetoothStateLabel(PeripheralRuntimeEventService.bluetoothCurrentState)}`
      )
      return
    }
    if (PeripheralRuntimeEventService.bluetoothAclSubscriber) {
      return
    }

    const permissionGranted = await PeripheralRuntimeEventService.ensureBluetoothRuntimePermission(trigger)
    if (!permissionGranted) {
      return
    }

    await PeripheralRuntimeEventService.subscribeBluetoothAclStateChange(trigger)
  }

  private static async subscribeBluetoothAclStateChange(trigger: string): Promise<void> {
    if (PeripheralRuntimeEventService.bluetoothAclSubscriber) {
      return
    }
    await new Promise<void>((resolve) => {
      try {
        const subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
          events: [BLUETOOTH_ACL_EVENT]
        }
        commonEventManager.createSubscriber(subscribeInfo, (err: BusinessError, subscriber) => {
          if (err) {
            if (PeripheralRuntimeEventService.isBluetoothPermissionDeniedError(err)) {
              PeripheralRuntimeEventService.enterBluetoothPermissionBlocked(`acl-subscriber-create-denied:${trigger}`)
            }
            hilog.warn(
              DOMAIN,
              TAG,
              `bluetooth acl createSubscriber failed: trigger=${trigger}, code=${err.code}, message=${err.message}`
            )
            resolve()
            return
          }
          commonEventManager.subscribe(
            subscriber,
            (callbackErr: BusinessError, data: commonEventManager.CommonEventData) => {
              if (callbackErr) {
                hilog.warn(
                  DOMAIN,
                  TAG,
                  `bluetooth acl callback failed: code=${callbackErr.code}, message=${callbackErr.message}`
                )
                return
              }
              PeripheralRuntimeEventService.notifyRuntimeCommonEventListeners('bluetooth_acl', data)
              void PeripheralRuntimeEventService.consumeBluetoothAclCommonEvent(data)
            }
          )
          PeripheralRuntimeEventService.bluetoothAclSubscriber = subscriber
          PeripheralRuntimeEventService.bluetoothPermissionBlocked = false
          hilog.info(DOMAIN, TAG, `bluetooth acl subscriber ready: trigger=${trigger}`)
          resolve()
        })
      } catch (err) {
        const error = err as BusinessError
        if (PeripheralRuntimeEventService.isBluetoothPermissionDeniedError(error)) {
          PeripheralRuntimeEventService.enterBluetoothPermissionBlocked(`acl-subscriber-subscribe-denied:${trigger}`)
        }
        hilog.warn(
          DOMAIN,
          TAG,
          `bluetooth acl subscribe failed: trigger=${trigger}, code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`
        )
        resolve()
      }
    })
  }

  private static cleanupBluetoothAclSubscriber(reason: string): void {
    const subscriber = PeripheralRuntimeEventService.bluetoothAclSubscriber
    PeripheralRuntimeEventService.bluetoothAclSubscriber = null
    if (!subscriber) {
      return
    }
    commonEventManager.unsubscribe(subscriber, (err?: BusinessError) => {
      if (err) {
        hilog.warn(
          DOMAIN,
          TAG,
          `bluetooth acl unsubscribe failed: reason=${reason}, code=${err.code}, message=${err.message}`
        )
        return
      }
      hilog.info(DOMAIN, TAG, `bluetooth acl subscriber cleaned: reason=${reason}`)
    })
  }

  static async mapBluetoothAclCommonEventToTraceRecord(
    data: commonEventManager.CommonEventData
  ): Promise<PeripheralTraceRecord | null> {
    const eventInfo = await PeripheralRuntimeEventService.resolveBluetoothAclEventInfo(data)
    if (!eventInfo) {
      return null
    }
    if (eventInfo.action === 'unknown') {
      return null
    }
    return {
      recordId: `runtime_bt_acl_${eventInfo.occurAt}_${Math.random().toString(36).substring(2, 8)}`,
      occurAt: eventInfo.occurAt,
      collectAt: Date.now(),
      deviceName: eventInfo.deviceName,
      deviceType: PeripheralType.BLUETOOTH,
      deviceId: eventInfo.deviceId,
      action: eventInfo.action,
      decision: 'unknown',
      result: LogEventResult.SUCCESS,
      source: 'runtime_event',
      summary: eventInfo.action === 'connect' ? '蓝牙设备已连接' : '蓝牙设备已断开',
      rawEventName: data.event,
      rawAction: eventInfo.action,
      rawPayload: eventInfo.rawPayload,
      detail: `aclState=${eventInfo.stateLabel}, reason=${eventInfo.reasonLabel}`,
      effectivePolicyLabel: '--',
      matchedPolicyKind: 'bluetooth_connection_event'
    }
  }

  private static async consumeBluetoothAclCommonEvent(data: commonEventManager.CommonEventData): Promise<void> {
    const eventInfo = await PeripheralRuntimeEventService.resolveBluetoothAclEventInfo(data)
    if (!eventInfo) {
      return
    }

    if (eventInfo.action === 'unknown') {
      hilog.info(
        DOMAIN,
        TAG,
        `skip bluetooth acl event with unsupported state: deviceId=${PeripheralRuntimeEventService.maskBluetoothIdentifier(eventInfo.rawDeviceId)}, state=${eventInfo.stateLabel}`
      )
      return
    }

    PeripheralRuntimeEventService.persistRuntimeRecord({
      recordId: `runtime_bt_acl_${eventInfo.occurAt}_${Math.random().toString(36).substring(2, 8)}`,
      occurAt: eventInfo.occurAt,
      collectAt: Date.now(),
      deviceName: eventInfo.deviceName,
      deviceType: PeripheralType.BLUETOOTH,
      deviceId: eventInfo.deviceId,
      action: eventInfo.action,
      decision: 'unknown',
      result: LogEventResult.SUCCESS,
      source: 'runtime_event',
      summary: eventInfo.action === 'connect' ? '蓝牙设备已连接' : '蓝牙设备已断开',
      rawEventName: data.event,
      rawAction: eventInfo.action,
      rawPayload: eventInfo.rawPayload,
      detail: `aclState=${eventInfo.stateLabel}, reason=${eventInfo.reasonLabel}`,
      effectivePolicyLabel: '--',
      matchedPolicyKind: 'bluetooth_connection_event'
    }, false, false)
    hilog.info(
      DOMAIN,
      TAG,
      `bluetooth acl event persisted: action=${eventInfo.action}, deviceId=${PeripheralRuntimeEventService.maskBluetoothIdentifier(eventInfo.rawDeviceId)}, state=${eventInfo.stateLabel}, reason=${eventInfo.reasonLabel}`
    )
  }

  private static async resolveBluetoothAclEventInfo(
    data: commonEventManager.CommonEventData
  ): Promise<BluetoothAclEventInfo | null> {
    const payloads = PeripheralRuntimeEventService.collectPayloadSources(data)
    const rawDeviceId = PeripheralRuntimeEventService.resolveBluetoothDeviceId(payloads)
    if (rawDeviceId.length === 0) {
      hilog.warn(
        DOMAIN,
        TAG,
        `skip bluetooth acl event: deviceId missing, keys=${PeripheralRuntimeEventService.describePayloadKeys(payloads)}`
      )
      return null
    }
    const action = PeripheralRuntimeEventService.resolveBluetoothAclAction(payloads)
    const stateLabel = PeripheralRuntimeEventService.resolveBluetoothAclStateLabel(payloads)
    const reasonLabel = PeripheralRuntimeEventService.resolveBluetoothAclReasonLabel(payloads)
    const occurAt = PeripheralRuntimeEventService.resolveBluetoothOccurAt(payloads)
    const nameResolution = PeripheralRuntimeEventService.resolveBluetoothDeviceName(rawDeviceId, payloads)
    let rawPayload = ''
    try {
      rawPayload = JSON.stringify(data)
    } catch (_err) {
      rawPayload = ''
    }
    return {
      occurAt: Number.isFinite(occurAt) && occurAt > 0 ? occurAt : Date.now(),
      deviceId: PeripheralRuntimeEventService.normalizeBluetoothDeviceId(rawDeviceId),
      rawDeviceId: rawDeviceId,
      deviceName: nameResolution.name,
      action: action,
      stateLabel: stateLabel,
      reasonLabel: reasonLabel,
      rawPayload: rawPayload
    }
  }

  private static normalizeBluetoothDeviceId(deviceId: string): string {
    return formatBluetoothDeviceId(deviceId)
  }

  private static resolveBluetoothDeviceId(sources: EventPayloadRecord[]): string {
    return PeripheralRuntimeEventService.pickString(
      sources,
      ['deviceId', 'deviceid', 'deviceAddr', 'deviceAddress', 'address', 'addr', 'remoteAddr', 'remoteAddress', 'mac', 'macAddress']
    )
  }

  private static resolveBluetoothAclAction(sources: EventPayloadRecord[]): BluetoothAclAction {
    const stateLabel = PeripheralRuntimeEventService.resolveBluetoothAclStateLabel(sources).toUpperCase()
    if (stateLabel.includes('DISCONNECT')) {
      return 'disconnect'
    }
    if (stateLabel.includes('CONNECT')) {
      return 'connect'
    }

    const stateValue = PeripheralRuntimeEventService.pickNumber(
      sources,
      ['connectionstate', 'connectionState', 'aclState', 'aclstate', 'state', 'linkState', 'linkstate', 'status']
    )
    if (stateValue === 0) {
      return 'disconnect'
    }
    if (stateValue === 1) {
      return 'connect'
    }
    if (stateValue === 2) {
      return 'connect'
    }
    return 'unknown'
  }

  private static resolveBluetoothAclStateLabel(sources: EventPayloadRecord[]): string {
    const rawLabel = PeripheralRuntimeEventService.pickString(
      sources,
      [
        'stateName',
        'stateLabel',
        'aclStateName',
        'aclstateName',
        'state',
        'aclState',
        'aclstate',
        'connectionState',
        'connectionstate',
        'linkState',
        'linkstate',
        'status'
      ]
    )
    if (rawLabel.length > 0) {
      return rawLabel
    }
    const rawState = PeripheralRuntimeEventService.pickNumber(
      sources,
      ['connectionstate', 'connectionState', 'aclState', 'aclstate', 'state', 'linkState', 'linkstate', 'status']
    )
    if (Number.isFinite(rawState)) {
      switch (rawState) {
        case 0:
          return 'STATE_DISCONNECTED'
        case 1:
          return 'STATE_CONNECTED'
        case 2:
          return 'STATE_CONNECTED'
        case 3:
          return 'STATE_DISCONNECTING'
        default:
          return `${rawState}`
      }
    }
    return 'UNKNOWN'
  }

  private static resolveBluetoothAclReasonLabel(sources: EventPayloadRecord[]): string {
    const rawReason = PeripheralRuntimeEventService.pickString(
      sources,
      ['reason', 'reasonCode', 'reasoncode', 'cause', 'disconnectReason', 'disconnectreason']
    )
    if (rawReason.length > 0) {
      return rawReason
    }
    const reasonCode = PeripheralRuntimeEventService.pickNumber(
      sources,
      ['reason', 'reasonCode', 'reasoncode', 'cause', 'disconnectReason', 'disconnectreason']
    )
    if (Number.isFinite(reasonCode)) {
      return `${reasonCode}`
    }
    return '--'
  }

  private static resolveBluetoothOccurAt(sources: EventPayloadRecord[]): number {
    return PeripheralRuntimeEventService.pickNumber(sources, ['timestamp', 'time', 'occurAt'])
  }

  private static resolveBluetoothDeviceName(deviceId: string, sources: EventPayloadRecord[]): BluetoothNameResolution {
    const payloadName = PeripheralRuntimeEventService.pickString(
      sources,
      ['deviceName', 'name', 'remoteName', 'remoteDeviceName', 'alias', 'deviceAlias', 'aliasName']
    )
    if (payloadName.length > 0) {
      return {
        name: payloadName,
        source: 'event_payload'
      }
    }

    try {
      const remoteName = connection.getRemoteDeviceName(deviceId, true)?.trim() ?? ''
      hilog.info(
        DOMAIN,
        TAG,
        `getRemoteDeviceName success: deviceId=${PeripheralRuntimeEventService.maskBluetoothIdentifier(deviceId)}, hasName=${remoteName.length > 0}`
      )
      if (remoteName.length > 0) {
        return {
          name: remoteName,
          source: 'remote_name'
        }
      }
    } catch (err) {
      const error = err as BusinessError
      hilog.warn(
        DOMAIN,
        TAG,
        `getRemoteDeviceName failed: deviceId=${PeripheralRuntimeEventService.maskBluetoothIdentifier(deviceId)}, code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`
      )
    }

    return {
      name: FALLBACK_BLUETOOTH_NAME,
      source: 'fallback'
    }
  }

  private static logBluetoothBondState(data: connection.BondStateParam): void {
    hilog.info(
      DOMAIN,
      TAG,
      `bondStateChange: deviceId=${PeripheralRuntimeEventService.maskBluetoothIdentifier(data.deviceId)}, state=${data.state}, cause=${data.cause ?? -1}`
    )
  }

  private static isBluetoothRuntimeActive(): boolean {
    return PeripheralRuntimeEventService.bluetoothCurrentState === access.BluetoothState.STATE_ON ||
      PeripheralRuntimeEventService.bluetoothCurrentState === access.BluetoothState.STATE_BLE_ON
  }

  private static getSelfAccessTokenId(): number {
    const bundleInfo = bundleManager.getBundleInfoForSelfSync(
      bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
    )
    return bundleInfo.appInfo.accessTokenId
  }

  private static hasBluetoothRuntimePermission(): boolean {
    try {
      const atManager = abilityAccessCtrl.createAtManager()
      const grantStatus = atManager.checkAccessTokenSync(
        PeripheralRuntimeEventService.getSelfAccessTokenId(),
        BLUETOOTH_RUNTIME_PERMISSION
      )
      return grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED
    } catch (err) {
      const error = err as BusinessError
      hilog.warn(
        DOMAIN,
        TAG,
        `checkAccessTokenSync failed: code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`
      )
      return false
    }
  }

  private static async ensureBluetoothRuntimePermission(trigger: string): Promise<boolean> {
    const granted = PeripheralRuntimeEventService.hasBluetoothRuntimePermission()
    if (granted) {
      if (PeripheralRuntimeEventService.bluetoothPermissionBlocked) {
        hilog.info(DOMAIN, TAG, `bluetooth permission recovered: trigger=${trigger}`)
      }
      PeripheralRuntimeEventService.bluetoothPermissionBlocked = false
      return true
    }

    if (PeripheralRuntimeEventService.bluetoothPermissionPrompted) {
      PeripheralRuntimeEventService.enterBluetoothPermissionBlocked(`permission-not-granted:${trigger}`)
      hilog.info(DOMAIN, TAG, `skip bluetooth permission request: trigger=${trigger}, prompted=true`)
      return false
    }

    const context = PeripheralRuntimeEventService.context
    if (!context) {
      PeripheralRuntimeEventService.enterBluetoothPermissionBlocked(`permission-context-missing:${trigger}`)
      hilog.warn(DOMAIN, TAG, `bluetooth permission request skipped: trigger=${trigger}, context unavailable`)
      return false
    }

    if (PeripheralRuntimeEventService.bluetoothPermissionRequestInFlight) {
      hilog.info(DOMAIN, TAG, `bluetooth permission request already in flight: trigger=${trigger}`)
      return false
    }

    PeripheralRuntimeEventService.bluetoothPermissionRequestInFlight = true
    PeripheralRuntimeEventService.bluetoothPermissionPrompted = true
    try {
      const atManager = abilityAccessCtrl.createAtManager()
      const result = await atManager.requestPermissionsFromUser(context, [BLUETOOTH_RUNTIME_PERMISSION])
      const authResult = Array.isArray(result.authResults) && result.authResults.length > 0
        ? result.authResults[0]
        : abilityAccessCtrl.GrantStatus.PERMISSION_DENIED
      const requestGranted = authResult === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED ||
        PeripheralRuntimeEventService.hasBluetoothRuntimePermission()
      hilog.info(
        DOMAIN,
        TAG,
        `bluetooth permission request result: trigger=${trigger}, granted=${requestGranted}, authResult=${authResult}`
      )
      if (requestGranted) {
        PeripheralRuntimeEventService.bluetoothPermissionBlocked = false
        return true
      }
      PeripheralRuntimeEventService.enterBluetoothPermissionBlocked(`permission-request-denied:${trigger}`)
      return false
    } catch (err) {
      const error = err as BusinessError
      PeripheralRuntimeEventService.enterBluetoothPermissionBlocked(`permission-request-error:${trigger}`)
      hilog.warn(
        DOMAIN,
        TAG,
        `requestPermissionsFromUser failed: trigger=${trigger}, code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`
      )
      return false
    } finally {
      PeripheralRuntimeEventService.bluetoothPermissionRequestInFlight = false
    }
  }

  private static enterBluetoothPermissionBlocked(reason: string): void {
    PeripheralRuntimeEventService.bluetoothPermissionBlocked = true
    PeripheralRuntimeEventService.cleanupBluetoothAclSubscriber(reason)
    hilog.warn(DOMAIN, TAG, `bluetooth runtime paused: reason=${reason}`)
  }

  private static isBluetoothPermissionDeniedError(error: BusinessError): boolean {
    if (error.code === 201) {
      return true
    }
    const message = (error.message ?? '').toLowerCase()
    return message.includes('permission denied')
  }

  private static maskBluetoothIdentifier(deviceId: string): string {
    const segments = deviceId.trim().replace(/-/g, ':').split(':').filter((item: string) => item.length > 0)
    if (segments.length < 2) {
      return 'unknown'
    }
    return `**:**:**:**:${segments[segments.length - 2]}:${segments[segments.length - 1]}`
  }

  private static getBluetoothStateLabel(state: access.BluetoothState): string {
    switch (state) {
      case access.BluetoothState.STATE_OFF:
        return 'STATE_OFF'
      case access.BluetoothState.STATE_TURNING_ON:
        return 'STATE_TURNING_ON'
      case access.BluetoothState.STATE_ON:
        return 'STATE_ON'
      case access.BluetoothState.STATE_TURNING_OFF:
        return 'STATE_TURNING_OFF'
      case access.BluetoothState.STATE_BLE_TURNING_ON:
        return 'STATE_BLE_TURNING_ON'
      case access.BluetoothState.STATE_BLE_ON:
        return 'STATE_BLE_ON'
      case access.BluetoothState.STATE_BLE_TURNING_OFF:
        return 'STATE_BLE_TURNING_OFF'
      default:
        return `${state}`
    }
  }

  private static buildDegradedReason(usbReady: boolean, bluetoothReady: boolean): string | undefined {
    const reasons: string[] = []
    if (!usbReady) {
      reasons.push('usb_common_event_subscribe_failed')
    }
    if (!bluetoothReady) {
      reasons.push('bluetooth_acl_runtime_register_failed')
    }
    return reasons.length > 0 ? reasons.join('|') : undefined
  }

  private static collectPayloadSources(data: commonEventManager.CommonEventData): EventPayloadRecord[] {
    const sources: EventPayloadRecord[] = []
    const root = PeripheralRuntimeEventService.toRecord(data as Object)
    const parameters = PeripheralRuntimeEventService.toRecord(data.parameters as Object)
    const want = PeripheralRuntimeEventService.readObjectField(root, 'want')
    const wantParameters = PeripheralRuntimeEventService.readObjectField(want, 'parameters')
    const rootData = PeripheralRuntimeEventService.parseJsonObjectField(root, 'data')
    const wantData = PeripheralRuntimeEventService.parseJsonObjectField(want, 'data')

    PeripheralRuntimeEventService.pushRecord(sources, root)
    PeripheralRuntimeEventService.pushRecord(sources, parameters)
    PeripheralRuntimeEventService.pushRecord(sources, want)
    PeripheralRuntimeEventService.pushRecord(sources, wantParameters)
    PeripheralRuntimeEventService.pushRecord(sources, rootData)
    PeripheralRuntimeEventService.pushRecord(sources, wantData)

    PeripheralRuntimeEventService.pushRecord(sources, PeripheralRuntimeEventService.readDeviceField(root))
    PeripheralRuntimeEventService.pushRecord(sources, PeripheralRuntimeEventService.readDeviceField(parameters))
    PeripheralRuntimeEventService.pushRecord(sources, PeripheralRuntimeEventService.readDeviceField(want))
    PeripheralRuntimeEventService.pushRecord(sources, PeripheralRuntimeEventService.readDeviceField(wantParameters))
    PeripheralRuntimeEventService.pushRecord(sources, PeripheralRuntimeEventService.readDeviceField(rootData))
    PeripheralRuntimeEventService.pushRecord(sources, PeripheralRuntimeEventService.readDeviceField(wantData))
    return sources
  }

  private static describePayloadKeys(sources: EventPayloadRecord[]): string {
    const keys = new Set<string>()
    sources.forEach((source: EventPayloadRecord) => {
      Object.keys(source).forEach((key: string) => {
        if (key.trim().length > 0) {
          keys.add(key)
        }
      })
    })
    return Array.from(keys).sort().join('|')
  }

  private static resolveVendorId(sources: EventPayloadRecord[]): number {
    return PeripheralRuntimeEventService.pickNumber(sources, ['vendorId', 'vid', 'vendor_id'])
  }

  private static resolveProductId(sources: EventPayloadRecord[]): number {
    return PeripheralRuntimeEventService.pickNumber(sources, ['productId', 'pid', 'product_id'])
  }

  private static resolveOccurAt(sources: EventPayloadRecord[]): number {
    return PeripheralRuntimeEventService.pickNumber(sources, ['timestamp', 'time', 'occurAt'])
  }

  private static resolveRawDeviceName(sources: EventPayloadRecord[]): string {
    return PeripheralRuntimeEventService.pickString(
      sources,
      ['deviceName', 'name', 'productName', 'product', 'manufacturerName']
    )
  }

  private static resolveProductName(sources: EventPayloadRecord[]): string {
    return PeripheralRuntimeEventService.pickString(sources, ['productName', 'product', 'deviceName', 'name'])
  }

  private static resolveManufacturerName(sources: EventPayloadRecord[]): string {
    return PeripheralRuntimeEventService.pickString(sources, ['manufacturerName', 'manufacturer', 'vendorName'])
  }

  private static resolveBaseClass(sources: EventPayloadRecord[]): number {
    return PeripheralRuntimeEventService.pickNumber(sources, ['baseClass', 'classCode', 'deviceClass', 'clazz'])
  }

  private static resolveSubClass(sources: EventPayloadRecord[]): number {
    return PeripheralRuntimeEventService.pickNumber(sources, ['subClass', 'subclass', 'usbSubClass'])
  }

  private static resolveProtocol(sources: EventPayloadRecord[]): number {
    return PeripheralRuntimeEventService.pickNumber(sources, ['protocol', 'usbProtocol'])
  }

  private static resolveDetail(sources: EventPayloadRecord[], manufacturerName: string): string {
    return PeripheralRuntimeEventService.pickString(sources, ['detail', 'message', 'description']) ||
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
    return PeripheralRuntimeEventService.toRecord(source[key])
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
      return PeripheralRuntimeEventService.toRecord(JSON.parse(normalized) as Object)
    } catch (_err) {
      return undefined
    }
  }

  private static readDeviceField(source: EventPayloadRecord | undefined): EventPayloadRecord | undefined {
    if (source === undefined) {
      return undefined
    }
    return PeripheralRuntimeEventService.readObjectField(source, 'device') ||
      PeripheralRuntimeEventService.readObjectField(source, 'remoteDevice') ||
      PeripheralRuntimeEventService.readObjectField(source, 'remote_device') ||
      PeripheralRuntimeEventService.readObjectField(source, 'bluetoothDevice') ||
      PeripheralRuntimeEventService.readObjectField(source, 'usbDevice') ||
      PeripheralRuntimeEventService.readObjectField(source, 'usb_device')
  }

  private static toRecordArray(value: Object | undefined | null): EventPayloadRecord[] {
    if (!Array.isArray(value)) {
      return []
    }
    const result: EventPayloadRecord[] = []
    for (const item of value as Object[]) {
      const record = PeripheralRuntimeEventService.toRecord(item)
      if (record) {
        result.push(record)
      }
    }
    return result
  }

}

