export class PermissionErrorStrings {
  static readonly missingUserListPermission: string = '缺少系统用户列表读取权限'
  static readonly missingAccountOrFirewallPermission: string = '缺少账户或防火墙管理权限'
  static readonly invalidUserIdParam: string = '用户 ID 参数不合法'
}

export class AdminErrorStrings {
  static buildCheckFailed(code?: number): string {
    return code !== undefined ? `管理员状态检查失败（错误码 ${code}）` : '管理员状态检查失败'
  }
}

export class SystemServiceErrorStrings {
  static readonly accountServiceConnectionFailed: string = '系统账号服务连接失败'
  static readonly serviceConnectionFailed: string = '系统服务连接失败'
  static readonly internalError: string = '系统内部错误'
  static readonly userNotExistOrInvalid: string = '目标用户不存在或已失效'
}

export class ErrorTemplates {
  static readonly actionFailedTemplate: string = '${action}失败'
}
