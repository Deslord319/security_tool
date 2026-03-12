import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import {
  LogEventResult,
  PeripheralTraceRecord,
  PeripheralType,
  formatUsbDeviceId,
  inferPeripheralTypeFromBaseClass
} from '../models/DataModels'
import { PeripheralTraceRepository } from './PeripheralTraceRepository'

const TAG = 'PeripheralRuntimeEvent'
const DOMAIN = 0x000A

interface GenericEmitter {
  on?: (eventName: string, callback: (event: Object) => void) => void
  off?: (eventName: string, callback: (event: Object) => void) => void
}

interface PeripheralRuntimeCapabilities {
  usbRuntimeEvents: boolean
  btRuntimeEvents: boolean
  degradedReason?: string
}

interface PeripheralRuntimeStatus {
  running: boolean
  capabilities: PeripheralRuntimeCapabilities
}

interface SubscriptionItem {
  emitter: GenericEmitter
  eventName: string
  callback: (event: Object) => void
}

export class PeripheralRuntimeEventService {
  private static context: common.UIAbilityContext | null = null
  private static initialized: boolean = false
  private static running: boolean = false
  private static subscriptions: SubscriptionItem[] = []
  private static capabilities: PeripheralRuntimeCapabilities = {
    usbRuntimeEvents: false,
    btRuntimeEvents: false,
    degradedReason: 'not_started'
  }
  private static lastSeenByKey: Map<string, number> = new Map()

  private static readonly USB_ATTACH_EVENTS: string[] = [
    'usbDeviceAttach',
    'usbDeviceAttached',
    'deviceAttach',
    'deviceAdded'
  ]

  private static readonly USB_DETACH_EVENTS: string[] = [
    'usbDeviceDetach',
    'usbDeviceDetached',
    'deviceDetach',
    'deviceRemoved'
  ]

  private static readonly BT_CONNECT_EVENTS: string[] = [
    'deviceConnect',
    'deviceConnected',
    'bluetoothDeviceConnected'
  ]

  private static readonly BT_DISCONNECT_EVENTS: string[] = [
    'deviceDisconnect',
    'deviceDisconnected',
    'bluetoothDeviceDisconnected'
  ]

  static async init(context: common.UIAbilityContext): Promise<boolean> {
    PeripheralRuntimeEventService.context = context
    let traceInited = await PeripheralTraceRepository.init(context)
    PeripheralRuntimeEventService.initialized = traceInited
    if (!traceInited) {
      PeripheralRuntimeEventService.capabilities = {
        usbRuntimeEvents: false,
        btRuntimeEvents: false,
        degradedReason: 'trace_repo_init_failed'
      }
    }
    return traceInited
  }

  static async start(): Promise<boolean> {
    if (PeripheralRuntimeEventService.running) {
      return true
    }
    if (!PeripheralRuntimeEventService.initialized) {
      if (!PeripheralRuntimeEventService.context) {
        PeripheralRuntimeEventService.capabilities = {
          usbRuntimeEvents: false,
          btRuntimeEvents: false,
          degradedReason: 'not_initialized'
        }
        return false
      }
      let ok = await PeripheralRuntimeEventService.init(PeripheralRuntimeEventService.context)
      if (!ok) {
        return false
      }
    }

    PeripheralRuntimeEventService.unsubscribeAll()
    let usbReady = PeripheralRuntimeEventService.registerUsbRuntimeEvents()
    let btReady = PeripheralRuntimeEventService.registerBtRuntimeEvents()
    PeripheralRuntimeEventService.capabilities = {
      usbRuntimeEvents: usbReady,
      btRuntimeEvents: btReady,
      degradedReason: usbReady || btReady ? undefined : 'runtime_not_implemented'
    }
    PeripheralRuntimeEventService.running = usbReady || btReady
    hilog.info(
      DOMAIN,
      TAG,
      `start complete, running=${PeripheralRuntimeEventService.running}, usb=${usbReady}, bt=${btReady}`
    )
    return PeripheralRuntimeEventService.running
  }

  static stop(): void {
    PeripheralRuntimeEventService.running = false
    PeripheralRuntimeEventService.unsubscribeAll()
  }

  static getStatus(): PeripheralRuntimeStatus {
    let status: PeripheralRuntimeStatus = {
      running: PeripheralRuntimeEventService.running,
      capabilities: PeripheralRuntimeEventService.capabilities
    }
    return status
  }

  static probeCapabilities(): PeripheralRuntimeCapabilities {
    let snapshot: PeripheralRuntimeCapabilities = {
      usbRuntimeEvents: PeripheralRuntimeEventService.capabilities.usbRuntimeEvents,
      btRuntimeEvents: PeripheralRuntimeEventService.capabilities.btRuntimeEvents,
      degradedReason: PeripheralRuntimeEventService.capabilities.degradedReason
    }
    return snapshot
  }

  private static registerUsbRuntimeEvents(): boolean {
    // ArkTS in this target does not allow namespace-as-object dynamic binding.
    // Keep service in degraded mode until a typed event API is available.
    return false
  }

  private static registerBtRuntimeEvents(): boolean {
    return false
  }

  private static tryRegisterAny(
    emitter: GenericEmitter,
    eventNames: string[],
    callback: (event: Object) => void
  ): boolean {
    if (!emitter.on) {
      return false
    }
    for (let eventName of eventNames) {
      try {
        emitter.on(eventName, callback)
        PeripheralRuntimeEventService.subscriptions.push({
          emitter: emitter,
          eventName: eventName,
          callback: callback
        })
        hilog.info(DOMAIN, TAG, `subscribed runtime event: ${eventName}`)
        return true
      } catch (_err) {
        // Try next candidate name.
      }
    }
    return false
  }

