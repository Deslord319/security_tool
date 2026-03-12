import { hilog } from '@kit.PerformanceAnalysisKit'
import {
  LogEntry,
  LogEventResult,
  LogEventType,
  PeripheralConnectionFilter,
  PeripheralConnectionRecord,
  PeripheralRecordAction,
  PeripheralRecordPolicyHit,
  PeripheralTraceQuery,
  PeripheralTraceRecord,
  PeripheralType,
  formatUsbDeviceId
} from '../models/DataModels'
import { LogStorageService } from './LogStorageService'
import { PeripheralService } from './PeripheralService'
import { PeripheralTraceRepository } from './PeripheralTraceRepository'

const TAG = 'PeripheralConnectionRecordService'
const DOMAIN = 0x0008
const DEDUPE_WINDOW_MS = 1500
const CORRELATION_WINDOW_MS = 10000

interface UsbDeviceIdLike {
  vendorId: number
  productId: number
}

export class PeripheralConnectionRecordService {
  private static readonly USB_DEVICE_NAMES: Map<string, string> = new Map([
    ['2B7E_B5A2', 'ShineOptics FHD Camera'],
    ['0781_5583', 'SanDisk Ultra USB 3.0'],
    ['03F0_0C17', 'HP LaserJet Pro M404'],
    ['046D_C52B', 'Logitech Unifying Receiver'],
    ['8087_0026', 'Intel Wireless Bluetooth'],
    ['0BDA_8153', 'Realtek USB Ethernet']
  ])

  private static readonly BT_DEVICE_NAMES: Map<string, string> = new Map([
    ['AA:BB:CC:DD:EE:01', 'Logitech MX Keys']
  ])

  static queryRecords(filter?: PeripheralConnectionFilter): PeripheralConnectionRecord[] {
    try {
      let auditEntries = LogStorageService.queryEntries({
        eventTypes: [LogEventType.USB_ACCESS]
      })
      let runtimeQuery: PeripheralTraceQuery = {
        startTime: filter?.startTime,
        endTime: filter?.endTime,
        deviceTypes: filter?.deviceTypes,
        sources: ['runtime_event']
      }
      let runtimeRecords = PeripheralTraceRepository.query(runtimeQuery)
      let usbWhitelist = PeripheralService.getUsbWhitelistWithResult().data ?? []
      let btWhitelist = PeripheralService.getBluetoothWhitelistWithResult().data ?? []
      return PeripheralConnectionRecordService.buildRecords(
        auditEntries,
        usbWhitelist as UsbDeviceIdLike[],
        btWhitelist,
        filter,
        runtimeRecords
      )
    } catch (err) {
      hilog.error(DOMAIN, TAG, `queryRecords failed: ${JSON.stringify(err)}`)
      return []
    }
  }

  static buildRecords(
    auditEntries: LogEntry[],
    usbWhitelist: UsbDeviceIdLike[],
    btWhitelist: string[],
    filter?: PeripheralConnectionFilter,
    runtimeRecords?: PeripheralTraceRecord[]
  ): PeripheralConnectionRecord[] {
    let records: PeripheralConnectionRecord[] = []
    let snapshotSeenKeys: string[] = []

    for (let entry of auditEntries) {
      if (entry.eventType !== LogEventType.USB_ACCESS) {
        continue
      }
      let record = PeripheralConnectionRecordService.mapAuditEntry(entry)
      records.push(record)
      snapshotSeenKeys.push(PeripheralConnectionRecordService.normalizeDeviceKey(record.deviceId))
    }

    if (runtimeRecords) {
      for (let runtimeRecord of runtimeRecords) {
        let mapped = PeripheralConnectionRecordService.mapRuntimeRecord(runtimeRecord)
        records.push(mapped)
        snapshotSeenKeys.push(PeripheralConnectionRecordService.normalizeDeviceKey(mapped.deviceId))
      }
    }

    for (let usbId of usbWhitelist) {
      let snapshotRecord = PeripheralConnectionRecordService.buildUsbSnapshotRecord(usbId)
      let key = PeripheralConnectionRecordService.normalizeDeviceKey(snapshotRecord.deviceId)
      if (!snapshotSeenKeys.includes(key)) {
        records.push(snapshotRecord)
      }
    }

    for (let rawMac of btWhitelist) {
      let snapshotRecord = PeripheralConnectionRecordService.buildBtSnapshotRecord(rawMac)
      let key = PeripheralConnectionRecordService.normalizeDeviceKey(snapshotRecord.deviceId)
      if (!snapshotSeenKeys.includes(key)) {
        records.push(snapshotRecord)
      }
    }

    let deduped = PeripheralConnectionRecordService.dedupeRecords(records)
    PeripheralConnectionRecordService.correlateRecords(deduped)

    let filtered = PeripheralConnectionRecordService.applyFilter(deduped, filter)
    filtered.sort((a: PeripheralConnectionRecord, b: PeripheralConnectionRecord) => {
      if (a.timestamp === b.timestamp) {
        let left = PeripheralConnectionRecordService.getSourcePriority(a.source)
        let right = PeripheralConnectionRecordService.getSourcePriority(b.source)
        if (left === right) {
          return 0
        }
        return left - right
      }
      return b.timestamp - a.timestamp
    })
    return filtered
  }

