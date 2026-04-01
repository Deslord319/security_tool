/**
 * 路由与页面级标识常量。
 * 路由相关场景统一复用同一套 id，避免 dashboard / quick-entry 再派生一层重复常量。
 */
export class RouteIds {
  static readonly DASHBOARD = 'dashboard'
  static readonly FIREWALL = 'firewall'
  static readonly FIREWALL_RULES = 'firewall-rules'
  static readonly LOG_MANAGE = 'log-manage'
  static readonly PERIPHERAL_MANAGE = 'peripheral-manage'
  static readonly IDENTITY = 'identity'
  static readonly TOOL_SETTINGS = 'tool-settings'
  static readonly HELP_FEEDBACK = 'help-feedback'

  static readonly ADMIN = 'admin'
}
