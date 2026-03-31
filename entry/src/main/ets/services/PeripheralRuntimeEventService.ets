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
const BLUETOOTH_DISCOVERY_WINDOW_MS = 30_000
const BLUETOOTH_DISCOVERY_PAUSE_MS = 5_000
const FALLBACK_BLUETOOTH_NAME = '未命名蓝牙设备'
const BLUETOOTH_DISCOVERY_PERMISSION: Permissions = 'ohos.permission.ACCESS_BLUETOOTH'

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
type BluetoothDiscoveryCallback = (data: Array<connection.DiscoveryResult>) => void
type BluetoothBondStateCallback = (data: connection.BondStateParam) => void

interface BluetoothNameResolution {
  name: string
  source: 'discovery_result' | 'remote_name' | 'fallback'
}

export class PeripheralRuntimeEventService {
  private static context: common.UIAbilityContext | null = null
  private static initialized: boolean = false
  private static running: boolean = false
  private static subscriber: commonEventManager.CommonEventSubscriber | null = null
  private static capabilities: PeripheralRuntimeCapabilities = {
    usbRuntimeEvents: false,
    bluetoothRuntimeEvents: false,
    degradedReason: 'not_started'
  }
  private static lastSeenByKey: Map<string, number> = new Map()
  private static nextListenerId: number = 1
  private static listeners: Map<number, (event: UsbRuntimeEvent) => void> = new Map()
  private static bluetoothStateListener: BluetoothStateCallback | undefined
  private static bluetoothDiscoveryListener: BluetoothDiscoveryCallback | undefined
  private static bluetoothBondStateListener: BluetoothBondStateCallback | undefined
  private static bluetoothLoopActive: boolean = false
  private static bluetoothWindowSeen: Set<string> = new Set()
  private static bluetoothScanTimerId: number = -1
  private static bluetoothPauseTimerId: number = -1
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
      await PeripheralRuntimeEventService.resumeBluetoothDiscoveryIfNeeded('start-called')
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
    const subscriber = PeripheralRuntimeEventService.subscriber
    PeripheralRuntimeEventService.subscriber = null
    if (subscriber) {
      commonEventManager.unsubscribe(subscriber, (err?: BusinessError) => {
        if (err) {
          hilog.warn(DOMAIN, TAG, `unsubscribe failed: code=${err.code}, message=${err.message}`)
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
            PeripheralRuntimeEventService.consumeUsbCommonEvent(data)
          })
          PeripheralRuntimeEventService.subscriber = subscriber
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
      PeripheralRuntimeEventService.bluetoothDiscoveryListener = (data: Array<connection.DiscoveryResult>): void => {
        void PeripheralRuntimeEventService.consumeBluetoothDiscoveryResult(data)
      }
      PeripheralRuntimeEventService.bluetoothBondStateListener = (data: connection.BondStateParam): void => {
        PeripheralRuntimeEventService.logBluetoothBondState(data)
      }

      access.on('stateChange', PeripheralRuntimeEventService.bluetoothStateListener)
      connection.on('discoveryResult', PeripheralRuntimeEventService.bluetoothDiscoveryListener)
      connection.on('bondStateChange', PeripheralRuntimeEventService.bluetoothBondStateListener)

      const currentState = access.getState()
      hilog.info(DOMAIN, TAG, `bluetooth state queried: state=${PeripheralRuntimeEventService.getBluetoothStateLabel(currentState)}`)
      PeripheralRuntimeEventService.handleBluetoothStateChange(currentState)
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
    const action = PeripheralRuntimeEventService.resolveAction(data.event)
    if (action === 'unknown') {
      hilog.warn(DOMAIN, TAG, `ignored unsupported usb event: ${data.event}`)
      return
    }
    const info = PeripheralRuntimeEventService.resolveUsbEventInfo(data)
    const evaluation = PeripheralRuntimeEventService.evaluateUsbEventPolicy(info, action)
    let rawPayload = ''
    try {
      rawPayload = JSON.stringify(data)
    } catch (_err) {
      rawPayload = ''
    }
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
    }, true)
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

