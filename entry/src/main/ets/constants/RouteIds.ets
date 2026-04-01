/**
 * 路由 ID 常量
 * 避免在代码中硬编码路由字符串
 * 
 * 使用示例:
 * ```ets
 * import { RouteIds } from '../constants/RouteIds'
 * router.pushUrl({ url: RouteIds.DASHBOARD })
 * ```
 */
export class RouteIds {
  // ==================== 主路由 ====================
  static readonly DASHBOARD = 'dashboard'
  static readonly FIREWALL = 'firewall'
  static readonly FIREWALL_RULES = 'firewall-rules'
  static readonly LOG_MANAGE = 'log-manage'
  static readonly PERIPHERAL_MANAGE = 'peripheral-manage'
  static readonly IDENTITY = 'identity'
  static readonly TOOL_SETTINGS = 'tool-settings'
  static readonly HELP_FEEDBACK = 'help-feedback'
  
  // ==================== Dashboard 模块卡片 ID ====================
  static readonly MODULE_ADMIN = 'admin'
  static readonly MODULE_FIREWALL = 'firewall'
  static readonly MODULE_LOG = 'log'
  static readonly MODULE_PERIPHERAL = 'peripheral'
  
  // ==================== 快捷入口 ID ====================
  static readonly ENTRY_FIREWALL = 'firewall'
  static readonly ENTRY_LOG = 'log'
  static readonly ENTRY_PERIPHERAL = 'peripheral'
  static readonly ENTRY_IDENTITY = 'identity'
  static readonly ENTRY_TOOL_SETTINGS = 'tool-settings'
  static readonly ENTRY_HELP_FEEDBACK = 'help-feedback'
}
