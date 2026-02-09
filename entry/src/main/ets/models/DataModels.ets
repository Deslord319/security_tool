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
