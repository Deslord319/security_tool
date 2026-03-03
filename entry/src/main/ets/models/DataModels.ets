// 防火墙规则类型
export enum RuleType {
  IP = 1,
  DOMAIN = 2,
  DNS = 3
}

// 防火墙规则方向
export enum RuleDirection {
  IN = 1,
  OUT = 2
}

// 防火墙规则策略
export enum RuleAction {
  ALLOW = 0,
  DENY = 1
}

// 协议类型
export enum ProtocolType {
  ALL = 0,
  TCP = 6,
  UDP = 17,
  ICMP = 1
}

// UI 展示用的规则模型
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

// 统计卡片数据模型
export interface StatCardData {
  label: string
  value: string
  gradientStart: string
  gradientEnd: string
  icon: Resource
}

// 快捷工具卡片数据模型
export interface ToolCardData {
  label: string
  icon: Resource
  route: string
  gradientStart: string
  gradientEnd: string
}

// 规则类型列表项模型
export interface RuleTypeData {
  label: string
  description: string
  ruleType: RuleType
  count: number
  iconColor: string
}

// 获取规则类型标签
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

// 获取方向标签
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

// 获取协议标签
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

// 获取策略标签
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

// ==================== 外设管理模块 ====================

// 外设类型
export enum PeripheralType {
  USB_STORAGE = 'usb_storage',
  USB_CAMERA = 'usb_camera',
  USB_PRINTER = 'usb_printer',
  USB_OTHER = 'usb_other',
  BLUETOOTH = 'bluetooth'
}

// 接口管控 feature
export enum InterfaceFeature {
  USB = 'usb',
  BLUETOOTH = 'bluetooth',
  WIFI = 'wifi',
  HDC = 'hdc'
}

// USB 存储访问策略
export enum UsbStoragePolicy {
  READ_WRITE = 0,
  READ_ONLY = 1,
  DISABLED = 2
}

// 设备连接记录
export interface DeviceRecord {
  deviceName: string
  deviceType: PeripheralType
  deviceId: string
  connectTime: string
  policy: string
}

// 设备管控记录（支持策略下拉选择）
export interface DeviceControlRecord {
  deviceName: string
  deviceType: PeripheralType
  deviceId: string
  connectTime: string
  policyIndex: number  // 0=允许, 1=禁用, 2=未配置
}

// USB 白名单项（UI 展示用，含备注）
export interface UsbWhitelistItem {
  vendorId: number
  productId: number
  remark: string
}

// USB 类型黑名单项（UI 展示用，含描述）
export interface UsbBlacklistItem {
  baseClass: number
  subClass: number
  protocol: number
  description: string
}

// 蓝牙白名单项（UI 展示用，含备注）
export interface BluetoothWhitelistItem {
  deviceId: string
  remark: string
}

// 接口管控配置项
export interface InterfaceControlConfig {
  feature: string
  label: string
  description: string
  options: string[]
  selectedIndex: number
}

// 获取外设类型标签
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

// 获取 USB 存储策略标签
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

// ==================== 设备 ID 解析工具函数 ====================

// USB 设备 ID 解析结果
export interface ParsedUsbId {
  vendorId: number
  productId: number
}

// 解析 "VID:2B7E PID:B5A2" → ParsedUsbId
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

// 解析 "MAC: AA:BB:CC:DD:EE:01" → "AA:BB:CC:DD:EE:01"
export function parseBluetoothMac(deviceId: string): string | null {
  let match = deviceId.match(/MAC:\s*([0-9A-Fa-f:]+)/)
  return match ? match[1] : null
}

// 格式化 { vendorId, productId } → "VID:2B7E PID:B5A2"
export function formatUsbDeviceId(vendorId: number, productId: number): string {
  return `VID:${vendorId.toString(16).toUpperCase().padStart(4, '0')} PID:${productId.toString(16).toUpperCase().padStart(4, '0')}`
}

// PeripheralType → USB Base Class 映射（禁用时加入黑名单用）
// USB_STORAGE → 0x08, USB_CAMERA → 0x0E, USB_PRINTER → 0x07
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

// USB Base Class → PeripheralType 反查
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

// ==================== 身份鉴别模块 ====================

