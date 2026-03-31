/**
 * 日志 DOMAIN 常量
 * 统一管理各模块的 hilog DOMAIN 值
 * 
 * 使用示例:
 * ```ets
 * import { LogDomains } from '../constants/LogDomains'
 * const DOMAIN = LogDomains.TOOL_SETTINGS
 * hilog.info(DOMAIN, TAG, 'message')
 * ```
 */
export class LogDomains {
  /** 通用/测试 */
  static readonly COMMON = 0x0000
  
  /** 防火墙服务 */
  static readonly FIREWALL = 0x0001
  
  /** 外设管理服务 */
  static readonly PERIPHERAL = 0x0002
  
  /** 身份鉴别页面 */
  static readonly IDENTITY = 0x0011
  
  /** 工具设置（页面、ViewModel、Repository） */
  static readonly TOOL_SETTINGS = 0x0014
  
  /** 仪表盘 ViewModel */
  static readonly DASHBOARD = 0x0014
  
  /** 日志服务 */
  static readonly LOG = 0x0006
}
