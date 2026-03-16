import { common } from '@kit.AbilityKit'
import { BusinessError, commonEventManager } from '@kit.BasicServicesKit'
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

interface PeripheralRuntimeCapabilities {
  usbRuntimeEvents: boolean
  degradedReason?: string
}

interface PeripheralRuntimeStatus {
  running: boolean
  capabilities: PeripheralRuntimeCapabilities
}

type UsbEventAction = 'connect' | 'disconnect'

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

  static async init(context: common.UIAbilityContext): Promise<boolean> {
    PeripheralRuntimeEventService.context = context
    let traceInited = await PeripheralTraceRepository.init(context)
    PeripheralRuntimeEventService.initialized = traceInited
    if (!traceInited) {
      PeripheralRuntimeEventService.capabilities = {
        usbRuntimeEvents: false,
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
          degradedReason: 'not_initialized'
        }
        return false
      }
      let ok = await PeripheralRuntimeEventService.init(PeripheralRuntimeEventService.context)
      if (!ok) {
        return false
      }
    }

    PeripheralRuntimeEventService.stop()
    let usbReady = await PeripheralRuntimeEventService.registerUsbRuntimeEvents()
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
    let subscriber = PeripheralRuntimeEventService.subscriber
    PeripheralRuntimeEventService.subscriber = null
    commonEventManager.unsubscribe(subscriber, (err?: BusinessError) => {
      if (err) {
        hilog.warn(DOMAIN, TAG, `unsubscribe failed: code=${err.code}, message=${err.message}`)
      }
    })
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
      let subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
        events: [
          commonEventManager.Support.COMMON_EVENT_USB_DEVICE_ATTACHED,
          commonEventManager.Support.COMMON_EVENT_USB_DEVICE_DETACHED
        ]
      }
      let subscriber = await PeripheralRuntimeEventService.createSubscriber(subscribeInfo)
      let ok = await PeripheralRuntimeEventService.subscribe(subscriber)
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
    let action = PeripheralRuntimeEventService.resolveAction(data.event)
    if (!action) {
      return
    }
    let payload = PeripheralRuntimeEventService.extractPayload(data)
    let vendorId = PeripheralRuntimeEventService.pickNumber(payload, ['vendorId', 'vid', 'vendor_id'])
    let productId = PeripheralRuntimeEventService.pickNumber(payload, ['productId', 'pid', 'product_id'])
    let baseClass = PeripheralRuntimeEventService.pickNumber(payload, ['baseClass', 'classCode', 'deviceClass'])
    let occurAt = PeripheralRuntimeEventService.pickNumber(payload, ['timestamp', 'time', 'occurAt']) || Date.now()
    let deviceId = formatUsbDeviceId(
      Number.isFinite(vendorId) ? vendorId : 0,
      Number.isFinite(productId) ? productId : 0
    )
    let deviceType = Number.isFinite(baseClass)
      ? inferPeripheralTypeFromBaseClass(baseClass)
      : PeripheralType.USB_OTHER
    let deviceName = PeripheralRuntimeEventService.pickString(payload, ['deviceName', 'name', 'productName']) ||
      `USB Device (${deviceId})`
    let detail = PeripheralRuntimeEventService.pickString(payload, ['detail', 'message', 'description']) || ''
    PeripheralRuntimeEventService.persistRuntimeRecord({
      recordId: `runtime_usb_${occurAt}_${Math.random().toString(36).substring(2, 8)}`,
      occurAt: occurAt,
      collectAt: Date.now(),
      deviceName: deviceName,
      deviceType: deviceType,
      deviceId: deviceId,
      action: action,
      decision: action === 'connect' ? 'allow' : 'unknown',
      result: LogEventResult.SUCCESS,
      source: 'runtime_event',
      summary: action === 'connect' ? 'USB 设备已连接' : 'USB 设备已断开',
      rawEventName: data.event,
      rawPayload: PeripheralRuntimeEventService.safeJson(data),
      detail: detail
    })
  }

  private static extractPayload(data: commonEventManager.CommonEventData): Record<string, Object> {
    if (data.parameters) {
      return data.parameters as Record<string, Object>
    }
    return {}
  }

  private static resolveAction(eventName: string): UsbEventAction | null {
    if (eventName === commonEventManager.Support.COMMON_EVENT_USB_DEVICE_ATTACHED) {
      return 'connect'
    }
    if (eventName === commonEventManager.Support.COMMON_EVENT_USB_DEVICE_DETACHED) {
      return 'disconnect'
    }
    return null
  }

  private static persistRuntimeRecord(record: PeripheralTraceRecord): void {
    let now = Date.now()
    let dedupeKey = `${record.deviceId}|${record.action}|${record.rawEventName || ''}`
    let lastSeen = PeripheralRuntimeEventService.lastSeenByKey.get(dedupeKey) || 0
    if (now - lastSeen < 1500) {
      return
    }
    PeripheralRuntimeEventService.lastSeenByKey.set(dedupeKey, now)
    PeripheralTraceRepository.append(record).then((ok: boolean) => {
      if (!ok) {
        hilog.warn(DOMAIN, TAG, `append runtime record failed, deviceId=${record.deviceId}`)
      }
    })
  }

  private static pickNumber(source: Record<string, Object>, keys: string[]): number {
    for (let key of keys) {
      let value = source[key]
      if (typeof value === 'number' && Number.isFinite(value)) {
        return value
      }
      if (typeof value === 'string') {
        let normalized = value.trim()
        if (normalized.length === 0) {
          continue
        }
        let radix = normalized.startsWith('0x') || normalized.startsWith('0X') ? 16 : 10
        let parsed = parseInt(normalized.replace(/^0x/i, ''), radix)
        if (Number.isFinite(parsed)) {
          return parsed
        }
      }
    }
    return Number.NaN
  }

  private static pickString(source: Record<string, Object>, keys: string[]): string {
    for (let key of keys) {
      let value = source[key]
      if (typeof value === 'string' && value.trim().length > 0) {
        return value.trim()
      }
    }
    return ''
  }

  private static safeJson(value: Object): string {
    try {
      return JSON.stringify(value)
    } catch (_err) {
      return ''
    }
  }
}
