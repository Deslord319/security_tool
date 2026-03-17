import { common } from '@kit.AbilityKit'
import { BusinessError, commonEventManager } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import {
  LogEventResult,
  PeripheralTraceRecord,
  PeripheralType,
  UsbStoragePolicy,
  formatUsbDeviceId,
  inferPeripheralTypeFromBaseClass
} from '../models/DataModels'
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

interface ResolvedUsbEventInfo {
  vendorId: number
  productId: number
  baseClass: number
  occurAt: number
  deviceName: string
  detail: string
  deviceId: string
  deviceType: PeripheralType
}

interface ResolvedNumberField {
  value: number
  sourceIndex: number
  key: string
  rawValue: string
}

interface ResolvedStringField {
  value: string
  sourceIndex: number
  key: string
  rawValue: string
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
    PeripheralRuntimeEventService.logUsbEventRawInput(data)
    let info = PeripheralRuntimeEventService.resolveUsbEventInfo(data)
    hilog.info(
      DOMAIN,
      TAG,
      `usb event parsed: event=${data.event}, name=${info.deviceName}, deviceId=${info.deviceId}, baseClass=${info.baseClass}`
    )
    PeripheralRuntimeEventService.persistRuntimeRecord({
      recordId: `runtime_usb_${info.occurAt}_${Math.random().toString(36).substring(2, 8)}`,
      occurAt: info.occurAt,
      collectAt: Date.now(),
      deviceName: info.deviceName,
      deviceType: info.deviceType,
      deviceId: info.deviceId,
      action: action,
      decision: action === 'connect' ? 'allow' : 'unknown',
      result: LogEventResult.SUCCESS,
      source: 'runtime_event',
      summary: action === 'connect' ? 'USB device connected' : 'USB device disconnected',
      rawEventName: data.event,
      rawPayload: PeripheralRuntimeEventService.safeJson(data),
      detail: info.detail,
      usbPolicy: PeripheralRuntimeEventService.resolveUsbPolicyForRecord(info.deviceType, action)
    })
  }

  private static resolveUsbPolicyForRecord(
    deviceType: PeripheralType,
    action: UsbEventAction
  ): UsbStoragePolicy | undefined {
    if (deviceType !== PeripheralType.USB_STORAGE) {
      return undefined
    }
    if (action === 'disconnect') {
      return PeripheralRuntimeEventService.readCurrentUsbStoragePolicy()
    }
    return PeripheralRuntimeEventService.readCurrentUsbStoragePolicy()
  }

  private static readCurrentUsbStoragePolicy(): UsbStoragePolicy {
    let result = PeripheralService.getUsbStoragePolicyWithResult()
    let policyValue = result.data as number | undefined
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

  private static resolveUsbEventInfo(data: commonEventManager.CommonEventData): ResolvedUsbEventInfo {
    let payloadSources = PeripheralRuntimeEventService.collectPayloadSources(data)
    PeripheralRuntimeEventService.logPayloadSources(payloadSources)

    let vendorIdField = PeripheralRuntimeEventService.pickNumberFieldFromSources(
      payloadSources,
      ['vendorId', 'vid', 'vendor_id']
    )
    PeripheralRuntimeEventService.logNumberFieldResolution('vendorId', ['vendorId', 'vid', 'vendor_id'], vendorIdField)

    let productIdField = PeripheralRuntimeEventService.pickNumberFieldFromSources(
      payloadSources,
      ['productId', 'pid', 'product_id']
    )
    PeripheralRuntimeEventService.logNumberFieldResolution(
      'productId',
      ['productId', 'pid', 'product_id'],
      productIdField
    )

    let occurAtField = PeripheralRuntimeEventService.pickNumberFieldFromSources(
      payloadSources,
      ['timestamp', 'time', 'occurAt']
    )
    PeripheralRuntimeEventService.logNumberFieldResolution('occurAt', ['timestamp', 'time', 'occurAt'], occurAtField)

    let vendorId = vendorIdField ? vendorIdField.value : Number.NaN
    let productId = productIdField ? productIdField.value : Number.NaN
    let occurAt = occurAtField ? occurAtField.value : Number.NaN
    if (!Number.isFinite(occurAt) || occurAt <= 0) {
      occurAt = Date.now()
    }

    let hasVidPid = Number.isFinite(vendorId) && Number.isFinite(productId)
    let deviceId = hasVidPid ? formatUsbDeviceId(vendorId, productId) : `UNKNOWN-USB-${occurAt}`
    let deviceNameField = PeripheralRuntimeEventService.pickStringFieldFromSources(
      payloadSources,
      ['deviceName', 'name', 'productName', 'product', 'manufacturerName']
    )
    PeripheralRuntimeEventService.logStringFieldResolution(
      'deviceName',
      ['deviceName', 'name', 'productName', 'product', 'manufacturerName'],
      deviceNameField
    )
    let productNameField = PeripheralRuntimeEventService.pickStringFieldFromSources(
      payloadSources,
      ['productName', 'product', 'deviceName', 'name']
    )
    PeripheralRuntimeEventService.logStringFieldResolution(
      'productName',
      ['productName', 'product', 'deviceName', 'name'],
      productNameField
    )
    let manufacturerNameField = PeripheralRuntimeEventService.pickStringFieldFromSources(
      payloadSources,
      ['manufacturerName', 'manufacturer', 'vendorName']
    )
    PeripheralRuntimeEventService.logStringFieldResolution(
      'manufacturerName',
      ['manufacturerName', 'manufacturer', 'vendorName'],
      manufacturerNameField
    )
    let manufacturerName = manufacturerNameField ? manufacturerNameField.value : ''
    let productName = productNameField ? productNameField.value : ''
    let deviceName = PeripheralRuntimeEventService.buildUsbDisplayName(manufacturerName, productName)
    if (deviceName.length === 0) {
      deviceName = deviceNameField ? deviceNameField.value : ''
    }
    if (deviceName.length === 0) {
      deviceName = hasVidPid ? 'USB device' : 'Unrecognized USB device'
    }

    let detailField = PeripheralRuntimeEventService.pickStringFieldFromSources(
      payloadSources,
      ['detail', 'message', 'description']
    )
    PeripheralRuntimeEventService.logStringFieldResolution(
      'detail',
      ['detail', 'message', 'description'],
      detailField
    )
    let detail = detailField ? detailField.value : ''
    if (detail.length === 0 && manufacturerName.length > 0) {
      detail = `manufacturer=${manufacturerName}`
    }

    let baseClassField = PeripheralRuntimeEventService.resolveUsbClassField(payloadSources)
    PeripheralRuntimeEventService.logNumberFieldResolution(
      'baseClass',
      ['baseClass', 'classCode', 'deviceClass', 'clazz', 'interfaces[].clazz'],
      baseClassField
    )
    let baseClass = baseClassField ? baseClassField.value : Number.NaN

    let resolvedInfo: ResolvedUsbEventInfo = {
      vendorId: vendorId,
      productId: productId,
      baseClass: baseClass,
      occurAt: occurAt,
      deviceName: deviceName,
      detail: detail,
      deviceId: deviceId,
      deviceType: Number.isFinite(baseClass)
        ? inferPeripheralTypeFromBaseClass(baseClass)
        : PeripheralType.USB_OTHER
    }

    PeripheralRuntimeEventService.logResolvedUsbEventInfo(
      resolvedInfo,
      deviceNameField === null,
      !hasVidPid,
      !Number.isFinite(baseClass)
    )
    return resolvedInfo
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

  private static collectPayloadSources(data: commonEventManager.CommonEventData): Record<string, Object>[] {
    let sources: Record<string, Object>[] = []
    let root = PeripheralRuntimeEventService.toRecord(data as Object)
    PeripheralRuntimeEventService.pushRecord(sources, root)
    PeripheralRuntimeEventService.pushRecord(sources, PeripheralRuntimeEventService.toRecord(data.parameters as Object))
    PeripheralRuntimeEventService.pushRecord(
      sources,
      PeripheralRuntimeEventService.parseJsonRecord(root ? root['data'] : undefined)
    )

    let want = PeripheralRuntimeEventService.readNestedRecord(root, ['want'])
    PeripheralRuntimeEventService.pushRecord(sources, want)
    PeripheralRuntimeEventService.pushRecord(sources, PeripheralRuntimeEventService.readNestedRecord(want, ['parameters']))
    PeripheralRuntimeEventService.pushRecord(
      sources,
      PeripheralRuntimeEventService.parseJsonRecord(want ? want['data'] : undefined)
    )

    for (let source of [...sources]) {
      PeripheralRuntimeEventService.pushRecord(
        sources,
        PeripheralRuntimeEventService.parseJsonRecord(source['data'])
      )
      PeripheralRuntimeEventService.pushRecord(
        sources,
        PeripheralRuntimeEventService.readNestedRecord(source, ['device'])
      )
      PeripheralRuntimeEventService.pushRecord(
        sources,
        PeripheralRuntimeEventService.readNestedRecord(source, ['usbDevice'])
      )
      PeripheralRuntimeEventService.pushRecord(
        sources,
        PeripheralRuntimeEventService.readNestedRecord(source, ['usb_device'])
      )
    }
    return sources
  }

  private static resolveUsbClassField(sources: Record<string, Object>[]): ResolvedNumberField | null {
    let topLevelClassField = PeripheralRuntimeEventService.pickNumberFieldFromSources(
      sources,
      ['baseClass', 'classCode', 'deviceClass', 'clazz']
    )
    if (topLevelClassField && topLevelClassField.value > 0) {
      return topLevelClassField
    }
    let interfaceClassField = PeripheralRuntimeEventService.pickInterfaceClassFieldFromSources(sources)
    if (interfaceClassField) {
      return interfaceClassField
    }
    return topLevelClassField
  }

  private static logUsbEventRawInput(data: commonEventManager.CommonEventData): void {
    let root = PeripheralRuntimeEventService.safeJson(data)
    let parameters = PeripheralRuntimeEventService.safeJson(data.parameters as Object)
    let rootRecord = PeripheralRuntimeEventService.toRecord(data as Object)
    let want = PeripheralRuntimeEventService.readNestedRecord(rootRecord, ['want'])
    let wantRecord = PeripheralRuntimeEventService.safeJson(want as Object)
    let wantParametersRecord = PeripheralRuntimeEventService.readNestedRecord(want, ['parameters'])
    let wantParameters = PeripheralRuntimeEventService.safeJson(wantParametersRecord as Object)
    hilog.info(DOMAIN, TAG, `usb event raw input: event=${data.event}, root=${root}`)
    hilog.info(DOMAIN, TAG, `usb event raw input: parameters=${parameters}`)
    hilog.info(DOMAIN, TAG, `usb event raw input: want=${wantRecord}`)
    hilog.info(DOMAIN, TAG, `usb event raw input: want.parameters=${wantParameters}`)
  }

  private static logPayloadSources(sources: Record<string, Object>[]): void {
    for (let index = 0; index < sources.length; index++) {
      hilog.info(
        DOMAIN,
        TAG,
        `usb payload source[${index}]=${PeripheralRuntimeEventService.safeJson(sources[index])}`
      )
    }
  }

  private static logNumberFieldResolution(
    fieldName: string,
    keys: string[],
    resolved: ResolvedNumberField | null
  ): void {
    if (!resolved) {
      hilog.info(DOMAIN, TAG, `usb field ${fieldName} miss: keys=${keys.join('|')}`)
      return
    }
    hilog.info(
      DOMAIN,
      TAG,
      `usb field ${fieldName} hit: source=${resolved.sourceIndex}, key=${resolved.key}, raw=${resolved.rawValue}, normalized=${resolved.value}`
    )
  }

  private static logStringFieldResolution(
    fieldName: string,
    keys: string[],
    resolved: ResolvedStringField | null
  ): void {
    if (!resolved) {
      hilog.info(DOMAIN, TAG, `usb field ${fieldName} miss: keys=${keys.join('|')}`)
      return
    }
    hilog.info(
      DOMAIN,
      TAG,
      `usb field ${fieldName} hit: source=${resolved.sourceIndex}, key=${resolved.key}, raw=${resolved.rawValue}, normalized=${resolved.value}`
    )
  }

  private static logResolvedUsbEventInfo(
    info: ResolvedUsbEventInfo,
    fallbackName: boolean,
    fallbackDeviceId: boolean,
    fallbackDeviceType: boolean
  ): void {
    hilog.info(
      DOMAIN,
      TAG,
      `usb resolved info: vendorId=${info.vendorId}, productId=${info.productId}, baseClass=${info.baseClass}, deviceName=${info.deviceName}, deviceId=${info.deviceId}, deviceType=${info.deviceType}, occurAt=${info.occurAt}, detail=${info.detail}`
    )
    hilog.info(
      DOMAIN,
      TAG,
      `usb resolved fallback: deviceName=${fallbackName}, deviceId=${fallbackDeviceId}, deviceType=${fallbackDeviceType}`
    )
  }

  private static pushRecord(target: Record<string, Object>[], value: Record<string, Object> | null): void {
    if (!value) {
      return
    }
    target.push(value)
  }

  private static toRecord(value: Object | undefined | null): Record<string, Object> | null {
    if (!value || typeof value !== 'object') {
      return null
    }
    return value as Record<string, Object>
  }

  private static readNestedRecord(
    source: Record<string, Object> | null,
    keys: string[]
  ): Record<string, Object> | null {
    if (!source) {
      return null
    }
    for (let key of keys) {
      let value = source[key]
      let record = PeripheralRuntimeEventService.toRecord(value)
      if (record) {
        return record
      }
    }
    return null
  }

  private static pickNumberFieldFromSources(
    sources: Record<string, Object>[],
    keys: string[]
  ): ResolvedNumberField | null {
    for (let index = 0; index < sources.length; index++) {
      let value = PeripheralRuntimeEventService.pickNumberField(sources[index], keys)
      if (value) {
        return {
          value: value.value,
          sourceIndex: index,
          key: value.key,
          rawValue: value.rawValue
        }
      }
    }
    return null
  }

  private static pickStringFieldFromSources(
    sources: Record<string, Object>[],
    keys: string[]
  ): ResolvedStringField | null {
    for (let index = 0; index < sources.length; index++) {
      let value = PeripheralRuntimeEventService.pickStringField(sources[index], keys)
      if (value) {
        return {
          value: value.value,
          sourceIndex: index,
          key: value.key,
          rawValue: value.rawValue
        }
      }
    }
    return null
  }

  private static pickNumberField(source: Record<string, Object>, keys: string[]): ResolvedNumberField | null {
    for (let key of keys) {
      let value = source[key]
      if (typeof value === 'number' && Number.isFinite(value)) {
        return {
          value: value,
          sourceIndex: -1,
          key: key,
          rawValue: `${value}`
        }
      }
      if (typeof value === 'string') {
        let normalized = value.trim()
        if (normalized.length === 0) {
          continue
        }
        let radix = normalized.startsWith('0x') || normalized.startsWith('0X') ? 16 : 10
        let parsed = parseInt(normalized.replace(/^0x/i, ''), radix)
        if (Number.isFinite(parsed)) {
          return {
            value: parsed,
            sourceIndex: -1,
            key: key,
            rawValue: normalized
          }
        }
      }
    }
    return null
  }

  private static pickStringField(source: Record<string, Object>, keys: string[]): ResolvedStringField | null {
    for (let key of keys) {
      let value = source[key]
      if (typeof value === 'string' && value.trim().length > 0) {
        return {
          value: value.trim(),
          sourceIndex: -1,
          key: key,
          rawValue: value
        }
      }
    }
    return null
  }

  private static buildUsbDisplayName(manufacturerName: string, productName: string): string {
    let manufacturer = manufacturerName.trim()
    let product = productName.trim()
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

  private static pickInterfaceClassFieldFromSources(
    sources: Record<string, Object>[]
  ): ResolvedNumberField | null {
    for (let index = 0; index < sources.length; index++) {
      let value = PeripheralRuntimeEventService.pickInterfaceClassField(sources[index])
      if (value) {
        return {
          value: value.value,
          sourceIndex: index,
          key: value.key,
          rawValue: value.rawValue
        }
      }
    }
    return null
  }

  private static pickInterfaceClassField(source: Record<string, Object>): ResolvedNumberField | null {
    let configs = PeripheralRuntimeEventService.toRecordArray(source['configs'])
    for (let configIndex = 0; configIndex < configs.length; configIndex++) {
      let interfaces = PeripheralRuntimeEventService.toRecordArray(configs[configIndex]['interfaces'])
      for (let interfaceIndex = 0; interfaceIndex < interfaces.length; interfaceIndex++) {
        let clazzField = PeripheralRuntimeEventService.pickNumberField(
          interfaces[interfaceIndex],
          ['clazz', 'baseClass', 'classCode', 'deviceClass']
        )
        if (clazzField && clazzField.value > 0) {
          return {
            value: clazzField.value,
            sourceIndex: -1,
            key: `configs[${configIndex}].interfaces[${interfaceIndex}].${clazzField.key}`,
            rawValue: clazzField.rawValue
          }
        }
      }
    }
    return null
  }

  private static parseJsonRecord(value: Object | undefined | null): Record<string, Object> | null {
    if (typeof value !== 'string') {
      return null
    }
    let normalized = value.trim()
    if (normalized.length === 0 || (!normalized.startsWith('{') && !normalized.startsWith('['))) {
      return null
    }
    try {
      let parsed = JSON.parse(normalized) as Object
      return PeripheralRuntimeEventService.toRecord(parsed)
    } catch (_err) {
      return null
    }
  }

  private static toRecordArray(value: Object | undefined | null): Record<string, Object>[] {
    if (!Array.isArray(value)) {
      return []
    }
    let result: Record<string, Object>[] = []
    let items = value as Object[]
    for (let item of items) {
      let record = PeripheralRuntimeEventService.toRecord(item as Object)
      if (record) {
        result.push(record)
      }
    }
    return result
  }

  private static safeJson(value: Object): string {
    try {
      return JSON.stringify(value)
    } catch (_err) {
      return ''
    }
  }
}
