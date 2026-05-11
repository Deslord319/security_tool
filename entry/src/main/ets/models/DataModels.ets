import { generateRandomSuffix } from '../utils/ValuePicker'

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

export type EnterpriseAdminType = 'super' | 'byod'

export interface AdminActivationState {
  activated: boolean
  errorCode?: number
  errorMessage?: string
  enableCommand: string
  adminType: EnterpriseAdminType
}

export interface OperationResult<T = void> {
  success: boolean
  data?: T
  errorCode?: number
  errorMessage?: string
  userMessage?: string
  isAdminMissing?: boolean
  stage?: string
  suggestion?: string
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

// ==================== 设备 ID 解析工具函数 ====================

interface ParsedUsbId {
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

export interface PasswordComplexityConfig {
  minLength: number
  requireUppercase: boolean
  requireLowercase: boolean
  requireDigit: boolean
  requireSpecialChar: boolean
  validityPeriod?: number
}

export const PASSWORD_LENGTH_OPTIONS: number[] = [6, 8, 10, 12, 16, 20, 24]
export type PasswordValidityPreset = 'halfYear' | 'oneYear' | 'permanent'
export const PASSWORD_VALIDITY_PRESETS: PasswordValidityPreset[] = ['halfYear', 'oneYear', 'permanent']

export enum AuthMethod {
  PIN = 1,
  FINGERPRINT = 4
}

export interface ToolSettingsConfig {
  startupAuthEnabled: boolean
  authMethod: AuthMethod
}

export const DEFAULT_TOOL_SETTINGS: ToolSettingsConfig = {
  startupAuthEnabled: false,
  authMethod: AuthMethod.PIN
}

export const PREF_KEY_STARTUP_AUTH = 'startup_auth_enabled'
export const PREF_KEY_AUTH_METHOD = 'auth_method'
export const PREF_STORE_NAME_TOOL = 'tool_settings'

export enum LogEventType {
  CRASH = 0,
  FILE = 1,
  ACCOUNT = 2,
  PERMISSION = 3,
  POWER = 4,
  SYSTEM = 5,
  KERNEL = 6
}

export enum LogEventResult {
  SUCCESS = 0,
  BLOCKED = 1,
  FAILED = 2
}

export interface LogDetailTableRow {
  key: string
  label: string
  value: string
}

export interface LogEntry {
  id: string
  timestamp: number
  eventType: LogEventType
  detail: string
  processName?: string
  pid?: number
  uid?: number
  filePath?: string
  remoteAddr?: string
  sourceEventId?: number
  rawEventName?: string
  rawOutcome?: string
  rawAction?: string
  detailRows?: LogDetailTableRow[]
  result: LogEventResult
}

export interface LogStorageConfig {
  maxLocalEntries: number
  retentionDays: number
}

export interface LogStatistics {
  totalCount: number
  todayCount: number
  blockedCount: number
  byType: Map<LogEventType, number>
}

export interface ExportActionResult {
  success: boolean
  fileName?: string
  reason?: string
}

export const DEFAULT_LOG_STORAGE_CONFIG: LogStorageConfig = {
  maxLocalEntries: 20000,
  retentionDays: 30
}

export const ALL_LOG_EVENT_TYPES: LogEventType[] = [
  LogEventType.CRASH,
  LogEventType.FILE,
  LogEventType.ACCOUNT,
  LogEventType.PERMISSION,
  LogEventType.POWER,
  LogEventType.SYSTEM,
  LogEventType.KERNEL
]

export const LOG_RETENTION_OPTIONS: number[] = [7, 14, 30, 90, 180]

export const LOG_MAX_ENTRIES_OPTIONS: number[] = [5000, 10000, 20000, 50000, 100000]

export const PREF_KEY_LOG_MAX_ENTRIES = 'log_max_entries'
export const PREF_KEY_LOG_RETENTION_DAYS = 'log_retention_days'
export const PREF_STORE_NAME_LOG = 'log_settings'

export function generateLogEntryId(): string {
  return `log_${Date.now()}_${generateRandomSuffix(9)}`
}

export function normalizeLogEventResult(value: LogEventResult, fallback: LogEventResult = LogEventResult.FAILED): LogEventResult {
  if (value === LogEventResult.SUCCESS || value === LogEventResult.BLOCKED || value === LogEventResult.FAILED) {
    return value
  }
  return fallback
}

export function parseLogEventResult(rawValue: string, fallback: LogEventResult = LogEventResult.FAILED): LogEventResult {
  let numeric = Number(rawValue)
  if (numeric === LogEventResult.SUCCESS || numeric === LogEventResult.BLOCKED || numeric === LogEventResult.FAILED) {
    return numeric as LogEventResult
  }
  return fallback
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
