export class ToolSettingsPageStrings {
  static readonly SUBTITLE: string = '配置启动认证与系统密码修改入口等工具级安全能力'
  static readonly SAVE_SUCCESS: string = '工具设置已保存'
  static readonly OPEN_PASSWORD_SETTINGS_FAILED: string = '无法打开系统密码设置，请手动前往系统设置修改'
}

export class ToolSettingsStartupAuthStrings {
  static readonly SECTION_TITLE: string = '启动认证设置'
  static readonly TITLE: string = '启动时身份校验'
  static readonly DESCRIPTION: string = '开启后，进入工具前需要先完成系统认证'
  static readonly AUTH_METHOD_DESCRIPTION: string = '选择启动时身份校验使用的系统认证方式'
}

export class ToolSettingsPasswordStrings {
  static readonly CHANGE_LABEL: string = '修改密码'
  static readonly CHANGE_DESCRIPTION: string = '打开系统设置中的“生物识别和密码”，修改系统 PIN/密码'
}

export class ToolSettingsConfirmationStrings {
  static readonly AUTH_METHOD_UNAVAILABLE_TITLE: string = '认证方式不可用'
  static readonly AUTH_METHOD_UNAVAILABLE_MESSAGE: string = '继续保存后，启动时身份校验可能无法正常工作，请确认是否仍要保存设置'
  static readonly CONTINUE_SAVE: string = '仍然保存'
}
