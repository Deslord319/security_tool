
import { ActionText, LabelText, MessageText, ResultText } from '../StringCatalog'

/**
 * 对话框通用字符串常量
 * 
 * 统一管理所有对话框组件中的硬编码文字，包括：
 * - 对话框标题
 * - 按钮文本
 * - 提示信息
 * - 状态文本
 */

// ==================== 加载状态文本 ====================
export class LoadingStrings {
  static readonly LOADING: string = '加载中...'
  static readonly LOADING_USERS: string = '正在加载用户列表...'
  static readonly LOADING_RULES: string = '正在加载规则...'
  static readonly APPLYING_MODE: string = '正在应用防火墙模式...'
}

// ==================== 空状态提示 ====================
export class EmptyStateStrings {
  static readonly NO_USERS: string = '暂无可选用户'
  static readonly NO_RECORDS: string = '暂无连接记录'
  static readonly NO_RULES: string = '暂无自定义规则'
  static readonly NO_DEVICES: string = '暂无可管理的设备'
  static readonly NO_RESULTS: string = '未找到相关结果'
}

// Firewall rule type labels reused by filters and dialogs.
export class FirewallRuleLabelStrings {
  static readonly ALL_RULES: string = '全部规则'
  static readonly IP_RULE: string = 'IP规则'
  static readonly DOMAIN_RULE: string = '域名规则'
  static readonly DNS_RULE: string = 'DNS规则'
}

// ==================== 验证错误提示 ====================
export class ValidationErrorStrings {
}

// ==================== 防火墙相关文本 ====================
export class FirewallDialogStrings {
  // 标签
  static readonly RULE_NAME: string = '规则名称'
  static readonly RULE_TYPE: string = '规则类型'
  static readonly RULE_DIRECTION: string = '方向'
  static readonly REMOTE_ADDRESS: string = '远端地址'
  static readonly LOCAL_PORT: string = '本地端口'
  static readonly REMOTE_PORT: string = '远端端口'
  static readonly PROTOCOL: string = '协议'
  static readonly ACTION: string = '动作'
  static readonly TARGET_USER: string = '目标用户'
  static readonly CURRENT_STATUS: string = '当前策略'
  static readonly TARGET_MODE: string = '目标模式'
  
  // 占位符
  static readonly IP_PLACEHOLDER: string = '例如 0.0.0.0/0'
  static readonly DOMAIN_PLACEHOLDER: string = '例如 *.example.com'
  static readonly DNS_PLACEHOLDER: string = '例如 8.8.8.8'
  static readonly PORT_PLACEHOLDER: string = '例如 443'
  static readonly RULE_NAME_PLACEHOLDER: string = '请输入规则名称'
  
  // 规则类型标签
  static readonly DIRECTION_INBOUND: string = '入站'
  static readonly DIRECTION_OUTBOUND: string = '出站'
  static readonly PROTOCOL_TCP: string = 'TCP'
  static readonly PROTOCOL_UDP: string = 'UDP'
  static readonly PROTOCOL_ICMP: string = 'ICMP'
  static readonly ACTION_ALLOW: string = '允许'
  static readonly ACTION_DENY: string = '阻止'
  static readonly SWITCH_ENABLED: string = '已开启'
  static readonly SWITCH_DISABLED: string = '已关闭'
  static readonly APPLY_MODE_FAILED: string = '策略下发失败'
  
  // 状态文本
  static readonly MODE_ALLOWLIST: string = '白名单模式'
  static readonly MODE_DENYLIST: string = '黑名单模式'
  
  // 验证错误
  static readonly ERROR_DOMAIN_REQUIRED: string = '请输入域名'
  static readonly ERROR_DNS_REQUIRED: string = '请输入 DNS 地址'
  static readonly ERROR_IP_REQUIRED: string = '请输入远端 IP 或 CIDR'
  static readonly ERROR_INVALID_IP: string = '远端 IP 或 CIDR 格式不正确'
  static readonly ERROR_INVALID_LOCAL_PORT: string = '本地端口范围必须为 1-65535'
  static readonly ERROR_INVALID_REMOTE_PORT: string = '远端端口范围必须为 1-65535'
  static readonly ERROR_INVALID_DOMAIN: string = '域名格式不正确'
  static readonly ERROR_INVALID_DNS: string = 'DNS 地址格式不正确'
  static readonly ERROR_CANNOT_GET_STATUS: string = '无法获取该用户当前防火墙策略'

  static buildApplyModeSuccess(ruleCount: number): string {
    return `策略下发成功，本次下发 ${ruleCount} 条规则`
  }
}

// ==================== 设备详情对话框文本 ====================
export class DeviceDetailStrings {
  // Dialog structure
  static readonly TITLE: string = '设备详情'
  static readonly KEY_INFO: string = '关键信息'
  static readonly HISTORY_TITLE: string = '历史连接记录'
  static readonly NO_HISTORY: string = '暂无历史连接记录'
  static readonly NO_RECORDS: string = '当前没有可展示的连接记录'
  static readonly HISTORY_COUNT_SUFFIX: string = '条'
  
  // 指标字段标签
  static readonly DEVICE_ID: string = '设备标识'
  static readonly RECENT_TIME: string = '最近时间'
  static readonly CONNECTION_EVENT: string = '连接事件'
  static readonly EVENT_SOURCE: string = '事件来源'
  static readonly POLICY_RESULT: string = '策略结论'
  static readonly EFFECTIVE_POLICY: string = '执行策略'
  static readonly MATCH_TYPE: string = '命中类型'
  static readonly RESULT_STATUS: string = '结果状态'
}

// Shared device type labels reused by records and policy views.
export class DeviceTypeLabels {
  static readonly USB_STORAGE: string = 'USB 存储设备'
  static readonly USB_CAMERA: string = 'USB 摄像头'
  static readonly USB_PRINTER: string = 'USB 打印机'
  static readonly USB_HID: string = 'USB 人机输入设备'
  static readonly USB_OTHER: string = 'USB 其他设备'
  static readonly BLUETOOTH: string = '蓝牙设备'
}
