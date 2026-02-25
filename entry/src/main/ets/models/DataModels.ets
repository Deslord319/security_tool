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
