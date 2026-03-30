/**
 * 错误消息字符串常量
 * 
 * 统一管理所有错误提示消息，包括：
 * - 权限相关错误
 * - 系统服务错误
 * - 参数验证错误
 * - 业务逻辑错误
 */

// ==================== 权限相关错误 ====================
export class PermissionErrors {
  // 用户列表读取
  static readonly READ_USER_LIST: string = '读取用户列表'
  static readonly MISSING_USER_LIST_PERMISSION: string = '缺少系统用户列表读取权限'
  
  // 账户/防火墙管理
  static readonly MISSING_ACCOUNT_OR_FIREWALL_PERMISSION: string = '缺少账户或防火墙管理权限'
  
  // 用户 ID 参数
  static readonly INVALID_USER_ID_PARAM: string = '用户 ID 参数不合法'
}

// ==================== 系统服务错误 ====================
export class SystemServiceErrors {
  // 账号服务
  static readonly ACCOUNT_SERVICE_CONNECTION_FAILED: string = '系统账号服务连接失败'
  
  // 通用服务
  static readonly SERVICE_CONNECTION_FAILED: string = '系统服务连接失败'
  static readonly INTERNAL_ERROR: string = '系统内部错误'
  
  // 用户状态
  static readonly USER_NOT_EXIST_OR_INVALID: string = '目标用户不存在或已失效'
}

// ==================== 日志导出错误 ====================
export class LogExportErrors {
  static readonly NO_LOGS_TO_EXPORT: string = '无日志可导出'
  static readonly UI_CONTEXT_UNAVAILABLE: string = 'UI 上下文不可用'
  static readonly USER_CANCELED_SAVE: string = '用户取消保存'
  static readonly EXPORT_FAILED_PREFIX: string = '导出失败：'
}

// ==================== 通用错误模板 ====================
export class ErrorTemplates {
  static readonly ACTION_FAILED_TEMPLATE: string = '${action}失败'
  static readonly ERROR_WITH_CODE_TEMPLATE: string = '${message}（错误码 ${code}）'
  static readonly EXPORT_FAILED_TEMPLATE: string = '导出失败：${detail}'
}