// 口令复杂度 UI 配置（用于 View 层状态管理）
export interface PasswordComplexityConfig {
  minLength: number           // 最小密码长度: 6/8/10/12/16
  requireUppercase: boolean   // 要求大写字母
  requireLowercase: boolean   // 要求小写字母
  requireDigit: boolean       // 要求数字
  requireSpecialChar: boolean // 要求特殊字符
}

// 口令有效期 UI 配置
export interface DomainPolicyConfig {
  passwordMaxAgeDays: number        // 密码最长使用天数: 30/60/90/180/-1(不限)
  expirationNotifyDays: number      // 过期前提醒天数: 3/7/14/30
  authTokenValidityMinutes: number  // 认证Token有效期(分钟): 5/15/30/60/-1(永久)
}

// 最小密码长度选项
export const PASSWORD_LENGTH_OPTIONS: number[] = [6, 8, 10, 12, 16]

// 密码有效期选项 (天, -1 = 不限制)
export const PASSWORD_MAX_AGE_OPTIONS: number[] = [30, 60, 90, 180, -1]

// 过期提醒天数选项
export const EXPIRY_NOTIFY_OPTIONS: number[] = [3, 7, 14, 30]

// 认证Token有效期选项 (分钟, -1 = 永久)
export const AUTH_TOKEN_VALIDITY_OPTIONS: number[] = [5, 15, 30, 60, -1]

// ==================== 工具设置模块 ====================

// 认证方式枚举（对应 userAuth.UserAuthType）
export enum AuthMethod {
  PIN = 1,          // PIN 码认证
  FACE = 2,         // 人脸识别
  FINGERPRINT = 4,  // 指纹认证
  PIN_FINGERPRINT = 5 // PIN + 指纹组合
}

// 工具设置 UI 配置
export interface ToolSettingsConfig {
  startupAuthEnabled: boolean   // 启动时是否需要认证
  authMethod: AuthMethod        // 认证方式
}

// 密码变更请求
export interface PasswordChangeRequest {
  currentPassword: string       // 当前密码
  newPassword: string           // 新密码
  confirmPassword: string       // 确认新密码
}

// 默认工具设置配置
export const DEFAULT_TOOL_SETTINGS: ToolSettingsConfig = {
  startupAuthEnabled: true,
  authMethod: AuthMethod.PIN
}

// 认证方式选项接口
export interface AuthMethodOption {
  label: string
  value: AuthMethod
}

// 认证方式选项
export const AUTH_METHOD_OPTIONS: AuthMethodOption[] = [
  { label: 'PIN 码', value: AuthMethod.PIN } as AuthMethodOption,
  { label: '指纹', value: AuthMethod.FINGERPRINT } as AuthMethodOption,
  { label: '人脸识别', value: AuthMethod.FACE } as AuthMethodOption,
  { label: 'PIN + 指纹', value: AuthMethod.PIN_FINGERPRINT } as AuthMethodOption
]

// Asset Store 键名常量
export const ASSET_KEY_TOOL_PASSWORD = 'tool_password'

// Preferences 键名常量
export const PREF_KEY_STARTUP_AUTH = 'startup_auth_enabled'
export const PREF_KEY_AUTH_METHOD = 'auth_method'

// Preferences Store 名称常量
export const PREF_STORE_NAME_TOOL = 'tool_settings'

// ==================== 日志管理模块 ====================

// 安全审计事件类型（对应 securityAudit.AuditEventType）
export enum LogEventType {
  FILE = 0,              // 文件操作（含审批流）
  NETWORK_CONN = 1,      // 网络连接
  NETWORK_TRAFFIC = 2,   // 网络流量
  APP = 3,               // 应用安装/卸载/启动
  ACCOUNT = 4,           // 账户操作（登录/登出/锁定）
  USB_ACCESS = 5,        // USB 外设访问
  PERMISSION = 6,        // 权限变更
  PROCESS = 7,           // 进程创建/终止
  PRINTER = 8,           // 打印机操作
  CAMERA = 9,            // 摄像头使用
  CERT = 10,             // 证书导入/删除
  EDM = 11,              // EDM 策略变更
  DNS = 12               // DNS 查询
}

// 审计事件操作结果
export enum LogEventResult {
  SUCCESS = 0,    // 操作成功
  BLOCKED = 1,    // 被策略阻止
  FAILED = 2      // 操作失败
}

