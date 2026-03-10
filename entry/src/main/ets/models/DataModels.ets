// 闃茬伀澧欒鍒欑被鍨?
export enum RuleType {
  IP = 1,
  DOMAIN = 2,
  DNS = 3
}

// 闃茬伀澧欒鍒欐柟鍚?
export enum RuleDirection {
  IN = 1,
  OUT = 2
}

// 闃茬伀澧欒鍒欑瓥鐣?
export enum RuleAction {
  ALLOW = 0,
  DENY = 1
}

// 鍗忚绫诲瀷
export enum ProtocolType {
  ALL = 0,
  TCP = 6,
  UDP = 17,
  ICMP = 1
}

// UI 灞曠ず鐢ㄧ殑瑙勫垯妯″瀷
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

// 缁熻鍗＄墖鏁版嵁妯″瀷
export interface StatCardData {
  label: string
  value: string
  gradientStart: string
  gradientEnd: string
  icon: Resource
}

// 蹇嵎宸ュ叿鍗＄墖鏁版嵁妯″瀷
export interface ToolCardData {
  label: string
  icon: Resource
  route: string
  gradientStart: string
  gradientEnd: string
}

// 瑙勫垯绫诲瀷鍒楄〃椤规ā鍨?
export interface RuleTypeData {
  label: string
  description: string
  ruleType: RuleType
  count: number
  iconColor: string
}

// 鑾峰彇瑙勫垯绫诲瀷鏍囩
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

// 鑾峰彇鏂瑰悜鏍囩
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

// 鑾峰彇鍗忚鏍囩
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

// 鑾峰彇绛栫暐鏍囩
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

// ==================== 澶栬绠＄悊妯″潡 ====================

// 澶栬绫诲瀷
export enum PeripheralType {
  USB_STORAGE = 'usb_storage',
  USB_CAMERA = 'usb_camera',
  USB_PRINTER = 'usb_printer',
  USB_OTHER = 'usb_other',
  BLUETOOTH = 'bluetooth'
}

// 鎺ュ彛绠℃帶 feature
export enum InterfaceFeature {
  USB = 'usb',
  BLUETOOTH = 'bluetooth',
  WIFI = 'wifi',
  HDC = 'hdc'
}

// USB 瀛樺偍璁块棶绛栫暐
export enum UsbStoragePolicy {
  READ_WRITE = 0,
  READ_ONLY = 1,
  DISABLED = 2
}

// 浼佷笟绠＄悊鍛樼被鍨?
export type EnterpriseAdminType = 'super' | 'byod'

// 浼佷笟绠＄悊鍛樻縺娲荤姸鎬?
export interface AdminActivationState {
  activated: boolean
  errorCode?: number
  errorMessage?: string
  enableCommand: string
  adminType: EnterpriseAdminType
}

// 閫氱敤鎿嶄綔缁撴灉
export interface OperationResult<T = void> {
  success: boolean
  data?: T
  errorCode?: number
  errorMessage?: string
  isAdminMissing?: boolean
  suggestion?: string
}

// 璁惧杩炴帴璁板綍
export interface DeviceRecord {
  deviceName: string
  deviceType: PeripheralType
  deviceId: string
  connectTime: string
  policy: string
}

// 璁惧绠℃帶璁板綍锛堟敮鎸佺瓥鐣ヤ笅鎷夐€夋嫨锛?
export interface DeviceControlRecord {
  deviceName: string
  deviceType: PeripheralType
  deviceId: string
  connectTime: string
  policyIndex: number  // 0=鍏佽, 1=绂佺敤, 2=鏈厤缃?
}

// USB 鐧藉悕鍗曢」锛圲I 灞曠ず鐢紝鍚娉級
export interface UsbWhitelistItem {
  vendorId: number
  productId: number
  remark: string
}

// USB 绫诲瀷榛戝悕鍗曢」锛圲I 灞曠ず鐢紝鍚弿杩帮級
export interface UsbBlacklistItem {
  baseClass: number
  subClass: number
  protocol: number
  description: string
}

// 钃濈墮鐧藉悕鍗曢」锛圲I 灞曠ず鐢紝鍚娉級
export interface BluetoothWhitelistItem {
  deviceId: string
  remark: string
}

