import { CommonStrings } from '../CommonStrings'

export class DashboardStrings {
  static readonly pageTitle: string = CommonStrings.moduleDashboard
  static readonly pageSubtitle: string = 'HarmonyOS 安全管理中心，提供企业级设备安全管控能力。'
  static readonly quickActionsTitle: string = '快捷功能'

  static readonly healthAdminLabel: string = '管理员'

  static readonly statFirewallStatus: string = '防火墙状态'
  static readonly statFirewallEnabled: string = '已开启'
  static readonly statFirewallDisabled: string = '已关闭'
  static readonly statTodayAuditEvents: string = '今日审计事件'
  static readonly statBlockedEvents: string = '已阻止事件'
  static readonly statTotalLogs: string = '日志总量'
}
