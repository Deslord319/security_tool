/**
 * 工具设置模块文案资源门面
 *
 * 文案唯一来源为 resources/{base,en_US}/element/string.json 中的 tool_settings_* 资源。
 * 门面保持与旧常量一致的访问方式，内部经 AppStrings 资源管理器按当前 locale 解析。
 *
 * 单元测试环境（AppStrings 未初始化）下门面返回资源名；相关断言必须经门面构造，
 * 不得断言中文或英文字面量。模块顶层常量不得在 AppStrings.init 之前读取本门面。
 */
import { AppStrings } from '../AppStrings'

export class ToolSettingsPageStrings {

  static get SAVE_SUCCESS(): string {
    return AppStrings.get('tool_settings_page_save_success')
  }

  static get OPEN_PASSWORD_SETTINGS_FAILED(): string {
    return AppStrings.get('tool_settings_page_open_password_settings_failed')
  }
}

export class ToolSettingsConfirmationStrings {
  static get AUTH_METHOD_UNAVAILABLE_TITLE(): string {
    return AppStrings.get('tool_settings_confirmation_auth_method_unavailable_title')
  }

  static get AUTH_METHOD_UNAVAILABLE_MESSAGE(): string {
    return AppStrings.get('tool_settings_confirmation_auth_method_unavailable_message')
  }

  static get CONTINUE_SAVE(): string {
    return AppStrings.get('tool_settings_confirmation_continue_save')
  }
}