// 鎺ュ彛绠℃帶閰嶇疆椤?
export interface InterfaceControlConfig {
  feature: string
  label: string
  description: string
  options: string[]
  selectedIndex: number
}

// 鑾峰彇澶栬绫诲瀷鏍囩
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

// 鑾峰彇 USB 瀛樺偍绛栫暐鏍囩
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

// ==================== 璁惧 ID 瑙ｆ瀽宸ュ叿鍑芥暟 ====================

// USB 璁惧 ID 瑙ｆ瀽缁撴灉
export interface ParsedUsbId {
  vendorId: number
  productId: number
}

// 瑙ｆ瀽 "VID:2B7E PID:B5A2" 鈫?ParsedUsbId
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

// 瑙ｆ瀽 "MAC: AA:BB:CC:DD:EE:01" 鈫?"AA:BB:CC:DD:EE:01"
export function parseBluetoothMac(deviceId: string): string | null {
  let match = deviceId.match(/MAC:\s*([0-9A-Fa-f:]+)/)
  return match ? match[1] : null
}

// 鏍煎紡鍖?{ vendorId, productId } 鈫?"VID:2B7E PID:B5A2"
export function formatUsbDeviceId(vendorId: number, productId: number): string {
  return `VID:${vendorId.toString(16).toUpperCase().padStart(4, '0')} PID:${productId.toString(16).toUpperCase().padStart(4, '0')}`
}

// PeripheralType 鈫?USB Base Class 鏄犲皠锛堢鐢ㄦ椂鍔犲叆榛戝悕鍗曠敤锛?
// USB_STORAGE 鈫?0x08, USB_CAMERA 鈫?0x0E, USB_PRINTER 鈫?0x07
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

// USB Base Class 鈫?PeripheralType 鍙嶆煡
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

// ==================== 韬唤閴村埆妯″潡 ====================

// 鍙ｄ护澶嶆潅搴?UI 閰嶇疆锛堢敤浜?View 灞傜姸鎬佺鐞嗭級
export interface PasswordComplexityConfig {
  minLength: number           // 鏈€灏忓瘑鐮侀暱搴? 6/8/10/12/16
  requireUppercase: boolean   // 瑕佹眰澶у啓瀛楁瘝
  requireLowercase: boolean   // 瑕佹眰灏忓啓瀛楁瘝
  requireDigit: boolean       // 瑕佹眰鏁板瓧
  requireSpecialChar: boolean // 瑕佹眰鐗规畩瀛楃
}

// 鍙ｄ护鏈夋晥鏈?UI 閰嶇疆
export interface DomainPolicyConfig {
  passwordMaxAgeDays: number        // 瀵嗙爜鏈€闀夸娇鐢ㄥぉ鏁? 30/60/90/180/-1(涓嶉檺)
  expirationNotifyDays: number      // 杩囨湡鍓嶆彁閱掑ぉ鏁? 3/7/14/30
  authTokenValidityMinutes: number  // 璁よ瘉Token鏈夋晥鏈?鍒嗛挓): 5/15/30/60/-1(姘镐箙)
}

// 鏈€灏忓瘑鐮侀暱搴﹂€夐」
export const PASSWORD_LENGTH_OPTIONS: number[] = [6, 8, 10, 12, 16]

// 瀵嗙爜鏈夋晥鏈熼€夐」 (澶? -1 = 涓嶉檺鍒?
export const PASSWORD_MAX_AGE_OPTIONS: number[] = [30, 60, 90, 180, -1]

// 杩囨湡鎻愰啋澶╂暟閫夐」
export const EXPIRY_NOTIFY_OPTIONS: number[] = [3, 7, 14, 30]

// 璁よ瘉Token鏈夋晥鏈熼€夐」 (鍒嗛挓, -1 = 姘镐箙)
export const AUTH_TOKEN_VALIDITY_OPTIONS: number[] = [5, 15, 30, 60, -1]

// ==================== 宸ュ叿璁剧疆妯″潡 ====================