  private static persistRuntimeRecord(record: PeripheralTraceRecord, notifyUsbListeners: boolean = false): void {
    const now = Date.now()
    const dedupeKey = `${record.deviceId}|${record.action}|${record.rawEventName || ''}`
    const lastSeen = PeripheralRuntimeEventService.lastSeenByKey.get(dedupeKey) || 0
    if (now - lastSeen < 1500) {
      return
    }
    PeripheralRuntimeEventService.lastSeenByKey.set(dedupeKey, now)
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

  private static cleanupBluetoothRuntimeEvents(): void {
    PeripheralRuntimeEventService.stopBluetoothDiscoveryLoop('service-stop')
    if (PeripheralRuntimeEventService.bluetoothStateListener) {
      try {
        access.off('stateChange', PeripheralRuntimeEventService.bluetoothStateListener)
      } catch (_err) {
      }
    }
    if (PeripheralRuntimeEventService.bluetoothDiscoveryListener) {
      try {
        connection.off('discoveryResult', PeripheralRuntimeEventService.bluetoothDiscoveryListener)
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
    PeripheralRuntimeEventService.bluetoothDiscoveryListener = undefined
    PeripheralRuntimeEventService.bluetoothBondStateListener = undefined
    PeripheralRuntimeEventService.bluetoothCurrentState = access.BluetoothState.STATE_OFF
  }

  private static handleBluetoothStateChange(state: access.BluetoothState): void {
    PeripheralRuntimeEventService.bluetoothCurrentState = state
    const stateLabel = PeripheralRuntimeEventService.getBluetoothStateLabel(state)
    hilog.info(DOMAIN, TAG, `bluetooth state change: state=${stateLabel}`)
    if (state === access.BluetoothState.STATE_ON || state === access.BluetoothState.STATE_BLE_ON) {
      void PeripheralRuntimeEventService.resumeBluetoothDiscoveryIfNeeded(`state=${stateLabel}`)
      return
    }
    PeripheralRuntimeEventService.stopBluetoothDiscoveryLoop(`state=${stateLabel}`)
  }

  private static async resumeBluetoothDiscoveryIfNeeded(trigger: string): Promise<void> {
    if (!PeripheralRuntimeEventService.running && !PeripheralRuntimeEventService.bluetoothStateListener) {
      return
    }
    if (!PeripheralRuntimeEventService.isBluetoothReadyForDiscovery()) {
      hilog.info(
        DOMAIN,
        TAG,
        `skip resumeBluetoothDiscoveryIfNeeded: trigger=${trigger}, state=${PeripheralRuntimeEventService.getBluetoothStateLabel(PeripheralRuntimeEventService.bluetoothCurrentState)}`
      )
      return
    }
    if (PeripheralRuntimeEventService.bluetoothLoopActive) {
      return
    }

    const permissionGranted = await PeripheralRuntimeEventService.ensureBluetoothDiscoveryPermission(trigger)
    if (!permissionGranted) {
      return
    }

    PeripheralRuntimeEventService.startBluetoothDiscoveryLoop(trigger)
  }

  private static startBluetoothDiscoveryLoop(trigger: string): void {
    if (PeripheralRuntimeEventService.bluetoothLoopActive) {
      return
    }
    PeripheralRuntimeEventService.bluetoothLoopActive = true
    hilog.info(
      DOMAIN,
      TAG,
      `bluetooth discovery loop start: trigger=${trigger}, windowMs=${BLUETOOTH_DISCOVERY_WINDOW_MS}, pauseMs=${BLUETOOTH_DISCOVERY_PAUSE_MS}`
    )
    PeripheralRuntimeEventService.runBluetoothDiscoveryWindow()
  }

  private static stopBluetoothDiscoveryLoop(reason: string): void {
    PeripheralRuntimeEventService.bluetoothLoopActive = false
    PeripheralRuntimeEventService.clearBluetoothTimers()
    PeripheralRuntimeEventService.resetBluetoothWindowDedupe()
    PeripheralRuntimeEventService.stopBluetoothDiscovery(reason)
    hilog.info(DOMAIN, TAG, `bluetooth discovery loop stop: reason=${reason}`)
  }

  private static clearBluetoothTimers(): void {
    if (PeripheralRuntimeEventService.bluetoothScanTimerId >= 0) {
      clearTimeout(PeripheralRuntimeEventService.bluetoothScanTimerId)
      PeripheralRuntimeEventService.bluetoothScanTimerId = -1
    }
    if (PeripheralRuntimeEventService.bluetoothPauseTimerId >= 0) {
      clearTimeout(PeripheralRuntimeEventService.bluetoothPauseTimerId)
      PeripheralRuntimeEventService.bluetoothPauseTimerId = -1
    }
  }

  private static runBluetoothDiscoveryWindow(): void {
    if (!PeripheralRuntimeEventService.bluetoothLoopActive) {
      return
    }
    if (PeripheralRuntimeEventService.bluetoothPermissionBlocked) {
      hilog.info(DOMAIN, TAG, 'skip bluetooth discovery window start: permission blocked')
      return
    }
    PeripheralRuntimeEventService.resetBluetoothWindowDedupe()
    hilog.info(DOMAIN, TAG, 'bluetooth discovery window start')
    PeripheralRuntimeEventService.startBluetoothDiscovery()
    PeripheralRuntimeEventService.bluetoothScanTimerId = setTimeout(() => {
      PeripheralRuntimeEventService.stopBluetoothDiscovery('window-finished')
      hilog.info(DOMAIN, TAG, 'bluetooth discovery window end')
      if (!PeripheralRuntimeEventService.bluetoothLoopActive) {
        return
      }
      PeripheralRuntimeEventService.bluetoothPauseTimerId = setTimeout(() => {
        PeripheralRuntimeEventService.runBluetoothDiscoveryWindow()
      }, BLUETOOTH_DISCOVERY_PAUSE_MS)
    }, BLUETOOTH_DISCOVERY_WINDOW_MS)
  }

  private static startBluetoothDiscovery(): void {
    if (!PeripheralRuntimeEventService.isBluetoothReadyForDiscovery()) {
      hilog.info(
        DOMAIN,
        TAG,
        `startBluetoothDiscovery skipped: state=${PeripheralRuntimeEventService.getBluetoothStateLabel(PeripheralRuntimeEventService.bluetoothCurrentState)}`
      )
      return
    }
    if (PeripheralRuntimeEventService.bluetoothPermissionBlocked) {
      hilog.info(DOMAIN, TAG, 'startBluetoothDiscovery skipped: permission blocked')
      return
    }
    try {
      const discovering = connection.isBluetoothDiscovering()
      if (discovering) {
        hilog.info(DOMAIN, TAG, 'startBluetoothDiscovery skipped: already discovering')
        return
      }
      connection.startBluetoothDiscovery()
      hilog.info(DOMAIN, TAG, 'startBluetoothDiscovery success')
    } catch (err) {
      const error = err as BusinessError
      if (PeripheralRuntimeEventService.isBluetoothPermissionDeniedError(error)) {
        PeripheralRuntimeEventService.enterBluetoothPermissionBlocked('start-discovery-denied')
      }
      hilog.warn(
        DOMAIN,
        TAG,
        `startBluetoothDiscovery failed: code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`
      )
    }
  }

  private static stopBluetoothDiscovery(reason: string): void {
    if (!PeripheralRuntimeEventService.isBluetoothReadyForDiscovery()) {
      hilog.info(
        DOMAIN,
        TAG,
        `stopBluetoothDiscovery skipped: reason=${reason}, state=${PeripheralRuntimeEventService.getBluetoothStateLabel(PeripheralRuntimeEventService.bluetoothCurrentState)}`
      )
      return
    }
    if (PeripheralRuntimeEventService.bluetoothPermissionBlocked) {
      hilog.info(DOMAIN, TAG, `stopBluetoothDiscovery skipped: reason=${reason}, permission blocked`)
      return
    }
    try {
      const discovering = connection.isBluetoothDiscovering()
      if (!discovering) {
        hilog.info(DOMAIN, TAG, `stopBluetoothDiscovery skipped: reason=${reason}, discovering=false`)
        return
      }
      connection.stopBluetoothDiscovery()
      hilog.info(DOMAIN, TAG, `stopBluetoothDiscovery success: reason=${reason}`)
    } catch (err) {
      const error = err as BusinessError
      if (PeripheralRuntimeEventService.isBluetoothPermissionDeniedError(error)) {
        PeripheralRuntimeEventService.enterBluetoothPermissionBlocked(`stop-discovery-denied:${reason}`)
      }
      hilog.warn(
        DOMAIN,
        TAG,
        `stopBluetoothDiscovery failed: reason=${reason}, code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`
      )
    }
  }

  private static async consumeBluetoothDiscoveryResult(data: Array<connection.DiscoveryResult>): Promise<void> {
    hilog.info(DOMAIN, TAG, `bluetooth discovery result received: count=${data.length}`)
    for (const item of data) {
      await PeripheralRuntimeEventService.persistBluetoothRuntimeRecord(item)
    }
  }

  private static async persistBluetoothRuntimeRecord(result: connection.DiscoveryResult): Promise<void> {
    const rawDeviceId = result.deviceId?.trim() ?? ''
    if (rawDeviceId.length === 0) {
      hilog.warn(DOMAIN, TAG, 'skip bluetooth discovery result: empty deviceId')
      return
    }

    const normalizedDeviceId = PeripheralRuntimeEventService.normalizeBluetoothDeviceId(rawDeviceId)
    const dedupeKey = normalizedDeviceId.toUpperCase()
    if (PeripheralRuntimeEventService.bluetoothWindowSeen.has(dedupeKey)) {
      hilog.info(
        DOMAIN,
        TAG,
        `bluetooth discovery dedupe hit: deviceId=${PeripheralRuntimeEventService.maskBluetoothIdentifier(rawDeviceId)}`
      )
      return
    }
    PeripheralRuntimeEventService.bluetoothWindowSeen.add(dedupeKey)

    const transport = PeripheralRuntimeEventService.resolveBluetoothTransport(rawDeviceId)
    const nameResolution = PeripheralRuntimeEventService.resolveBluetoothDeviceName(result)
    const persistentIdStatus = await PeripheralRuntimeEventService.tryAddPersistentBluetoothDeviceId(rawDeviceId)
    const detail = `transport=${transport}, rssi=${result.rssi}, nameSource=${nameResolution.source}, persistentId=${persistentIdStatus}`
    let rawPayload = ''
    try {
      rawPayload = JSON.stringify(result)
    } catch (_err) {
      rawPayload = ''
    }

    const record: PeripheralTraceRecord = {
      recordId: `runtime_bt_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`,
      occurAt: Date.now(),
      collectAt: Date.now(),
      deviceName: nameResolution.name,
      deviceType: PeripheralType.BLUETOOTH,
      deviceId: normalizedDeviceId,
      action: 'discover',
      decision: 'unknown',
      result: LogEventResult.SUCCESS,
      source: 'runtime_event',
      summary: '发现蓝牙设备',
      rawEventName: 'bluetooth.discoveryResult',
      rawAction: 'discover',
      rawPayload: rawPayload,
      detail: detail,
      effectivePolicyLabel: '--',
      matchedPolicyKind: 'bluetooth_discovery'
    }

    const appendOk = await PeripheralTraceRepository.append(record)
    hilog.info(
      DOMAIN,
      TAG,
      `bluetooth runtime record append: success=${appendOk}, deviceId=${PeripheralRuntimeEventService.maskBluetoothIdentifier(rawDeviceId)}, transport=${transport}`
    )
  }

  private static normalizeBluetoothDeviceId(deviceId: string): string {
    return formatBluetoothDeviceId(deviceId)
  }

  private static async tryAddPersistentBluetoothDeviceId(deviceId: string): Promise<string> {
    try {
      const validRandomId = access.isValidRandomDeviceId(deviceId)
      hilog.info(
        DOMAIN,
        TAG,
        `isValidRandomDeviceId success: deviceId=${PeripheralRuntimeEventService.maskBluetoothIdentifier(deviceId)}, valid=${validRandomId}`
      )
      if (!validRandomId) {
        return 'not_required'
      }
    } catch (err) {
      const error = err as BusinessError
      hilog.warn(
        DOMAIN,
        TAG,
        `isValidRandomDeviceId failed: deviceId=${PeripheralRuntimeEventService.maskBluetoothIdentifier(deviceId)}, code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`
      )
      return 'validation_failed'
    }

    try {
      await access.addPersistentDeviceId(deviceId)
      hilog.info(
        DOMAIN,
        TAG,
        `addPersistentDeviceId success: deviceId=${PeripheralRuntimeEventService.maskBluetoothIdentifier(deviceId)}`
      )
      return 'added'
    } catch (err) {
      const error = err as BusinessError
      hilog.warn(
        DOMAIN,
        TAG,
        `addPersistentDeviceId failed: deviceId=${PeripheralRuntimeEventService.maskBluetoothIdentifier(deviceId)}, code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`
      )
      return `failed:${error.code ?? -1}`
    }
  }

  private static resolveBluetoothDeviceName(result: connection.DiscoveryResult): BluetoothNameResolution {
    const scannedName = result.deviceName?.trim() ?? ''
    if (scannedName.length > 0) {
      return {
        name: scannedName,
        source: 'discovery_result'
      }
    }

    try {
      const remoteName = connection.getRemoteDeviceName(result.deviceId, true)?.trim() ?? ''
      hilog.info(
        DOMAIN,
        TAG,
        `getRemoteDeviceName success: deviceId=${PeripheralRuntimeEventService.maskBluetoothIdentifier(result.deviceId)}, hasName=${remoteName.length > 0}`
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
        `getRemoteDeviceName failed: deviceId=${PeripheralRuntimeEventService.maskBluetoothIdentifier(result.deviceId)}, code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`
      )
    }

    return {
      name: FALLBACK_BLUETOOTH_NAME,
      source: 'fallback'
    }
  }

  private static resolveBluetoothTransport(deviceId: string): string {
    try {
      const transport = connection.getRemoteDeviceTransport(deviceId)
      const label = PeripheralRuntimeEventService.getBluetoothTransportLabel(transport)
      hilog.info(
        DOMAIN,
        TAG,
        `getRemoteDeviceTransport success: deviceId=${PeripheralRuntimeEventService.maskBluetoothIdentifier(deviceId)}, transport=${label}`
      )
      return label
    } catch (err) {
      const error = err as BusinessError
      hilog.warn(
        DOMAIN,
        TAG,
        `getRemoteDeviceTransport failed: deviceId=${PeripheralRuntimeEventService.maskBluetoothIdentifier(deviceId)}, code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`
      )
      return 'UNKNOWN'
    }
  }

  private static logBluetoothBondState(data: connection.BondStateParam): void {
    hilog.info(
      DOMAIN,
      TAG,
      `bondStateChange: deviceId=${PeripheralRuntimeEventService.maskBluetoothIdentifier(data.deviceId)}, state=${data.state}, cause=${data.cause ?? -1}`
    )
  }

  private static resetBluetoothWindowDedupe(): void {
    PeripheralRuntimeEventService.bluetoothWindowSeen.clear()
  }

  private static isBluetoothReadyForDiscovery(): boolean {
    return PeripheralRuntimeEventService.bluetoothCurrentState === access.BluetoothState.STATE_ON ||
      PeripheralRuntimeEventService.bluetoothCurrentState === access.BluetoothState.STATE_BLE_ON
  }

  private static getSelfAccessTokenId(): number {
    const bundleInfo = bundleManager.getBundleInfoForSelfSync(
      bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
    )
    return bundleInfo.appInfo.accessTokenId
  }

  private static hasBluetoothDiscoveryPermission(): boolean {
    try {
      const atManager = abilityAccessCtrl.createAtManager()
      const grantStatus = atManager.checkAccessTokenSync(
        PeripheralRuntimeEventService.getSelfAccessTokenId(),
        BLUETOOTH_DISCOVERY_PERMISSION
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

  private static async ensureBluetoothDiscoveryPermission(trigger: string): Promise<boolean> {
    const granted = PeripheralRuntimeEventService.hasBluetoothDiscoveryPermission()
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
      const result = await atManager.requestPermissionsFromUser(context, [BLUETOOTH_DISCOVERY_PERMISSION])
      const authResult = Array.isArray(result.authResults) && result.authResults.length > 0
        ? result.authResults[0]
        : abilityAccessCtrl.GrantStatus.PERMISSION_DENIED
      const requestGranted = authResult === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED ||
        PeripheralRuntimeEventService.hasBluetoothDiscoveryPermission()
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
    PeripheralRuntimeEventService.bluetoothLoopActive = false
    PeripheralRuntimeEventService.clearBluetoothTimers()
    PeripheralRuntimeEventService.resetBluetoothWindowDedupe()
    hilog.warn(DOMAIN, TAG, `bluetooth discovery paused: reason=${reason}`)
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

  private static getBluetoothTransportLabel(transport: connection.BluetoothTransport): string {
    switch (transport) {
      case connection.BluetoothTransport.TRANSPORT_BR_EDR:
        return 'BR_EDR'
      case connection.BluetoothTransport.TRANSPORT_LE:
        return 'LE'
      case connection.BluetoothTransport.TRANSPORT_DUAL:
        return 'DUAL'
      case connection.BluetoothTransport.TRANSPORT_UNKNOWN:
      default:
        return 'UNKNOWN'
    }
  }

  private static buildDegradedReason(usbReady: boolean, bluetoothReady: boolean): string | undefined {
    const reasons: string[] = []
    if (!usbReady) {
      reasons.push('usb_common_event_subscribe_failed')
    }
    if (!bluetoothReady) {
      reasons.push('bluetooth_runtime_event_register_failed')
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

    PeripheralRuntimeEventService.pushRecord(sources, PeripheralRuntimeEventService.readUsbDeviceField(root))
    PeripheralRuntimeEventService.pushRecord(sources, PeripheralRuntimeEventService.readUsbDeviceField(parameters))
    PeripheralRuntimeEventService.pushRecord(sources, PeripheralRuntimeEventService.readUsbDeviceField(want))
    PeripheralRuntimeEventService.pushRecord(sources, PeripheralRuntimeEventService.readUsbDeviceField(wantParameters))
    PeripheralRuntimeEventService.pushRecord(sources, PeripheralRuntimeEventService.readUsbDeviceField(rootData))
    PeripheralRuntimeEventService.pushRecord(sources, PeripheralRuntimeEventService.readUsbDeviceField(wantData))
    return sources
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

  private static readUsbDeviceField(source: EventPayloadRecord | undefined): EventPayloadRecord | undefined {
    if (source === undefined) {
      return undefined
    }
    return PeripheralRuntimeEventService.readObjectField(source, 'device') ||
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

