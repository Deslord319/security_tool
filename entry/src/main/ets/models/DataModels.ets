
export enum RuleType {
  IP = 1,
  DOMAIN = 2,
  DNS = 3
}


export enum RuleDirection {
  IN = 1,
  OUT = 2
}


export enum RuleAction {
  ALLOW = 0,
  DENY = 1
}


export enum ProtocolType {
  ALL = 0,
  TCP = 6,
  UDP = 17,
  ICMP = 1
}


export interface FirewallRuleDisplay {
  ruleId: number
  name: string
  ruleType: RuleType
  direction: RuleDirection
  protocol: ProtocolType
  address: string
  port: string
  action: RuleAction
  isEnabled: boolean
}


export interface StatCardData {
  label: string
  value: string
  gradientStart: string
  gradientEnd: string
  icon: Resource
}


export interface ToolCardData {
  label: string
  icon: Resource
  route: string
  gradientStart: string
  gradientEnd: string
}


export interface RuleTypeData {
  label: string
  description: string
  ruleType: RuleType
  count: number
  iconColor: string
}


export function getRuleTypeLabel(type: RuleType): string {
  switch (type) {
    case RuleType.IP:
      return 'IP'
    case RuleType.DOMAIN:
      return '域名'
    case RuleType.DNS:
      return 'DNS'
    default:
      return '未知'
  }
}


export function getDirectionLabel(dir: RuleDirection): string {
  switch (dir) {
    case RuleDirection.IN:
      return '入站'
    case RuleDirection.OUT:
      return '出站'
    default:
      return '未知'
  }
}


export function getProtocolLabel(proto: ProtocolType): string {
  switch (proto) {
    case ProtocolType.ALL:
      return 'ALL'
    case ProtocolType.TCP:
      return 'TCP'
    case ProtocolType.UDP:
      return 'UDP'
    case ProtocolType.ICMP:
      return 'ICMP'
    default:
      return 'ALL'
  }
}


export function getActionLabel(action: RuleAction): string {
  switch (action) {
    case RuleAction.ALLOW:
      return '允许'
    case RuleAction.DENY:
      return '拒绝'
    default:
      return '未知'
  }
}




export enum PeripheralType {
  USB_STORAGE = 'usb_storage',
  USB_CAMERA = 'usb_camera',
  USB_PRINTER = 'usb_printer',
  USB_OTHER = 'usb_other',
  BLUETOOTH = 'bluetooth'
}


export enum InterfaceFeature {
  USB = 'usb',
  BLUETOOTH = 'bluetooth',
  WIFI = 'wifi',
  HDC = 'hdc'
}


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
  isAdminMissing?: boolean
  suggestion?: string
}


export interface DeviceRecord {
  deviceName: string
  deviceType: PeripheralType
  deviceId: string
  connectTime?: string
  policy?: string
}

export type PeripheralRecordSource = 'runtime_event' | 'audit_event' | 'policy_snapshot'

export type PeripheralCandidateSource = PeripheralRecordSource | 'connected_usb'

export type PeripheralRecordAction = 'connect' | 'disconnect' | 'intercept' | 'unknown'

export type PeripheralRecordPolicyHit = 'allow' | 'deny' | 'unknown'

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
}

export interface PeripheralWhitelistCandidate {
  id: string
  deviceName: string
  deviceType: PeripheralType
  deviceId: string
  timestamp: number
  source: PeripheralCandidateSource
  vendorId?: number
  productId?: number
  mac?: string
  isConnected?: boolean
  disabled: boolean
}

export interface PeripheralBlacklistTemplate {
  id: string
  title: string
  description: string
  baseClass: number
  subClass: number
  protocol: number
  fromConnectedDevice?: boolean
  disabled: boolean
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
  pageSize?: number
  pageOffset?: number
}

export interface PeripheralTraceStats {
  total: number
  connects: number
  disconnects: number
  intercepts: number
  allows: number
  denies: number
  unknowns: number
  runtimeCount: number
  auditCount: number
  snapshotCount: number
}