// 璁よ瘉鏂瑰紡鏋氫妇锛堝搴?userAuth.UserAuthType锛?
export enum AuthMethod {
  PIN = 1,          // PIN 鐮佽璇?
  FACE = 2,         // 浜鸿劯璇嗗埆
  FINGERPRINT = 4,  // 鎸囩汗璁よ瘉
  PIN_FINGERPRINT = 5 // PIN + 鎸囩汗缁勫悎
}

// 宸ュ叿璁剧疆 UI 閰嶇疆
export interface ToolSettingsConfig {
  startupAuthEnabled: boolean   // 鍚姩鏃舵槸鍚﹂渶瑕佽璇?
  authMethod: AuthMethod        // 璁よ瘉鏂瑰紡
}

// 瀵嗙爜鍙樻洿璇锋眰
export interface PasswordChangeRequest {
  currentPassword: string       // 褰撳墠瀵嗙爜
  newPassword: string           // 鏂板瘑鐮?
  confirmPassword: string       // 纭鏂板瘑鐮?
}

// 榛樿宸ュ叿璁剧疆閰嶇疆
export const DEFAULT_TOOL_SETTINGS: ToolSettingsConfig = {
  startupAuthEnabled: true,
  authMethod: AuthMethod.PIN
}

// 璁よ瘉鏂瑰紡閫夐」鎺ュ彛
export interface AuthMethodOption {
  label: string
  value: AuthMethod
}

// 璁よ瘉鏂瑰紡閫夐」
export const AUTH_METHOD_OPTIONS: AuthMethodOption[] = [
  { label: 'PIN 码', value: AuthMethod.PIN } as AuthMethodOption,
  { label: '指纹', value: AuthMethod.FINGERPRINT } as AuthMethodOption,
  { label: '人脸识别', value: AuthMethod.FACE } as AuthMethodOption,
  { label: 'PIN + 指纹', value: AuthMethod.PIN_FINGERPRINT } as AuthMethodOption
]

// Asset Store 閿悕甯搁噺
export const ASSET_KEY_TOOL_PASSWORD = 'tool_password'

// Preferences 閿悕甯搁噺
export const PREF_KEY_STARTUP_AUTH = 'startup_auth_enabled'
export const PREF_KEY_AUTH_METHOD = 'auth_method'

// Preferences Store 鍚嶇О甯搁噺
export const PREF_STORE_NAME_TOOL = 'tool_settings'

// ==================== 鏃ュ織绠＄悊妯″潡 ====================

// 瀹夊叏瀹¤浜嬩欢绫诲瀷锛堝搴?securityAudit.AuditEventType锛?
export enum LogEventType {
  FILE = 0,              // 鏂囦欢鎿嶄綔锛堝惈瀹℃壒娴侊級
  NETWORK_CONN = 1,      // 缃戠粶杩炴帴
  NETWORK_TRAFFIC = 2,   // 缃戠粶娴侀噺
  APP = 3,               // 搴旂敤瀹夎/鍗歌浇/鍚姩
  ACCOUNT = 4,           // 璐︽埛鎿嶄綔锛堢櫥褰?鐧诲嚭/閿佸畾锛?
  USB_ACCESS = 5,        // USB 澶栬璁块棶
  PERMISSION = 6,        // 鏉冮檺鍙樻洿
  PROCESS = 7,           // 杩涚▼鍒涘缓/缁堟
  PRINTER = 8,           // 鎵撳嵃鏈烘搷浣?
  CAMERA = 9,            // 鎽勫儚澶翠娇鐢?
  CERT = 10,             // 璇佷功瀵煎叆/鍒犻櫎
  EDM = 11,              // EDM 绛栫暐鍙樻洿
  DNS = 12               // DNS 鏌ヨ
}

// 瀹¤浜嬩欢鎿嶄綔缁撴灉
export enum LogEventResult {
  SUCCESS = 0,    // 鎿嶄綔鎴愬姛
  BLOCKED = 1,    // 琚瓥鐣ラ樆姝?
  FAILED = 2      // 鎿嶄綔澶辫触
}

