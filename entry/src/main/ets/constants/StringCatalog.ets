import { AppStrings } from './AppStrings'

/**
 * 公共文案资源门面
 *
 * 文案唯一来源为 resources/{base,en_US}/element/string.json 中的 common_* 资源，
 * 经 AppStrings 资源管理器按当前 locale 解析。版权声明等 locale 无关字面量保留常量。
 *
 * 单元测试环境（AppStrings 未初始化）下门面返回资源名；相关断言必须经门面
 * 构造，不得断言中文或英文字面量。模块顶层常量不得在 AppStrings.init 之前
 * 读取本门面（如侧边栏 NAV_ITEMS 已改为惰性函数）。
 */
export class AppText {
  static get NAME(): string {
    return AppStrings.get('common_app_name')
  }

  static get ABOUT(): string {
    return AppStrings.get('common_about')
  }


  static readonly COPYRIGHT: string = 'Copyright 2026'
}

export const PLACEHOLDER_TEXT: string = '--'

export class ModuleText {
  static get DASHBOARD(): string {
    return AppStrings.get('common_module_dashboard')
  }

  static get FIREWALL(): string {
    return AppStrings.get('common_module_firewall')
  }

  static get LOG_MANAGE(): string {
    return AppStrings.get('common_module_log_manage')
  }

  static get PERIPHERAL_MANAGE(): string {
    return AppStrings.get('common_module_peripheral_manage')
  }

  static get PERMISSION_MANAGE(): string {
    return AppStrings.get('common_module_permission_manage')
  }

  static get IDENTITY(): string {
    return AppStrings.get('common_module_identity')
  }

  static get TOOL_SETTINGS(): string {
    return AppStrings.get('common_module_tool_settings')
  }

  static get HELP_FEEDBACK(): string {
    return AppStrings.get('common_module_help_feedback')
  }
}

export class StatusText {
  static get ACTIVATED(): string {
    return AppStrings.get('common_status_activated')
  }



  static get ENABLED(): string {
    return AppStrings.get('common_status_enabled')
  }

  static get DISABLED(): string {
    return AppStrings.get('common_status_disabled')
  }
}

export class ActionText {
  static get SAVE_CONFIG(): string {
    return AppStrings.get('common_action_save_config')
  }


  static get SAVE(): string {
    return AppStrings.get('common_action_save')
  }

  static get CANCEL(): string {
    return AppStrings.get('common_action_cancel')
  }

  static get CONTINUE(): string {
    return AppStrings.get('common_action_continue')
  }

  static get DELETE(): string {
    return AppStrings.get('common_action_delete')
  }

  static get CLEAR(): string {
    return AppStrings.get('common_action_clear')
  }

  static get RESTORE(): string {
    return AppStrings.get('common_action_restore')
  }

  static get OVERRIDE(): string {
    return AppStrings.get('common_action_override')
  }

  static get ACKNOWLEDGE(): string {
    return AppStrings.get('common_action_acknowledge')
  }

  static get CONFIRM(): string {
    return AppStrings.get('common_action_confirm')
  }


  static get ADD(): string {
    return AppStrings.get('common_action_add')
  }



}

export class MessageText {
  static get NO_CHANGES(): string {
    return AppStrings.get('common_message_no_changes')
  }

  static get SAVE_FAILED(): string {
    return AppStrings.get('common_message_save_failed')
  }

  static get RETRY_LATER(): string {
    return AppStrings.get('common_message_retry_later')
  }

  static get SUCCESS_TITLE(): string {
    return AppStrings.get('common_message_success_title')
  }

  static get FAILURE_TITLE(): string {
    return AppStrings.get('common_message_failure_title')
  }
}

export class LabelText {
  static get UNKNOWN(): string {
    return AppStrings.get('common_label_unknown')
  }

  static get TIME(): string {
    return AppStrings.get('common_label_time')
  }

  static get DETAIL(): string {
    return AppStrings.get('common_label_detail')
  }

  static get AUTH_METHOD(): string {
    return AppStrings.get('common_label_auth_method')
  }
}

export class ResultText {
  static get SUCCESS(): string {
    return AppStrings.get('common_result_success')
  }

  static get FAILED(): string {
    return AppStrings.get('common_result_failed')
  }

  static get SAVE_FAILED(): string {
    return AppStrings.get('common_result_save_failed')
  }
}

export class ThemeText {

  static get FOLLOW_SYSTEM(): string {
    return AppStrings.get('common_theme_follow_system')
  }

  static get LIGHT_MODE(): string {
    return AppStrings.get('common_theme_light')
  }

  static get DARK_MODE(): string {
    return AppStrings.get('common_theme_dark')
  }
}

export class StorageAccessText {
  static get READ_WRITE(): string {
    return AppStrings.get('common_storage_read_write')
  }

  static get READ_ONLY(): string {
    return AppStrings.get('common_storage_read_only')
  }

  static get BLOCKED(): string {
    return AppStrings.get('common_storage_blocked')
  }
}

export class AdminText {
  static get NOT_ACTIVATED(): string {
    return AppStrings.get('common_admin_not_activated')
  }

  static buildCheckFailed(code?: number): string {
    return code !== undefined ?
      AppStrings.format('common_admin_check_failed_with_code', code) :
      AppStrings.get('common_admin_check_failed')
  }
}