export interface DeviceControlRecord {
  deviceName: string
  deviceType: PeripheralType
  deviceId: string
  connectTime: string
  policyIndex: number
}


export interface UsbWhitelistItem {
  vendorId: number
  productId: number
  remark: string
}


export interface UsbBlacklistItem {
  baseClass: number
  subClass: number
  protocol: number
  description: string
}


export interface BluetoothWhitelistItem {
  deviceId: string
  remark: string
}


export interface InterfaceControlConfig {
  feature: string
  label: string
  description: string
  options: string[]
  selectedIndex: number
}


export function getPeripheralTypeLabel(type: PeripheralType): string {
  switch (type) {
    case PeripheralType.USB_STORAGE:
      return 'USB 存储设备'
    case PeripheralType.USB_CAMERA:
      return 'USB 摄像头'
    case PeripheralType.USB_PRINTER:
      return 'USB 打印机'
    case PeripheralType.USB_OTHER:
      return 'USB 其他'
    case PeripheralType.BLUETOOTH:
      return '蓝牙设备'
    default:
      return '未知'
  }
}


export function getUsbStoragePolicyLabel(policy: UsbStoragePolicy): string {
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

export function getPeripheralRecordSourceLabel(source: PeripheralRecordSource): string {
  switch (source) {
    case 'runtime_event':
      return '运行时事件'
    case 'audit_event':
      return '审计事件'
    case 'policy_snapshot':
      return '策略快照'
    default:
      return '未知来源'
  }
}

export function getPeripheralRecordActionLabel(action: PeripheralRecordAction): string {
  switch (action) {
    case 'connect':
      return '连接'
    case 'disconnect':
      return '断开'
    case 'intercept':
      return '拦截'
    default:
      return '未知动作'
  }
}
export function getPeripheralRecordPolicyHitLabel(policyHit: PeripheralRecordPolicyHit): string {
  switch (policyHit) {
    case 'allow':
      return '允许'
    case 'deny':
      return '阻止'
    default:
      return '未知'
  }
}

export function getPeripheralCandidateSourceLabel(source: PeripheralCandidateSource): string {
  if (source === 'connected_usb') {
    return '当前连接'
  }
  return getPeripheralRecordSourceLabel(source)
}

// ==================== 设备 ID 解析工具函数 ====================



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


export function parseBluetoothMac(deviceId: string): string | null {
  let match = deviceId.match(/MAC:\s*([0-9A-Fa-f:]+)/)
  return match ? match[1] : null
}


export function formatUsbDeviceId(vendorId: number, productId: number): string {
  return `VID:${vendorId.toString(16).toUpperCase().padStart(4, '0')} PID:${productId.toString(16).toUpperCase().padStart(4, '0')}`
}



export function inferUsbBaseClass(type: PeripheralType): number {
  switch (type) {
    case PeripheralType.USB_STORAGE:
      return 0x08
    case PeripheralType.USB_CAMERA:
      return 0x0E
    case PeripheralType.USB_PRINTER:
      return 0x07
    default:
      return 0
  }
}


export function inferPeripheralTypeFromBaseClass(baseClass: number): PeripheralType {
  switch (baseClass) {
    case 0x08:
      return PeripheralType.USB_STORAGE
    case 0x0E:
      return PeripheralType.USB_CAMERA
    case 0x07:
      return PeripheralType.USB_PRINTER
    default:
      return PeripheralType.USB_OTHER
  }
}




export interface PasswordComplexityConfig {
  minLength: number
  requireUppercase: boolean
  requireLowercase: boolean
  requireDigit: boolean
  requireSpecialChar: boolean
  validityPeriod: number
}


export const PASSWORD_LENGTH_OPTIONS: number[] = [6, 8, 10, 12, 16]
export const PASSWORD_VALIDITY_OPTIONS: number[] = [0, 30, 60, 90]




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
  { label: 'PIN', value: AuthMethod.PIN } as AuthMethodOption,
  { label: '指纹', value: AuthMethod.FINGERPRINT } as AuthMethodOption
]

