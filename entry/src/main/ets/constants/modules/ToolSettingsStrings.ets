import { CommonStrings } from '../CommonStrings'

export class ToolSettingsStrings {
  static readonly pageTitle: string = CommonStrings.moduleToolSettings
  static readonly pageSubtitle: string = '配置启动认证与系统密码修改入口等工具级安全能力'
  static readonly saveButton: string = CommonStrings.actionSaveSettings
  static readonly saveSuccess: string = '工具设置已保存'
  static readonly openPasswordSettingsFailed: string = '无法打开系统密码设置，请手动前往系统设置修改'

  static readonly sectionStartupAuth: string = '启动认证设置'
  static readonly startupAuthTitle: string = '启动时身份校验'
  static readonly startupAuthDesc: string = '开启后，进入工具前需要先完成系统认证'
  static readonly authMethodTitle: string = '认证方式'
  static readonly authMethodDesc: string = '选择启动时身份校验使用的系统认证方式'
  static readonly changePasswordLabel: string = '修改密码'
  static readonly changePasswordDesc: string = '打开系统设置中的“生物识别和密码”，修改系统 PIN/密码'

  static readonly authMethodUnavailableTitle: string = '认证方式不可用'
  static readonly authMethodUnavailableMessage: string = '继续保存后，启动时身份校验可能无法正常工作，请确认是否仍要保存设置。'
  static readonly continueSave: string = '仍然保存'
}