  private static mapAuditEntry(entry: LogEntry): PeripheralConnectionRecord {
    let parsedUsb = PeripheralConnectionRecordService.extractUsbDeviceId(entry)
    let deviceId = parsedUsb ?
      formatUsbDeviceId(parsedUsb.vendorId, parsedUsb.productId) :
      PeripheralConnectionRecordService.extractFallbackDeviceId(entry)
    let deviceType = PeripheralConnectionRecordService.inferUsbType(entry)
    let action = PeripheralConnectionRecordService.mapAction(entry)
    let policyHit = PeripheralConnectionRecordService.mapPolicyHit(entry.result, action)
    let deviceName = PeripheralConnectionRecordService.inferUsbDeviceName(deviceType, parsedUsb, deviceId)

    return {
      id: `peripheral_audit_${entry.id}`,
      timestamp: entry.timestamp,
      collectAt: Date.now(),
      deviceName: deviceName,
      deviceType: deviceType,
      deviceId: deviceId,
      action: action,
      result: entry.result,
      policyHit: policyHit,
      source: 'audit_event',
      summary: PeripheralConnectionRecordService.buildSummary(action, policyHit),
      rawEventId: entry.sourceEventId,
      rawEventName: entry.rawEventName,
      rawOutcome: entry.rawOutcome,
      rawAction: entry.rawAction,
      detail: entry.detail,
      processName: entry.processName,
      rawPayload: entry.detail
    }
  }

  private static mapRuntimeRecord(record: PeripheralTraceRecord): PeripheralConnectionRecord {
    return {
      id: `peripheral_runtime_${record.recordId}`,
      timestamp: record.occurAt,
      collectAt: record.collectAt,
      deviceName: record.deviceName,
      deviceType: record.deviceType,
      deviceId: record.deviceId,
      action: record.action,
      result: record.result,
      policyHit: record.decision,
      source: 'runtime_event',
      summary: record.summary || PeripheralConnectionRecordService.buildSummary(record.action, record.decision),
      correlationId: record.correlationId,
      policyVersion: record.policyVersion,
      rawEventId: record.rawEventId,
      rawEventName: record.rawEventName,
      rawOutcome: record.rawOutcome,
      rawAction: record.rawAction,
      rawPayload: record.rawPayload,
      detail: record.detail,
      processName: record.processName
    }
  }

