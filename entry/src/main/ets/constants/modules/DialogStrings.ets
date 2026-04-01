
/**
 * 对话框通用字符串常量
 * 
 * 统一管理所有对话框组件中的硬编码文字，包括：
 * - 对话框标题
 * - 按钮文本
 * - 提示信息
 * - 状态文本
 */

// ==================== 通用对话框按钮文本 ====================
export class DialogButtonStrings {
  static readonly CONFIRM: string = '确定'
  static readonly CANCEL: string = '取消'
  static readonly CLOSE: string = '关闭'
  static readonly SAVE: string = '保存'
  static readonly DELETE: string = '删除'
  static readonly EDIT: string = '编辑'
  static readonly ADD: string = '添加'
  static readonly OK: string = '好的'
}

// ==================== 加载状态文本 ====================
export class LoadingStrings {
  static readonly LOADING: string = '加载中...'
  static readonly LOADING_USERS: string = '正在加载用户列表...'
  static readonly LOADING_RULES: string = '正在加载规则...'
  static readonly LOADING_POLICY: string = '正在读取防火墙状态...'
  static readonly APPLYING_MODE: string = '正在应用防火墙模式...'
  static readonly SAVING: string = '正在保存...'
  static readonly SUBMITTING: string = '正在提交...'
}

// ==================== 空状态提示 ====================
export class EmptyStateStrings {
  static readonly NO_DATA: string = '暂无数据'
  static readonly NO_USERS: string = '暂无可选用户'
  static readonly NO_RECORDS: string = '暂无连接记录'
  static readonly NO_HISTORY: string = '暂无历史记录'
  static readonly NO_RULES: string = '暂无自定义规则'
  static readonly NO_DEVICES: string = '暂无可管理的设备'
  static readonly NO_RESULTS: string = '未找到相关结果'
  static readonly CHECK_PERMISSIONS: string = '请检查账户权限或系统账户状态'
}

// ==================== 成功/失败提示 ====================
export class ResultStrings {
  static readonly SUCCESS: string = '成功'
  static readonly FAILED: string = '失败'
  static readonly SAVE_SUCCESS: string = '保存成功'
  static readonly SAVE_FAILED: string = '保存失败'
  static readonly DELETE_SUCCESS: string = '删除成功'
  static readonly ADD_SUCCESS: string = '添加成功'
  static readonly UPDATE_SUCCESS: string = '更新成功'
}

export class CommonLabelStrings {
  static readonly ALL: string = '全部'
  static readonly UNKNOWN: string = '未知'
}

export class FirewallRuleLabelStrings {
  static readonly ALL_RULES: string = '全部规则'
  static readonly IP_RULE: string = 'IP规则'
  static readonly DOMAIN_RULE: string = '域名规则'
  static readonly DNS_RULE: string = 'DNS规则'
}

// ==================== 验证错误提示 ====================
export class ValidationErrorStrings {
  static readonly PIN_FAILED: string = 'PIN 验证失败，已取消本次变更'
  static readonly PIN_UNAVAILABLE: string = '系统 PIN 认证暂不可用'
  static readonly PIN_LOCKOUT_MESSAGE: string = 'PIN 认证失败次数过多，请在'
  static readonly PIN_LOCKOUT_SUFFIX: string = '秒后重试'
  static readonly POLICY_FAILED: string = '防火墙状态更新失败'
  static readonly NETWORK_FAILED: string = '网络操作失败'
  static readonly PERMISSION_DENIED: string = '权限不足'
  static readonly STATUS_UNKNOWN: string = '状态未知'
  static readonly PLEASE_READ_STATUS_FIRST: string = '请先读取状态'
}

// ==================== 防火墙相关文本 ====================
export class FirewallDialogStrings {
  // 标题
  static readonly ADD_RULE_TITLE: string = '新增规则'
  static readonly EDIT_RULE_TITLE: string = '编辑规则'
  static readonly USER_FIREWALL_TITLE: string = '模式下发'
  
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
  static readonly CURRENT_MODE: string = '当前模式'
  static readonly TARGET_MODE: string = '目标模式'
  
  // 占位符
  static readonly IP_PLACEHOLDER: string = '例如 0.0.0.0/0'
  static readonly DOMAIN_PLACEHOLDER: string = '例如 *.example.com'
  static readonly DNS_PLACEHOLDER: string = '例如 8.8.8.8'
  static readonly PORT_PLACEHOLDER: string = '例如 443'
  static readonly RULE_NAME_PLACEHOLDER: string = '请输入规则名称'
  
