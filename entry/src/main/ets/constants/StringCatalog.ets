export class AppText {
  static readonly NAME: string = '安全管理中心'
  static readonly ABOUT: string = '关于'
  static readonly VERSION: string = '版本'
  static readonly COPYRIGHT: string = 'Copyright 2026'
}

export const PLACEHOLDER_TEXT: string = '--'

export class ModuleText {
  static readonly DASHBOARD: string = '安全总览'
  static readonly FIREWALL: string = '防火墙管理'
  static readonly LOG_MANAGE: string = '日志管理'
  static readonly PERIPHERAL_MANAGE: string = '外设管理'
  static readonly IDENTITY: string = '身份鉴别'
  static readonly TOOL_SETTINGS: string = '工具设置'
  static readonly HELP_FEEDBACK: string = '帮助与反馈'
}

export class StatusText {
  static readonly ACTIVATED: string = '已激活'
  static readonly CURRENT_MODE: string = '当前模式'
  static readonly EFFECTIVE: string = '已生效'
  static readonly ENABLED: string = '已启用'
  static readonly DISABLED: string = '已禁用'
}

export class ActionText {
  static readonly SAVE_CONFIG: string = '保存配置'
  static readonly SAVE_SETTINGS: string = '保存设置'
  static readonly SAVE: string = '保存'
  static readonly CANCEL: string = '取消'
  static readonly CONTINUE: string = '继续'
  static readonly DELETE: string = '删除'
  static readonly CLEAR: string = '清理'
  static readonly OVERRIDE: string = '覆盖'
  static readonly ACKNOWLEDGE: string = '我知道了'
  static readonly CONFIRM: string = '确定'
  static readonly CLOSE: string = '关闭'
  static readonly ADD: string = '添加'
  static readonly PREVIOUS_PAGE: string = '上一页'
  static readonly NEXT_PAGE: string = '下一页'
  static readonly JUMP: string = '跳转'
}

export class MessageText {
  static readonly NO_CHANGES: string = '当前没有需要保存的更改'
  static readonly SAVE_FAILED: string = '保存失败，请稍后重试'
  static readonly RETRY_LATER: string = '请稍后重试'
  static readonly SUCCESS_TITLE: string = '操作成功'
  static readonly FAILURE_TITLE: string = '操作失败'
}

export class LabelText {
  static readonly ALL: string = '全部'
  static readonly UNKNOWN: string = '未知'
  static readonly TIME: string = '时间'
  static readonly DETAIL: string = '详情'
  static readonly AUTH_METHOD: string = '认证方式'
}

export class ResultText {
  static readonly SUCCESS: string = '成功'
  static readonly FAILED: string = '失败'
  static readonly SAVE_FAILED: string = '保存失败'
}

export class ThemeText {
  static readonly SECTION_TITLE: string = '显示模式'
  static readonly FOLLOW_SYSTEM: string = '跟随系统'
  static readonly LIGHT_MODE: string = '浅色模式'
  static readonly DARK_MODE: string = '深色模式'
}

export class StorageAccessText {
  static readonly READ_WRITE: string = '读写'
  static readonly READ_ONLY: string = '只读'
  static readonly BLOCKED: string = '禁止访问'
}

export class AdminText {
  static readonly NOT_ACTIVATED: string = '企业管理员未激活'

  static buildCheckFailed(code?: number): string {
    return code !== undefined ? `管理员状态检查失败（错误码 ${code}）` : '管理员状态检查失败'
  }
}