// 日志条目 - 对应系统 securityAudit.AuditEvent 结构的 UI 展示模型
export interface LogEntry {
  id: string                  // 唯一标识（内部生成）
  timestamp: number           // 时间戳（毫秒）
  eventType: LogEventType     // 事件类型
  detail: string              // 事件详情（content 字段解析后）
  processName?: string        // 进程名称
  pid?: number                // 进程 ID
  uid?: number                // 用户 ID
  filePath?: string           // 文件路径（FILE 类型）
  remoteAddr?: string         // 远程地址（NETWORK 类型）
  result: LogEventResult      // 操作结果
}

// 日志过滤条件
export interface LogFilter {
  eventTypes?: LogEventType[] // 事件类型过滤（空数组=全部）
  results?: LogEventResult[]  // 结果过滤（空数组=全部）
  keyword?: string            // 关键字搜索（detail/processName）
  startTime?: number          // 开始时间（毫秒）
  endTime?: number            // 结束时间（毫秒）
}

// 日志存储配置
export interface LogStorageConfig {
  maxLocalEntries: number     // 本地最大条数
  retentionDays: number       // 保留天数
  autoExportEnabled: boolean  // 自动导出开关
  exportPath?: string         // 导出路径
}

// 日志订阅配置
export interface LogSubscriptionConfig {
  subscribeAll: boolean         // 是否订阅全部事件类型
  subscribedTypes: LogEventType[] // 订阅的事件类型列表
}

// 日志统计信息（用于 Dashboard 展示）
export interface LogStatistics {
  totalCount: number          // 总条数
  todayCount: number          // 今日条数
  blockedCount: number        // 阻止事件数
  byType: Map<LogEventType, number>  // 按类型统计
}

// 日志导出格式
export enum LogExportFormat {
  JSON = 'json',
  CSV = 'csv',
  TXT = 'txt'
}

// 事件类型选项（UI 展示用）
export interface LogEventTypeOption {
  label: string
  value: LogEventType
  icon?: Resource
}

// 默认日志存储配置
export const DEFAULT_LOG_STORAGE_CONFIG: LogStorageConfig = {
  maxLocalEntries: 10000,
  retentionDays: 30,
  autoExportEnabled: false
}

// 全部审计类型（需求清单 13 类）
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

// 默认订阅配置（默认订阅全部 13 类）
export const DEFAULT_SUBSCRIPTION_CONFIG: LogSubscriptionConfig = {
  subscribeAll: true,
  subscribedTypes: ALL_LOG_EVENT_TYPES
}

// 日志保留天数选项
export const LOG_RETENTION_OPTIONS: number[] = [7, 14, 30, 60, 90]

// 本地最大条数选项
export const LOG_MAX_ENTRIES_OPTIONS: number[] = [1000, 5000, 10000, 50000]

// Preferences 键名常量（日志模块）
export const PREF_KEY_LOG_MAX_ENTRIES = 'log_max_entries'
export const PREF_KEY_LOG_RETENTION_DAYS = 'log_retention_days'
export const PREF_KEY_LOG_AUTO_EXPORT = 'log_auto_export'
export const PREF_KEY_LOG_EXPORT_PATH = 'log_export_path'
export const PREF_KEY_LOG_SUBSCRIBE_ALL = 'log_subscribe_all'
export const PREF_KEY_LOG_SUBSCRIBED_TYPES = 'log_subscribed_types'

// Preferences Store 名称常量（日志模块）
export const PREF_STORE_NAME_LOG = 'log_settings'

// 获取事件类型标签
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

// 获取事件结果标签
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

// 获取事件结果颜色（用于 UI 展示）
export function getLogEventResultColor(result: LogEventResult): string {
  switch (result) {
    case LogEventResult.SUCCESS:
      return '#4CAF50'  // 绿色
    case LogEventResult.BLOCKED:
      return '#FF9800'  // 橙色
    case LogEventResult.FAILED:
      return '#F44336'  // 红色
    default:
      return '#9E9E9E'  // 灰色
  }
}

// 事件类型选项列表（用于筛选器）
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

// 格式化时间戳为可读字符串
export function formatLogTimestamp(timestamp: number): string {
  let date = new Date(timestamp)
  let pad = (n: number): string => n.toString().padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
}

// 生成日志条目唯一 ID
export function generateLogEntryId(): string {
  return `log_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`
}