  // 规则类型标签
  static readonly RULE_TYPE_IP: string = FirewallRuleLabelStrings.IP_RULE
  static readonly RULE_TYPE_DOMAIN: string = FirewallRuleLabelStrings.DOMAIN_RULE
  static readonly RULE_TYPE_DNS: string = FirewallRuleLabelStrings.DNS_RULE
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
  
  // 按钮
  static readonly APPLY_MODE: string = '下发策略'
  
  // 状态文本
  static readonly MODE_ALLOWLIST: string = '白名单模式'
  static readonly MODE_DENYLIST: string = '黑名单模式'
  static readonly MODE_NON_STANDARD: string = '非标准模式'
  static readonly MODE_UNMANAGED: string = '未纳管'
  
  // 验证错误
  static readonly ERROR_RULE_NAME_REQUIRED: string = FirewallDialogStrings.RULE_NAME_PLACEHOLDER
  static readonly ERROR_DOMAIN_REQUIRED: string = '请输入域名'
  static readonly ERROR_DNS_REQUIRED: string = '请输入 DNS 地址'
  static readonly ERROR_IP_REQUIRED: string = '请输入远端 IP 或 CIDR'
  static readonly ERROR_INVALID_IP: string = '远端 IP 或 CIDR 格式不正确'
  static readonly ERROR_INVALID_LOCAL_PORT: string = '本地端口范围必须为 1-65535'
  static readonly ERROR_INVALID_REMOTE_PORT: string = '远端端口范围必须为 1-65535'
  static readonly ERROR_INVALID_DOMAIN: string = '域名格式不正确'
  static readonly ERROR_INVALID_DNS: string = 'DNS 地址格式不正确'
  static readonly ERROR_CANNOT_GET_STATUS: string = '无法获取该用户当前防火墙策略'
  static readonly ERROR_PLEASE_READ_STATUS: string = '请先选择并读取有效用户状态'
  
  // 描述文本
  static readonly USER_FIREWALL_DESCRIPTION: string = '选择目标 userId 后，为该用户下发自定义模式。白名单模式默认双向拒绝，只放行允许规则；黑名单模式默认双向允许，只阻止禁止规则；非标准模式只下发手动维护的规则，不修改默认入/出站策略。执行前需要完成 PIN 认证。'

  static buildPolicySummary(isOpen: boolean, inboundAction: string, outboundAction: string): string {
    let switchStatus = isOpen ? FirewallDialogStrings.SWITCH_ENABLED : FirewallDialogStrings.SWITCH_DISABLED
    return `主开关${switchStatus}，默认入站${inboundAction}，默认出站${outboundAction}`
  }

  static buildApplyModeSuccess(ruleCount: number): string {
    return `策略下发成功，本次下发 ${ruleCount} 条规则`
  }
}

// ==================== 设备详情对话框文本 ====================
export class DeviceDetailStrings {
  static readonly TITLE: string = '设备详情'
  static readonly CLOSE_BUTTON: string = DialogButtonStrings.CLOSE
  static readonly KEY_INFO: string = '关键信息'
  static readonly HISTORY_TITLE: string = '历史连接记录'
  static readonly NO_HISTORY: string = '暂无历史连接记录'
  static readonly NO_RECORDS: string = '当前没有可展示的连接记录。'
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

// ==================== 通用提示文本 ====================
export class HintStrings {
  static readonly CHECK_PERMISSIONS: string = EmptyStateStrings.CHECK_PERMISSIONS
  static readonly PLEASE_SELECT: string = '请选择'
  static readonly PLEASE_ENTER: string = '请输入'
  static readonly CONFIRM_DELETE: string = '确认删除吗？'
  static readonly CONFIRM_ACTION: string = '确认执行此操作吗？'
}

// ==================== 设备列表相关 ====================
export class DeviceEmptyStates {
  static readonly NO_DEVICE_RECORDS: string = '暂无设备连接记录'
  static readonly DEVICE_RECORDS_EMPTY_DESC: string = '重新连接设备后，可在这里查看最新的接入历史。'
  static readonly NO_MANAGEABLE_USB_DEVICES: string = '暂无可管理的 USB 设备记录'
  static readonly USB_DEVICES_EMPTY_DESC: string = '设备接入后会显示在这里，可直接设置允许接入或禁止接入。'
}

export class DeviceTypeLabels {
  static readonly USB_STORAGE: string = 'USB 存储设备'
  static readonly USB_CAMERA: string = 'USB 摄像头'
  static readonly USB_PRINTER: string = 'USB 打印机'
  static readonly USB_HID: string = 'USB 人机输入设备'
  static readonly USB_OTHER: string = 'USB 其他设备'
}

export class PinErrorStrings {
  static readonly PIN_VERIFICATION_FAILED: string = ValidationErrorStrings.PIN_FAILED
}