  private static unsubscribeAll(): void {
    for (let item of PeripheralRuntimeEventService.subscriptions) {
      try {
        if (item.emitter.off) {
          item.emitter.off(item.eventName, item.callback)
        }
      } catch (_err) {
        // ignore
      }
    }
    PeripheralRuntimeEventService.subscriptions = []
  }

  private static consumeUsbRuntimeEvent(event: Object, action: 'connect' | 'disconnect'): void {
    let map = event as Record<string, Object>
    let vendorId = PeripheralRuntimeEventService.pickNumber(map, ['vendorId', 'vid', 'vendor_id'])
    let productId = PeripheralRuntimeEventService.pickNumber(map, ['productId', 'pid', 'product_id'])
    let baseClass = PeripheralRuntimeEventService.pickNumber(map, ['baseClass', 'classCode', 'deviceClass'])
    let occurAt = PeripheralRuntimeEventService.pickNumber(map, ['timestamp', 'time', 'occurAt']) || Date.now()
    if (!Number.isFinite(vendorId)) {
      vendorId = 0
    }
    if (!Number.isFinite(productId)) {
      productId = 0
    }
    let deviceId = formatUsbDeviceId(vendorId, productId)
    let deviceType = Number.isFinite(baseClass) ? inferPeripheralTypeFromBaseClass(baseClass) : PeripheralType.USB_OTHER
    let deviceName = PeripheralRuntimeEventService.pickString(map, ['deviceName', 'name', 'productName']) || `USB Device (${deviceId})`
    let detail = PeripheralRuntimeEventService.pickString(map, ['detail', 'message', 'description']) || ''
    let rawPayload = PeripheralRuntimeEventService.safeJson(event)
    PeripheralRuntimeEventService.persistRuntimeRecord({
      recordId: `runtime_usb_${occurAt}_${Math.random().toString(36).substring(2, 7)}`,
      occurAt: occurAt,
      collectAt: Date.now(),
      deviceName: deviceName,
      deviceType: deviceType,
      deviceId: deviceId,
      action: action,
      decision: 'unknown',
      result: LogEventResult.SUCCESS,
      source: 'runtime_event',
      summary: action === 'connect' ? 'USB runtime connect' : 'USB runtime disconnect',
      detail: detail,
      rawPayload: rawPayload
    })
  }

  private static consumeBtRuntimeEvent(event: Object, action: 'connect' | 'disconnect'): void {
    let map = event as Record<string, Object>
    let rawMac = PeripheralRuntimeEventService.pickString(map, ['macAddress', 'mac', 'address', 'deviceId'])
    let mac = PeripheralRuntimeEventService.normalizeMac(rawMac)
    let occurAt = PeripheralRuntimeEventService.pickNumber(map, ['timestamp', 'time', 'occurAt']) || Date.now()
    let deviceId = mac.length > 0 ? `MAC: ${mac}` : 'MAC: UNKNOWN'
    let deviceName = PeripheralRuntimeEventService.pickString(map, ['deviceName', 'name']) || `Bluetooth Device (${mac || 'UNKNOWN'})`
    let detail = PeripheralRuntimeEventService.pickString(map, ['detail', 'message', 'description']) || ''
    let rawPayload = PeripheralRuntimeEventService.safeJson(event)
    PeripheralRuntimeEventService.persistRuntimeRecord({
      recordId: `runtime_bt_${occurAt}_${Math.random().toString(36).substring(2, 7)}`,
      occurAt: occurAt,
      collectAt: Date.now(),
      deviceName: deviceName,
      deviceType: PeripheralType.BLUETOOTH,
      deviceId: deviceId,
      action: action,
      decision: 'unknown',
      result: LogEventResult.SUCCESS,
      source: 'runtime_event',
      summary: action === 'connect' ? 'Bluetooth runtime connect' : 'Bluetooth runtime disconnect',
      detail: detail,
      rawPayload: rawPayload
    })
  }

  private static persistRuntimeRecord(record: PeripheralTraceRecord): void {
    let now = Date.now()
    let dedupeKey = `${record.deviceId}|${record.action}|${record.source}`
    let lastSeen = PeripheralRuntimeEventService.lastSeenByKey.get(dedupeKey) || 0
    if (now - lastSeen < 1500) {
      return
    }
    PeripheralRuntimeEventService.lastSeenByKey.set(dedupeKey, now)
    PeripheralTraceRepository.append(record).then((ok: boolean) => {
      if (!ok) {
        hilog.warn(DOMAIN, TAG, 'persistRuntimeRecord failed')
      }
    }).catch((err: Object) => {
      hilog.warn(DOMAIN, TAG, `persistRuntimeRecord exception: ${JSON.stringify(err)}`)
    })
  }

  private static pickNumber(map: Record<string, Object>, keys: string[]): number {
    for (let key of keys) {
      let value = map[key]
      if (typeof value === 'number' && Number.isFinite(value)) {
        return value
      }
      if (typeof value === 'string') {
        let parsed = Number(value)
        if (!Number.isNaN(parsed)) {
          return parsed
        }
      }
    }
    return NaN
  }

  private static pickString(map: Record<string, Object>, keys: string[]): string {
    for (let key of keys) {
      let value = map[key]
      if (typeof value === 'string' && value.trim().length > 0) {
        return value.trim()
      }
    }
    return ''
  }

  private static normalizeMac(value: string): string {
    if (!value) {
      return ''
    }
    return value.toUpperCase().replace(/-/g, ':').trim()
  }

  private static safeJson(value: Object): string {
    try {
      return JSON.stringify(value)
    } catch (_err) {
      return ''
    }
  }
}