  private static buildUsbSnapshotRecord(usbId: UsbDeviceIdLike): PeripheralConnectionRecord {
    let deviceId = formatUsbDeviceId(usbId.vendorId, usbId.productId)
    let key = PeripheralConnectionRecordService.buildUsbKey(usbId.vendorId, usbId.productId)
    let knownName = PeripheralConnectionRecordService.USB_DEVICE_NAMES.get(key)

    return {
      id: `peripheral_snapshot_usb_${key}`,
      timestamp: 0,
      collectAt: Date.now(),
      deviceName: knownName ? knownName : `USB Device (${deviceId})`,
      deviceType: PeripheralType.USB_OTHER,
      deviceId: deviceId,
      action: 'unknown',
      result: LogEventResult.SUCCESS,
      policyHit: 'unknown',
      source: 'policy_snapshot',
      summary: '仅策略快照（非实时连接事件）'
    }
  }

  private static buildBtSnapshotRecord(rawMac: string): PeripheralConnectionRecord {
    let mac = PeripheralConnectionRecordService.normalizeMac(rawMac)
    let knownName = PeripheralConnectionRecordService.BT_DEVICE_NAMES.get(mac)
    let deviceId = `MAC: ${mac}`

    return {
      id: `peripheral_snapshot_bt_${mac}`,
      timestamp: 0,
      collectAt: Date.now(),
      deviceName: knownName ? knownName : `Bluetooth Device (${mac})`,
      deviceType: PeripheralType.BLUETOOTH,
      deviceId: deviceId,
      action: 'unknown',
      result: LogEventResult.SUCCESS,
      policyHit: 'unknown',
      source: 'policy_snapshot',
      summary: '仅策略快照（非实时连接事件）'
    }
  }

  private static dedupeRecords(records: PeripheralConnectionRecord[]): PeripheralConnectionRecord[] {
    let sorted = records.slice().sort((a: PeripheralConnectionRecord, b: PeripheralConnectionRecord) => {
      return b.timestamp - a.timestamp
    })
    let deduped: PeripheralConnectionRecord[] = []
    let lastSeenByKey: Map<string, number> = new Map()

    for (let record of sorted) {
      let timestamp = record.timestamp > 0 ? record.timestamp : 0
      let key = [
        record.source,
        record.action,
        PeripheralConnectionRecordService.normalizeDeviceKey(record.deviceId),
        (record.rawEventName || '').toLowerCase(),
        (record.rawOutcome || '').toLowerCase(),
        record.rawEventId !== undefined ? `${record.rawEventId}` : ''
      ].join('|')
      let lastSeen = lastSeenByKey.get(key)
      if (lastSeen !== undefined && timestamp > 0 && Math.abs(lastSeen - timestamp) <= DEDUPE_WINDOW_MS) {
        continue
      }
      if (timestamp > 0) {
        lastSeenByKey.set(key, timestamp)
      }
      deduped.push(record)
    }
    return deduped
  }

  private static correlateRecords(records: PeripheralConnectionRecord[]): void {
    let auditRecords = records.filter((record: PeripheralConnectionRecord) => record.source === 'audit_event')
    let runtimeRecords = records.filter((record: PeripheralConnectionRecord) => record.source === 'runtime_event')

    for (let runtime of runtimeRecords) {
      if (runtime.timestamp <= 0) {
        continue
      }
      let normalizedDevice = PeripheralConnectionRecordService.normalizeDeviceKey(runtime.deviceId)
      let nearest: PeripheralConnectionRecord | undefined = undefined
      let nearestGap = CORRELATION_WINDOW_MS + 1

      for (let audit of auditRecords) {
        if (audit.timestamp <= 0) {
          continue
        }
        let auditDevice = PeripheralConnectionRecordService.normalizeDeviceKey(audit.deviceId)
        if (auditDevice !== normalizedDevice) {
          continue
        }
        let gap = Math.abs(audit.timestamp - runtime.timestamp)
        if (gap < nearestGap && gap <= CORRELATION_WINDOW_MS) {
          nearest = audit
          nearestGap = gap
        }
      }

      if (nearest) {
        let correlationId = runtime.correlationId || nearest.correlationId ||
          `corr_${normalizedDevice}_${Math.min(runtime.timestamp, nearest.timestamp)}`
        runtime.correlationId = correlationId
        nearest.correlationId = correlationId
      }
    }
  }