export type FirewallPresetMode = 'public' | 'private' | 'custom'

export const PREF_KEY_STARTUP_AUTH = 'startup_auth_enabled'
export const PREF_KEY_AUTH_METHOD = 'auth_method'


export const PREF_STORE_NAME_TOOL = 'tool_settings'


export type FirewallToggleRejectReason =
  'lockout' |
  'pin_unavailable' |
  'pin_failed' |
  'policy_apply_failed'


export interface FirewallToggleResult {
  success: boolean
  targetEnabled: boolean
  reason?: FirewallToggleRejectReason
  lockRemainingSec?: number
  errorCode?: number
  errorMessage?: string
}


export const PREF_STORE_NAME_FIREWALL_AUTH = 'firewall_auth'
export const PREF_KEY_FIREWALL_PIN_FAILED_COUNT = 'firewall_pin_failed_count'
export const PREF_KEY_FIREWALL_PIN_LOCK_UNTIL = 'firewall_pin_lock_until'
export const FIREWALL_PIN_LOCK_MAX_ATTEMPTS = 3
export const FIREWALL_PIN_LOCK_DURATION_MS = 60 * 1000




export enum LogEventType {
  FILE = 0,
  NETWORK_CONN = 1,
  NETWORK_TRAFFIC = 2,
  APP = 3,
  ACCOUNT = 4,
  USB_ACCESS = 5,
  PERMISSION = 6,
  PROCESS = 7,
  PRINTER = 8,
  CAMERA = 9,
  CERT = 10,
  EDM = 11,
  DNS = 12
}


export enum LogEventResult {
  SUCCESS = 0,
  BLOCKED = 1,
  FAILED = 2
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
  sourceSubType?: number
  rawEventName?: string
  rawOutcome?: string
  rawAction?: string
  result: LogEventResult
}


export interface LogFilter {
  eventTypes?: LogEventType[]
  results?: LogEventResult[]
  keyword?: string
  startTime?: number
  endTime?: number
}


export interface LogStorageConfig {
  maxLocalEntries: number
  retentionDays: number

  exportPath?: string
  exportTargetType?: LogExportTargetType
  exportTargetValue?: string
  exportAuthMode?: LogExportAuthMode
}

export type LogExportTargetType = 'download' | 'documents' | 'desktop'

export type LogExportAuthMode = 'runtime_permission' | 'download_mode'


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

export interface LogEventTypeDiag {
  type: LogEventType
  subscribed: boolean
  failedEventIds: number[]
  lastSeenAt?: number
  seenCount: number
  lastErrorCode?: number
}

export type AuditSubscribeMode = 'client' | 'legacy' | 'none'

export type AuditFallbackReason = 'new_api_unavailable' | 'new_api_init_failed' | 'none'

export interface LogAuditDiagnostics {
  byType: Map<LogEventType, LogEventTypeDiag>
  unknownEventIds: number[]
  subscribeMode: AuditSubscribeMode
  fallbackReason: AuditFallbackReason
  lastModeSwitchAt?: number
  lastUpdatedAt: number
}


export enum LogExportFormat {
  JSON = 'json',
  CSV = 'csv',
  TXT = 'txt'
}


export type LogExportTrigger = 'manual' | 'auto'

export type LogExportRecoveryAction = 'pick_directory' | 'authorize_download'


export interface LogExportResult {
  success: boolean
  count: number
  format: LogExportFormat
  timestamp: number
  trigger: LogExportTrigger
  fileName?: string
  fullPath?: string
  directory?: string
  sizeBytes?: number
  errorCode?: number
  errorMessage?: string
  recoverAction?: LogExportRecoveryAction
}


export interface LogEventTypeOption {
  label: string
  value: LogEventType
  icon?: Resource
}


export const DEFAULT_LOG_STORAGE_CONFIG: LogStorageConfig = {
  maxLocalEntries: 5000,
  retentionDays: 30,
  exportTargetType: 'download',
  exportTargetValue: '',
  exportAuthMode: 'download_mode'
}