// 鏃ュ織鏉＄洰 - 瀵瑰簲绯荤粺 securityAudit.AuditEvent 缁撴瀯鐨?UI 灞曠ず妯″瀷
export interface LogEntry {
  id: string                  // 鍞竴鏍囪瘑锛堝唴閮ㄧ敓鎴愶級
  timestamp: number           // 鏃堕棿鎴筹紙姣锛?
  eventType: LogEventType     // 浜嬩欢绫诲瀷
  detail: string              // 浜嬩欢璇︽儏锛坈ontent 瀛楁瑙ｆ瀽鍚庯級
  processName?: string        // 杩涚▼鍚嶇О
  pid?: number                // 杩涚▼ ID
  uid?: number                // 鐢ㄦ埛 ID
  filePath?: string           // 鏂囦欢璺緞锛團ILE 绫诲瀷锛?
  remoteAddr?: string         // 杩滅▼鍦板潃锛圢ETWORK 绫诲瀷锛?
  sourceEventId?: number      // 鍘熷瀹¤ eventId
  sourceSubType?: number      // 鍘熷瀹¤瀛愮被鍨?
  rawEventName?: string       // 鍘熷浜嬩欢鍚嶇О
  rawOutcome?: string         // 鍘熷缁撴灉瀛楁
  result: LogEventResult      // 鎿嶄綔缁撴灉
}

// 鏃ュ織杩囨护鏉′欢
export interface LogFilter {
  eventTypes?: LogEventType[] // 浜嬩欢绫诲瀷杩囨护锛堢┖鏁扮粍=鍏ㄩ儴锛?
  results?: LogEventResult[]  // 缁撴灉杩囨护锛堢┖鏁扮粍=鍏ㄩ儴锛?
  keyword?: string            // 鍏抽敭瀛楁悳绱紙detail/processName锛?
  startTime?: number          // 寮€濮嬫椂闂达紙姣锛?
  endTime?: number            // 缁撴潫鏃堕棿锛堟绉掞級
}

// 鏃ュ織瀛樺偍閰嶇疆
export interface LogStorageConfig {
  maxLocalEntries: number
  retentionDays: number
  autoExportEnabled: boolean
  // Legacy field, kept for backward compatibility.
  exportPath?: string
  exportTargetType?: LogExportTargetType
  exportTargetValue?: string
  exportAuthMode?: LogExportAuthMode
}

export type LogExportTargetType = 'download' | 'documents' | 'desktop' | 'custom_uri'

export type LogExportAuthMode = 'runtime_permission' | 'persisted_uri'

// 鏃ュ織璁㈤槄閰嶇疆
export interface LogSubscriptionConfig {
  subscribeAll: boolean         // 鏄惁璁㈤槄鍏ㄩ儴浜嬩欢绫诲瀷
  subscribedTypes: LogEventType[] // 璁㈤槄鐨勪簨浠剁被鍨嬪垪琛?
}

// 鏃ュ織缁熻淇℃伅锛堢敤浜?Dashboard 灞曠ず锛?
export interface LogStatistics {
  totalCount: number          // 鎬绘潯鏁?
  todayCount: number          // 浠婃棩鏉℃暟
  blockedCount: number        // 闃绘柇浜嬩欢鏁?
  byType: Map<LogEventType, number>  // 鎸夌被鍨嬬粺璁?
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

// 鏃ュ織瀵煎嚭鏍煎紡
export enum LogExportFormat {
  JSON = 'json',
  CSV = 'csv',
  TXT = 'txt'
}

// 鏃ュ織瀵煎嚭瑙﹀彂鏉ユ簮
export type LogExportTrigger = 'manual' | 'auto'

// 鏃ュ織瀵煎嚭缁撴灉
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
}

// 浜嬩欢绫诲瀷閫夐」锛圲I 灞曠ず鐢級
export interface LogEventTypeOption {
  label: string
  value: LogEventType
  icon?: Resource
}

// 榛樿鏃ュ織瀛樺偍閰嶇疆
export const DEFAULT_LOG_STORAGE_CONFIG: LogStorageConfig = {
  maxLocalEntries: 5000,
  retentionDays: 30,
  autoExportEnabled: false,
  exportTargetType: 'download',
  exportTargetValue: '',
  exportAuthMode: 'runtime_permission'
}

// 鍏ㄩ儴瀹¤绫诲瀷锛堥渶姹傛竻鍗?13 绫伙級
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