  private static applyFilter(
    records: PeripheralConnectionRecord[],
    filter?: PeripheralConnectionFilter
  ): PeripheralConnectionRecord[] {
    if (!filter) {
      return records
    }

    if (
      filter.startTime !== undefined &&
      Number.isFinite(filter.startTime) &&
      filter.endTime !== undefined &&
      Number.isFinite(filter.endTime) &&
      filter.startTime > filter.endTime
    ) {
      return []
    }

    return records.filter((record: PeripheralConnectionRecord) => {
      if (filter.deviceTypes && filter.deviceTypes.length > 0) {
        if (!filter.deviceTypes.includes(record.deviceType)) {
          return false
        }
      }

      if (filter.results && filter.results.length > 0) {
        if (record.source === 'policy_snapshot') {
          return false
        }
        if (!filter.results.includes(record.result)) {
          return false
        }
      }

      if (filter.sources && filter.sources.length > 0) {
        if (!filter.sources.includes(record.source)) {
          return false
        }
      }

      if (
        filter.startTime !== undefined &&
        Number.isFinite(filter.startTime) &&
        record.timestamp > 0 &&
        record.timestamp < filter.startTime
      ) {
        return false
      }

      if (
        filter.endTime !== undefined &&
        Number.isFinite(filter.endTime) &&
        record.timestamp > 0 &&
        record.timestamp > filter.endTime
      ) {
        return false
      }

      if (filter.keyword && filter.keyword.length > 0) {
        let keyword = filter.keyword.toLowerCase()
        let target = `${record.deviceName} ${record.deviceId} ${record.summary} ${record.detail || ''} ${record.processName || ''}`.toLowerCase()
        if (!target.includes(keyword)) {
          return false
        }
      }

      return true
    })
  }

  private static getSourcePriority(source: string): number {
    if (source === 'runtime_event') {
      return 0
    }
    if (source === 'audit_event') {
      return 1
    }
    return 2
  }

  private static buildUsbKey(vendorId: number, productId: number): string {
    return `${vendorId.toString(16).toUpperCase().padStart(4, '0')}_${productId.toString(16).toUpperCase().padStart(4, '0')}`
  }

  private static normalizeMac(rawMac: string): string {
    return rawMac.toUpperCase().replace(/-/g, ':').trim()
  }

  private static normalizeDeviceKey(deviceId: string): string {
    return deviceId.replace(/\s+/g, '').toUpperCase()
  }

  private static mapAction(entry: LogEntry): PeripheralRecordAction {
    let signals = PeripheralConnectionRecordService.collectAuditSignals(entry)
    if (
      signals.includes('blocked') ||
      signals.includes('intercept') ||
      signals.includes('deny') ||
      signals.includes('reject') ||
      signals.includes('阻止') ||
      signals.includes('拦截') ||
      signals.includes('拒绝') ||
      signals.includes('禁止')
    ) {
      return 'intercept'
    }

    if (
      signals.includes('detach') ||
      signals.includes('detached') ||
      signals.includes('remove') ||
      signals.includes('removed') ||
      signals.includes('unmount') ||
      signals.includes('unmounted') ||
      signals.includes('eject') ||
      signals.includes('disconnect') ||
      signals.includes('unplug') ||
      signals.includes('unplugged') ||
      signals.includes('disconnected') ||
      signals.includes('拔出') ||
      signals.includes('移除') ||
      signals.includes('卸载') ||
      signals.includes('断开') ||
      signals.includes('弹出')
    ) {
      return 'disconnect'
    }

    if (
      signals.includes('attach') ||
      signals.includes('attached') ||
      signals.includes('insert') ||
      signals.includes('inserted') ||
      signals.includes('mount') ||
      signals.includes('mounted') ||
      signals.includes('connect') ||
      signals.includes('plug') ||
      signals.includes('plugged') ||
      signals.includes('connected') ||
      signals.includes('接入') ||
      signals.includes('插入') ||
      signals.includes('挂载') ||
      signals.includes('连接')
    ) {
      return 'connect'
    }

    if (entry.result === LogEventResult.BLOCKED) {
      return 'intercept'
    }
    return 'unknown'
  }