export const ALL_LOG_EVENT_TYPES: LogEventType[] = [
  LogEventType.FILE,
  LogEventType.NETWORK_CONN,
  LogEventType.NETWORK_TRAFFIC,
  LogEventType.APP,
  LogEventType.ACCOUNT,
  LogEventType.USB_ACCESS,
  LogEventType.PERMISSION,
  LogEventType.PROCESS,
  LogEventType.PRINTER,
  LogEventType.CAMERA,
  LogEventType.CERT,
  LogEventType.EDM,
  LogEventType.DNS
]


export const DEFAULT_SUBSCRIPTION_CONFIG: LogSubscriptionConfig = {
  subscribeAll: true,
  subscribedTypes: ALL_LOG_EVENT_TYPES
}


export const LOG_RETENTION_OPTIONS: number[] = [7, 14, 30, 60, 90]


export const LOG_MAX_ENTRIES_OPTIONS: number[] = [1000, 5000]


export const PREF_KEY_LOG_MAX_ENTRIES = 'log_max_entries'
export const PREF_KEY_LOG_RETENTION_DAYS = 'log_retention_days'
export const PREF_KEY_LOG_EXPORT_PATH = 'log_export_path'
export const PREF_KEY_LOG_EXPORT_TARGET_TYPE = 'log_export_target_type'
export const PREF_KEY_LOG_EXPORT_TARGET_VALUE = 'log_export_target_value'
export const PREF_KEY_LOG_EXPORT_AUTH_MODE = 'log_export_auth_mode'
export const PREF_KEY_LOG_SUBSCRIBE_ALL = 'log_subscribe_all'
export const PREF_KEY_LOG_SUBSCRIBED_TYPES = 'log_subscribed_types'


export const PREF_STORE_NAME_LOG = 'log_settings'


export function getLogEventTypeLabel(type: LogEventType): string {
  switch (type) {
    case LogEventType.FILE:
      return '文件操作'
    case LogEventType.NETWORK_CONN:
      return '网络连接'
    case LogEventType.NETWORK_TRAFFIC:
      return '网络流量'
    case LogEventType.APP:
      return '应用管理'
    case LogEventType.ACCOUNT:
      return '账户操作'
    case LogEventType.USB_ACCESS:
      return 'USB 访问'
    case LogEventType.PERMISSION:
      return '权限变更'
    case LogEventType.PROCESS:
      return '进程管理'
    case LogEventType.PRINTER:
      return '打印机'
    case LogEventType.CAMERA:
      return '摄像头'
    case LogEventType.CERT:
      return '证书管理'
    case LogEventType.EDM:
      return 'EDM 策略'
    case LogEventType.DNS:
      return 'DNS 查询'
    default:
      return '未知'
  }
}


export function getLogEventResultLabel(result: LogEventResult): string {
  switch (result) {
    case LogEventResult.SUCCESS:
      return '成功'
    case LogEventResult.BLOCKED:
      return '已阻止'
    case LogEventResult.FAILED:
      return '失败'
    default:
      return '未知'
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
  { label: '文件操作', value: LogEventType.FILE },
  { label: '网络连接', value: LogEventType.NETWORK_CONN },
  { label: '网络流量', value: LogEventType.NETWORK_TRAFFIC },
  { label: '应用管理', value: LogEventType.APP },
  { label: '账户操作', value: LogEventType.ACCOUNT },
  { label: 'USB 访问', value: LogEventType.USB_ACCESS },
  { label: '权限变更', value: LogEventType.PERMISSION },
  { label: '进程管理', value: LogEventType.PROCESS },
  { label: '打印机', value: LogEventType.PRINTER },
  { label: '摄像头', value: LogEventType.CAMERA },
  { label: '证书管理', value: LogEventType.CERT },
  { label: 'EDM 策略', value: LogEventType.EDM },
  { label: 'DNS 查询', value: LogEventType.DNS }
]


export function formatLogTimestamp(timestamp: number): string {
  let date = new Date(timestamp)
  let pad = (n: number): string => n.toString().padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
}


export function generateLogEntryId(): string {
  return `log_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`
}