// 榛樿璁㈤槄閰嶇疆锛堥粯璁よ闃呭叏閮?13 绫伙級
export const DEFAULT_SUBSCRIPTION_CONFIG: LogSubscriptionConfig = {
  subscribeAll: true,
  subscribedTypes: ALL_LOG_EVENT_TYPES
}

// 鏃ュ織淇濈暀澶╂暟閫夐」
export const LOG_RETENTION_OPTIONS: number[] = [7, 14, 30, 60, 90]

// 鏈湴鏈€澶ф潯鏁伴€夐」
export const LOG_MAX_ENTRIES_OPTIONS: number[] = [1000, 5000]

// Preferences 閿悕甯搁噺锛堟棩蹇楁ā鍧楋級
export const PREF_KEY_LOG_MAX_ENTRIES = 'log_max_entries'
export const PREF_KEY_LOG_RETENTION_DAYS = 'log_retention_days'
export const PREF_KEY_LOG_AUTO_EXPORT = 'log_auto_export'
export const PREF_KEY_LOG_EXPORT_PATH = 'log_export_path'
export const PREF_KEY_LOG_EXPORT_TARGET_TYPE = 'log_export_target_type'
export const PREF_KEY_LOG_EXPORT_TARGET_VALUE = 'log_export_target_value'
export const PREF_KEY_LOG_EXPORT_AUTH_MODE = 'log_export_auth_mode'
export const PREF_KEY_LOG_SUBSCRIBE_ALL = 'log_subscribe_all'
export const PREF_KEY_LOG_SUBSCRIBED_TYPES = 'log_subscribed_types'

// Preferences Store 鍚嶇О甯搁噺锛堟棩蹇楁ā鍧楋級
export const PREF_STORE_NAME_LOG = 'log_settings'

// 鑾峰彇浜嬩欢绫诲瀷鏍囩
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
      return 'USB访问'
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
      return 'EDM策略'
    case LogEventType.DNS:
      return 'DNS查询'
    default:
      return '未知'
  }
}

// 鑾峰彇浜嬩欢缁撴灉鏍囩
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

// 鑾峰彇浜嬩欢缁撴灉棰滆壊锛堢敤浜?UI 灞曠ず锛?
export function getLogEventResultColor(result: LogEventResult): string {
  switch (result) {
    case LogEventResult.SUCCESS:
      return '#4CAF50'  // 缁胯壊
    case LogEventResult.BLOCKED:
      return '#FF9800'  // 姗欒壊
    case LogEventResult.FAILED:
      return '#F44336'  // 绾㈣壊
    default:
      return '#9E9E9E'  // 鐏拌壊
  }
}

// 浜嬩欢绫诲瀷閫夐」鍒楄〃锛堢敤浜庣瓫閫夊櫒锛?
export const LOG_EVENT_TYPE_OPTIONS: LogEventTypeOption[] = [
  { label: '文件操作', value: LogEventType.FILE },
  { label: '网络连接', value: LogEventType.NETWORK_CONN },
  { label: '网络流量', value: LogEventType.NETWORK_TRAFFIC },
  { label: '应用管理', value: LogEventType.APP },
  { label: '账户操作', value: LogEventType.ACCOUNT },
  { label: 'USB访问', value: LogEventType.USB_ACCESS },
  { label: '权限变更', value: LogEventType.PERMISSION },
  { label: '进程管理', value: LogEventType.PROCESS },
  { label: '打印机', value: LogEventType.PRINTER },
  { label: '摄像头', value: LogEventType.CAMERA },
  { label: '证书管理', value: LogEventType.CERT },
  { label: 'EDM策略', value: LogEventType.EDM },
  { label: 'DNS查询', value: LogEventType.DNS }
]

// 鏍煎紡鍖栨椂闂存埑涓哄彲璇诲瓧绗︿覆
export function formatLogTimestamp(timestamp: number): string {
  let date = new Date(timestamp)
  let pad = (n: number): string => n.toString().padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
}

// 鐢熸垚鏃ュ織鏉＄洰鍞竴 ID
export function generateLogEntryId(): string {
  return `log_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`
}

