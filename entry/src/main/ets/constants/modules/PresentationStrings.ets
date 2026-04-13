export class FirewallActionPresentationStrings {
  static readonly DENY: string = '拒绝'
}

export class PeripheralSourcePresentationStrings {
  static readonly RUNTIME_EVENT: string = '运行时事件'
  static readonly AUDIT_EVENT: string = '审计事件'
  static readonly POLICY_SNAPSHOT: string = '策略快照'
  static readonly UNKNOWN: string = '未知来源'
}

export class PeripheralRecordActionPresentationStrings {
  static readonly CONNECT: string = '连接'
  static readonly DISCONNECT: string = '断开'
  static readonly DISCOVER: string = '发现'
  static readonly INTERCEPT: string = '拦截'
  static readonly UNKNOWN: string = '未知动作'
}

export class LogEventPresentationStrings {
  static readonly CRASH: string = '崩溃日志'
  static readonly FILE: string = '文件操作'
  static readonly ACCOUNT: string = '用户认证'
  static readonly PERMISSION: string = '权限变更'
}

export class LogResultPresentationStrings {
  static readonly BLOCKED: string = '已阻止'
}