  private static mapPolicyHit(
    result: LogEventResult,
    action: PeripheralRecordAction
  ): PeripheralRecordPolicyHit {
    if (action === 'intercept' || result === LogEventResult.BLOCKED) {
      return 'deny'
    }
    if (action === 'disconnect') {
      return 'unknown'
    }
    if (action === 'connect') {
      return 'allow'
    }
    return 'unknown'
  }

  private static buildSummary(action: PeripheralRecordAction, policyHit: PeripheralRecordPolicyHit): string {
    if (policyHit === 'deny') {
      return action === 'intercept' ? '命中拦截策略' : '命中禁止策略'
    }
    if (policyHit === 'allow') {
      return action === 'connect' ? '命中允许策略并放行' : '命中允许策略'
    }
    if (action === 'disconnect') {
      return '设备已断开'
    }
    return '策略结果未知'
  }

  private static collectAuditSignals(entry: LogEntry): string {
    let parts: string[] = []
    if (entry.rawAction) {
      parts.push(entry.rawAction)
    }
    if (entry.rawOutcome) {
      parts.push(entry.rawOutcome)
    }
    if (entry.rawEventName) {
      parts.push(entry.rawEventName)
    }
    if (entry.sourceSubType !== undefined) {
      parts.push(`${entry.sourceSubType}`)
    }
    if (entry.detail) {
      parts.push(entry.detail)
    }
    return parts.join(' ').toLowerCase()
  }

  private static extractUsbDeviceId(entry: LogEntry): UsbDeviceIdLike | undefined {
    let rawText = `${entry.detail || ''} ${entry.rawEventName || ''} ${entry.rawOutcome || ''}`
    let match = rawText.match(/VID[:=\s]*([0-9A-Fa-f]{1,4})[\s,;|/\\-]*PID[:=\s]*([0-9A-Fa-f]{1,4})/i)
    if (!match) {
      return undefined
    }

    let vendorId = parseInt(match[1], 16)
    let productId = parseInt(match[2], 16)
    if (!Number.isFinite(vendorId) || !Number.isFinite(productId)) {
      return undefined
    }
    return {
      vendorId: vendorId,
      productId: productId
    }
  }

  private static extractFallbackDeviceId(entry: LogEntry): string {
    let rawText = `${entry.detail || ''} ${entry.rawEventName || ''}`
    if (rawText.length > 0) {
      let compact = rawText.replace(/\s+/g, ' ').trim()
      return `USB: ${compact.substring(0, Math.min(48, compact.length))}`
    }
    return 'USB: UNKNOWN'
  }

  private static inferUsbType(entry: LogEntry): PeripheralType {
    let rawText = `${entry.detail || ''} ${entry.rawEventName || ''}`.toLowerCase()
    if (rawText.includes('camera')) {
      return PeripheralType.USB_CAMERA
    }
    if (rawText.includes('printer')) {
      return PeripheralType.USB_PRINTER
    }
    if (rawText.includes('storage') || rawText.includes('disk') || rawText.includes('udisk')) {
      return PeripheralType.USB_STORAGE
    }
    return PeripheralType.USB_OTHER
  }

  private static inferUsbDeviceName(
    deviceType: PeripheralType,
    parsedUsb: UsbDeviceIdLike | undefined,
    fallbackId: string
  ): string {
    if (parsedUsb) {
      let key = PeripheralConnectionRecordService.buildUsbKey(parsedUsb.vendorId, parsedUsb.productId)
      let known = PeripheralConnectionRecordService.USB_DEVICE_NAMES.get(key)
      if (known) {
        return known
      }
    }

    if (deviceType === PeripheralType.USB_STORAGE) {
      return `USB Storage (${fallbackId})`
    }
    if (deviceType === PeripheralType.USB_CAMERA) {
      return `USB Camera (${fallbackId})`
    }
    if (deviceType === PeripheralType.USB_PRINTER) {
      return `USB Printer (${fallbackId})`
    }
    return `USB Device (${fallbackId})`
  }
}
