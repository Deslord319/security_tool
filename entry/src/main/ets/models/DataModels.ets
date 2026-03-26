
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
  USB_HID = 'usb_hid',
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
  userMessage?: string
  isAdminMissing?: boolean
  stage?: string
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

export type PeripheralMatchedPolicyKind =
  'usb_disabled' |
  'usb_storage_disabled' |
  'usb_storage_read_only' |
  'usb_whitelist' |
  'usb_blacklist' |
  'default_allow' |
  'disconnect_event' |
  'unknown'

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

export interface PeripheralPolicyRecord {
  deviceName: string
  deviceType: PeripheralType
  deviceId: string
  lastSeenAt: number
  lastSeenLabel: string
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
    case PeripheralType.USB_HID:
      return 'USB 人机输入设备'
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
    case PeripheralType.USB_HID:
      return 0x03
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
    case 0x03:
      return PeripheralType.USB_HID
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

export type FirewallManagedRuleKind = 'preset' | 'custom'

export interface FirewallManagedRuleMetadata {
  owner: 'security_tool'
  mode: FirewallPresetMode
  kind: FirewallManagedRuleKind
  customRuleId?: string
  templateKey?: string
}

export interface FirewallModeSwitchResult {
  success: boolean
  mode: FirewallPresetMode
  appliedRuleCount: number
  errorCode?: number
  errorMessage?: string
}

export interface FirewallPresetConfig {
  fixedPublicIp: string
  privateCidrs: string[]
  privateTcpPorts: number[]
  privateUdpPorts: number[]
}

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

export interface UserFirewallOption {
  userId: number
  label: string
  isForeground?: boolean
}

export interface UserFirewallListResult {
  users: UserFirewallOption[]
  selectedUserId?: number
  errorCode?: number
  message?: string
}

export interface UserFirewallPolicyResult {
  userId: number
  isOpen: boolean
  inAction: number
  outAction: number
  errorCode?: number
  message?: string
}

export interface UserFirewallActionResult {
  success: boolean
  userId: number
  errorCode?: number
  message?: string
}

export const PREF_STORE_NAME_FIREWALL_AUTH = 'firewall_auth'
export const PREF_KEY_FIREWALL_PIN_FAILED_COUNT = 'firewall_pin_failed_count'
export const PREF_KEY_FIREWALL_PIN_LOCK_UNTIL = 'firewall_pin_lock_until'
export const FIREWALL_PIN_LOCK_MAX_ATTEMPTS = 3
export const FIREWALL_PIN_LOCK_DURATION_MS = 60 * 1000
export const PREF_STORE_NAME_FIREWALL_MODE = 'firewall_mode'
export const PREF_KEY_FIREWALL_ACTIVE_MODE = 'firewall_active_mode'
export const PREF_STORE_NAME_FIREWALL_CUSTOM_RULES = 'firewall_custom_rules'
export const PREF_KEY_FIREWALL_CUSTOM_RULES = 'firewall_custom_rules_payload'

export enum LogEventType {
  CRASH = 0,
  FILE = 1,
  ACCOUNT = 2,
  PERMISSION = 3
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

export interface LogEventTypeDiag {
  type: LogEventType
  subscribed: boolean
  failedEventIds: number[]
  lastSeenAt?: number
  seenCount: number
  lastErrorCode?: number
  preFilterUnsupportedEventIds?: number[]
  preFilterFailedEventIds?: number[]
  preFilterLastErrorCode?: number
  droppedNoPathCount?: number
  droppedPrefixMismatchCount?: number
  lastDropReason?: string
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

export interface LogExportResult {
  success: boolean
  timestamp: number
  fileName?: string
  fullPath?: string
  directory?: string
  sizeBytes?: number
  errorCode?: number
  errorMessage?: string
}

export interface LogEventTypeOption {
  label: string
  value: LogEventType
  icon?: Resource
}

export const DEFAULT_LOG_STORAGE_CONFIG: LogStorageConfig = {
  maxLocalEntries: 5000,
  retentionDays: 30
}

export const ALL_LOG_EVENT_TYPES: LogEventType[] = [
  LogEventType.CRASH,
  LogEventType.FILE,
  LogEventType.ACCOUNT,
  LogEventType.PERMISSION
]

export const DEFAULT_SUBSCRIPTION_CONFIG: LogSubscriptionConfig = {
  subscribeAll: true,
  subscribedTypes: ALL_LOG_EVENT_TYPES
}

export const LOG_RETENTION_OPTIONS: number[] = [7, 14, 30, 60, 90]

export const LOG_MAX_ENTRIES_OPTIONS: number[] = [1000, 5000]

export const PREF_KEY_LOG_MAX_ENTRIES = 'log_max_entries'
export const PREF_KEY_LOG_RETENTION_DAYS = 'log_retention_days'
export const PREF_KEY_LOG_SUBSCRIBE_ALL = 'log_subscribe_all'
export const PREF_KEY_LOG_SUBSCRIBED_TYPES = 'log_subscribed_types'
export const PREF_STORE_NAME_LOG = 'log_settings'

export function getLogEventTypeLabel(type: LogEventType): string {
  switch (type) {
    case LogEventType.CRASH:
      return '崩溃日志'
    case LogEventType.FILE:
      return '文件操作'
    case LogEventType.ACCOUNT:
      return '用户认证'
    case LogEventType.PERMISSION:
      return '权限变更'
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
  { label: '崩溃日志', value: LogEventType.CRASH },
  { label: '文件操作', value: LogEventType.FILE },
  { label: '用户认证', value: LogEventType.ACCOUNT },
  { label: '权限变更', value: LogEventType.PERMISSION }
]

export function formatLogTimestamp(timestamp: number): string {
  let date = new Date(timestamp)
  let pad = (n: number): string => n.toString().padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
}

export function generateLogEntryId(): string {
  return `log_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`
}
