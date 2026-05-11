import { LogEventResult } from './LogModels'

export enum PeripheralType {
  USB_STORAGE = 'usb_storage',
  USB_CAMERA = 'usb_camera',
  USB_PRINTER = 'usb_printer',
  USB_HID = 'usb_hid',
  USB_OTHER = 'usb_other',
  BLUETOOTH = 'bluetooth'
}

interface UsbPeripheralTypeMapping {
  type: PeripheralType
  baseClass: number | null
}

const USB_PERIPHERAL_TYPE_MAPPINGS: UsbPeripheralTypeMapping[] = [
  { type: PeripheralType.USB_STORAGE, baseClass: 0x08 },
  { type: PeripheralType.USB_CAMERA, baseClass: 0x0E },
  { type: PeripheralType.USB_PRINTER, baseClass: 0x07 },
  { type: PeripheralType.USB_HID, baseClass: 0x03 },
  { type: PeripheralType.USB_OTHER, baseClass: null }
]

export enum UsbStoragePolicy {
  READ_WRITE = 0,
  READ_ONLY = 1,
  DISABLED = 2
}

export type PeripheralRecordSource = 'runtime_event' | 'audit_event' | 'policy_snapshot'

export type PeripheralRecordAction = 'connect' | 'disconnect' | 'discover' | 'intercept' | 'unknown'

export type PeripheralRecordPolicyHit = 'allow' | 'deny' | 'unknown'

export type PeripheralMatchedPolicyKind =
  'usb_disabled' |
  'usb_storage_disabled' |
  'usb_storage_read_only' |
  'device_deny' |
  'bluetooth_connection_event' |
  'bluetooth_discovery' |
  'default_allow' |
  'disconnect_event' |
  'unknown'

export type PeripheralDevicePolicy = 'allow' | 'deny'

export interface PeripheralDevicePolicyRecord {
  deviceId: string
  policy: PeripheralDevicePolicy
  updatedAt: number
  deviceName?: string
  deviceType?: PeripheralType
}

export interface PeripheralConnectionRecord {
  id: string
  timestamp: number
  collectAt?: number
  deviceName: string
  deviceType: PeripheralType
  deviceId: string
  action: PeripheralRecordAction
  result: LogEventResult
  policyHit: PeripheralRecordPolicyHit
  source: PeripheralRecordSource
  summary: string
  correlationId?: string
  policyVersion?: string
  rawEventId?: number
  rawEventName?: string
  rawOutcome?: string
  rawAction?: string
  rawPayload?: string
  detail?: string
  processName?: string
  usbPolicy?: UsbStoragePolicy
  effectivePolicyLabel?: string
  matchedPolicyKind?: PeripheralMatchedPolicyKind
}

export interface PeripheralConnectionFilter {
  deviceTypes?: PeripheralType[]
  results?: LogEventResult[]
  sources?: PeripheralRecordSource[]
  startTime?: number
  endTime?: number
  keyword?: string
}

export interface PeripheralTraceRecord {
  recordId: string
  occurAt: number
  collectAt: number
  deviceName: string
  deviceType: PeripheralType
  deviceId: string
  action: PeripheralRecordAction
  decision: PeripheralRecordPolicyHit
  result: LogEventResult
  source: PeripheralRecordSource
  summary: string
  correlationId?: string
  policyVersion?: string
  rawEventId?: number
  rawEventName?: string
  rawOutcome?: string
  rawAction?: string
  rawPayload?: string
  detail?: string
  processName?: string
  usbPolicy?: UsbStoragePolicy
  effectivePolicyLabel?: string
  matchedPolicyKind?: PeripheralMatchedPolicyKind
}

export interface PeripheralTraceQuery {
  startTime?: number
  endTime?: number
  deviceId?: string
  keyword?: string
  deviceTypes?: PeripheralType[]
  actions?: PeripheralRecordAction[]
  decisions?: PeripheralRecordPolicyHit[]
  results?: LogEventResult[]
  sources?: PeripheralRecordSource[]
}

export interface PeripheralTraceStats {
  total: number
  connects: number
  disconnects: number
}

export interface PeripheralPolicyRecord {
  deviceName: string
  deviceType: PeripheralType
  deviceId: string
  lastSeenAt: number
  lastSeenLabel: string
  policyIndex: number
}

export function isUsbPeripheralType(type: PeripheralType): boolean {
  for (const item of USB_PERIPHERAL_TYPE_MAPPINGS) {
    if (item.type === type) {
      return true
    }
  }
  return false
}

export function getUsbPeripheralBaseClass(type: PeripheralType): number | null {
  for (const item of USB_PERIPHERAL_TYPE_MAPPINGS) {
    if (item.type === type) {
      return item.baseClass
    }
  }
  return null
}

export interface ParsedUsbId {
  vendorId: number
  productId: number
}

export function parseUsbDeviceId(deviceId: string): ParsedUsbId | null {
  let match = deviceId.match(/VID:([0-9A-Fa-f]+)\s+PID:([0-9A-Fa-f]+)/)
  if (!match) {
    return null
  }
  let result: ParsedUsbId = {
    vendorId: parseInt(match[1], 16),
    productId: parseInt(match[2], 16)
  }
  return result
}

export function formatUsbDeviceId(vendorId: number, productId: number): string {
  return `VID:${vendorId.toString(16).toUpperCase().padStart(4, '0')} PID:${productId.toString(16).toUpperCase().padStart(4, '0')}`
}

export function normalizeDeviceId(deviceId: string): string {
  let value = (deviceId || '').trim()
  if (value.length === 0) {
    return 'UNKNOWN'
  }
  return value.replace(/\s+/g, ' ').toUpperCase()
}

export function formatBluetoothDeviceId(deviceId: string): string {
  const normalized = deviceId.trim().replace(/-/g, ':').toUpperCase()
  return `MAC: ${normalized}`
}

export function inferPeripheralTypeFromBaseClass(baseClass: number): PeripheralType {
  for (const item of USB_PERIPHERAL_TYPE_MAPPINGS) {
    if (item.baseClass === baseClass) {
      return item.type
    }
  }
  return PeripheralType.USB_OTHER
}

export function normalizePeripheralAction(value: string | undefined): PeripheralRecordAction {
  if (value === 'connect' || value === 'disconnect' || value === 'discover' || value === 'intercept' || value === 'unknown') {
    return value
  }
  return 'unknown'
}

export function normalizePeripheralDecision(value: string | undefined): PeripheralRecordPolicyHit {
  if (value === 'allow' || value === 'deny' || value === 'unknown') {
    return value
  }
  return 'unknown'
}

export function normalizePeripheralSource(value: string | undefined): PeripheralRecordSource {
  if (value === 'runtime_event' || value === 'audit_event' || value === 'policy_snapshot') {
    return value
  }
  return 'audit_event'
}
