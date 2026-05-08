import { LabelText, ResultText } from '../constants/StringCatalog'
import { DeviceTypeLabels, PeripheralRecordActionPresentationStrings, PeripheralSourcePresentationStrings } from '../constants/modules/PeripheralStrings'
import { LogEventPresentationStrings, LogResultPresentationStrings } from '../constants/modules/LogManageStrings'
import { IdentityAuthStrings } from '../constants/modules/IdentityStrings'
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

export function getPeripheralTypeLabel(type: PeripheralType): string {
  switch (type) {
    case PeripheralType.USB_STORAGE:
      return DeviceTypeLabels.USB_STORAGE
    case PeripheralType.USB_CAMERA:
      return DeviceTypeLabels.USB_CAMERA
    case PeripheralType.USB_PRINTER:
      return DeviceTypeLabels.USB_PRINTER
    case PeripheralType.USB_HID:
      return DeviceTypeLabels.USB_HID
    case PeripheralType.USB_OTHER:
      return DeviceTypeLabels.USB_OTHER
    case PeripheralType.BLUETOOTH:
      return DeviceTypeLabels.BLUETOOTH
    default:
      return LabelText.UNKNOWN
  }
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

export function getPeripheralRecordSourceLabel(source: PeripheralRecordSource): string {
  switch (source) {
    case 'runtime_event':
      return PeripheralSourcePresentationStrings.RUNTIME_EVENT
    case 'audit_event':
      return PeripheralSourcePresentationStrings.AUDIT_EVENT
    case 'policy_snapshot':
      return PeripheralSourcePresentationStrings.POLICY_SNAPSHOT
    default:
      return PeripheralSourcePresentationStrings.UNKNOWN
  }
}

export function getPeripheralRecordActionLabel(action: PeripheralRecordAction): string {
  switch (action) {
    case 'connect':
      return PeripheralRecordActionPresentationStrings.CONNECT
    case 'disconnect':
      return PeripheralRecordActionPresentationStrings.DISCONNECT
    case 'discover':
      return PeripheralRecordActionPresentationStrings.DISCOVER
    case 'intercept':
      return PeripheralRecordActionPresentationStrings.INTERCEPT
    default:
      return PeripheralRecordActionPresentationStrings.UNKNOWN
  }
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

export interface AuthMethodOption {
  label: string
  value: AuthMethod
}

export const AUTH_METHOD_OPTIONS: AuthMethodOption[] = [
  { label: IdentityAuthStrings.METHOD_PIN, value: AuthMethod.PIN } as AuthMethodOption,
  { label: IdentityAuthStrings.METHOD_FINGERPRINT, value: AuthMethod.FINGERPRINT } as AuthMethodOption
]

export const PREF_KEY_STARTUP_AUTH = 'startup_auth_enabled'
export const PREF_KEY_AUTH_METHOD = 'auth_method'
export const PREF_STORE_NAME_TOOL = 'tool_settings'

export enum LogEventType {
  CRASH = 0,
  FILE = 1,
  ACCOUNT = 2,
  PERMISSION = 3,
  POWER = 4
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

export interface LogSubscriptionConfig {
  subscribeAll: boolean
  subscribedTypes: LogEventType[]
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

interface LogEventTypeOption {
  label: string
  value: LogEventType
  icon?: Resource
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
  LogEventType.POWER
]

export const DEFAULT_SUBSCRIPTION_CONFIG: LogSubscriptionConfig = {
  subscribeAll: true,
  subscribedTypes: ALL_LOG_EVENT_TYPES
}

export const LOG_RETENTION_OPTIONS: number[] = [7, 14, 30, 90, 180]

export const LOG_MAX_ENTRIES_OPTIONS: number[] = [5000, 10000, 20000, 50000, 100000]

export const PREF_KEY_LOG_MAX_ENTRIES = 'log_max_entries'
export const PREF_KEY_LOG_RETENTION_DAYS = 'log_retention_days'
export const PREF_KEY_LOG_SUBSCRIBE_ALL = 'log_subscribe_all'
export const PREF_KEY_LOG_SUBSCRIBED_TYPES = 'log_subscribed_types'
export const PREF_STORE_NAME_LOG = 'log_settings'

export function getLogEventTypeLabel(type: LogEventType): string {
  switch (type) {
    case LogEventType.CRASH:
      return LogEventPresentationStrings.CRASH
    case LogEventType.FILE:
      return LogEventPresentationStrings.FILE
    case LogEventType.ACCOUNT:
      return LogEventPresentationStrings.ACCOUNT
    case LogEventType.PERMISSION:
      return LogEventPresentationStrings.PERMISSION
    case LogEventType.POWER:
      return LogEventPresentationStrings.POWER
    default:
      return LabelText.UNKNOWN
  }
}

export function getLogEventResultLabel(result: LogEventResult): string {
  switch (result) {
    case LogEventResult.SUCCESS:
      return ResultText.SUCCESS
    case LogEventResult.BLOCKED:
      return LogResultPresentationStrings.BLOCKED
    case LogEventResult.FAILED:
      return ResultText.FAILED
    default:
      return LabelText.UNKNOWN
  }
}

export function getLogEventResultColor(result: LogEventResult): string {
  switch (result) {
    case LogEventResult.SUCCESS:
      return '#4CAF50'
    case LogEventResult.BLOCKED:
      return '#FF9800'
    case LogEventResult.FAILED:
      return '#F44336'
    default:
      return '#9E9E9E'
  }
}

export const LOG_EVENT_TYPE_OPTIONS: LogEventTypeOption[] = [
  { label: LogEventPresentationStrings.CRASH, value: LogEventType.CRASH },
  { label: LogEventPresentationStrings.FILE, value: LogEventType.FILE },
  { label: LogEventPresentationStrings.ACCOUNT, value: LogEventType.ACCOUNT },
  { label: LogEventPresentationStrings.PERMISSION, value: LogEventType.PERMISSION },
  { label: LogEventPresentationStrings.POWER, value: LogEventType.POWER }
]

export function formatLogTimestamp(timestamp: number): string {
  let date = new Date(timestamp)
  let pad = (n: number): string => n.toString().padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
}

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

export function normalizePeripheralAction(action: PeripheralRecordAction): PeripheralRecordAction {
  if (action === 'connect' || action === 'disconnect' || action === 'discover' || action === 'intercept' || action === 'unknown') {
    return action
  }
  return 'unknown'
}

export function normalizePeripheralDecision(decision: PeripheralRecordPolicyHit): PeripheralRecordPolicyHit {
  if (decision === 'allow' || decision === 'deny' || decision === 'unknown') {
    return decision
  }
  return 'unknown'
}

export function normalizePeripheralSource(source: PeripheralRecordSource): PeripheralRecordSource {
  if (source === 'runtime_event' || source === 'audit_event' || source === 'policy_snapshot') {
    return source
  }
  return 'audit_event'
}
