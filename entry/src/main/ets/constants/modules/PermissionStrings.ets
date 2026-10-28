import { AppStrings } from '../AppStrings'

/**
 * 权限管理模块文案资源门面
 *
 * 文案唯一来源为 resources/{base,en_US}/element/string.json 中的 permission_* 资源，
 * 经 AppStrings 资源管理器按当前 locale 解析。
 *
 * 单元测试环境（AppStrings 未初始化）下门面返回资源名；相关断言必须经门面
 * 构造，不得断言中文或英文字面量。`ApplicationInventoryRepository` 中匹配系统
 * 应用中文名的过滤关键字属于数据，不在此门面范围内。
 */

export class PermissionSectionStrings {

  static get TARGET_APPLICATION_PLACEHOLDER(): string {
    return AppStrings.get('permission_section_target_application_placeholder')
  }

}

export class PermissionAccountStrings {

  static get NO_ACCOUNTS(): string {
    return AppStrings.get('permission_account_no_accounts')
  }
}

export class PermissionSummaryStrings {
  static get ACCOUNTS_TITLE(): string {
    return AppStrings.get('permission_summary_accounts_title')
  }

  static get ACCOUNTS_DESC(): string {
    return AppStrings.get('permission_summary_accounts_desc')
  }

  static get APPLICATIONS_TITLE(): string {
    return AppStrings.get('permission_summary_applications_title')
  }

  static get APPLICATIONS_DESC(): string {
    return AppStrings.get('permission_summary_applications_desc')
  }

  static get POLICIES_TITLE(): string {
    return AppStrings.get('permission_summary_policies_title')
  }

  static get POLICIES_DESC(): string {
    return AppStrings.get('permission_summary_policies_desc')
  }
}

export class PermissionEmptyStrings {
  static get APPLICATIONS(): string {
    return AppStrings.get('permission_empty_applications')
  }

  static get SELECT_APPLICATION_FIRST(): string {
    return AppStrings.get('permission_empty_select_application_first')
  }

}

export class PermissionLoadingStrings {
  static get ACCOUNT_SWITCH(): string {
    return AppStrings.get('permission_loading_account_switch')
  }
}

export class PermissionApplicationStrings {

  static readonly INSTALL_BLOCK_PLACEHOLDER: string = 'appId / appIdentifier'

  static get INSTALL_BLOCK_ACTION(): string {
    return AppStrings.get('permission_application_install_block_action')
  }

  static get POLICY_TYPE_INSTALL_DENY(): string {
    return AppStrings.get('permission_application_policy_type_install_deny')
  }

  static get POLICY_TYPE_INSTALL_ALLOW(): string {
    return AppStrings.get('permission_application_policy_type_install_allow')
  }

  static get POLICY_TYPE_UNINSTALL(): string {
    return AppStrings.get('permission_application_policy_type_uninstall')
  }

  static get POLICY_TYPE_RUNNING(): string {
    return AppStrings.get('permission_application_policy_type_running')
  }

  static get POLICY_TYPE_NETWORK(): string {
    return AppStrings.get('permission_application_policy_type_network')
  }

  static get POLICY_TABLE_TYPE(): string {
    return AppStrings.get('permission_application_policy_table_type')
  }

  static get POLICY_TABLE_TARGET(): string {
    return AppStrings.get('permission_application_policy_table_target')
  }

  static get POLICY_TABLE_STATUS(): string {
    return AppStrings.get('permission_application_policy_table_status')
  }

  static get POLICY_TABLE_SCOPE(): string {
    return AppStrings.get('permission_application_policy_table_scope')
  }

  static get POLICY_TABLE_ACTION(): string {
    return AppStrings.get('permission_application_policy_table_action')
  }

  static get DELETE_POLICY_CONFIRM_TITLE(): string {
    return AppStrings.get('permission_application_delete_policy_confirm_title')
  }

  static get DELETE_POLICY_CONFIRM_MESSAGE(): string {
    return AppStrings.get('permission_application_delete_policy_confirm_message')
  }

  static get POLICY_TARGET_NOT_INSTALLED(): string {
    return AppStrings.get('permission_application_policy_target_not_installed')
  }

  static get POLICY_SCOPE_ACCOUNT_PREFIX(): string {
    return AppStrings.get('permission_application_policy_scope_account_prefix')
  }

  static get UNINSTALL_PROTECTED_DESC(): string {
    return AppStrings.get('permission_application_uninstall_protected_desc')
  }

  static get RUNNING_POLICY_DESC(): string {
    return AppStrings.get('permission_application_running_policy_desc')
  }

  static get NETWORK_POLICY_DESC(): string {
    return AppStrings.get('permission_application_network_policy_desc')
  }

  static get CURRENT_STATE_PREFIX(): string {
    return AppStrings.get('permission_application_current_state_prefix')
  }

  static get THREE_D_GROUP_DESC(): string {
    return AppStrings.get('permission_application_three_d_group_desc')
  }

  static get THREE_D_FULL_FILE_DESC(): string {
    return AppStrings.get('permission_application_three_d_full_file_desc')
  }

  static get POLICY_DEFAULT(): string {
    return AppStrings.get('permission_application_policy_default')
  }

  static get POLICY_ALLOWED(): string {
    return AppStrings.get('permission_application_policy_allowed')
  }

  static get POLICY_DENIED(): string {
    return AppStrings.get('permission_application_policy_denied')
  }

  static get ENABLED(): string {
    return AppStrings.get('permission_application_enabled')
  }

  static get DISABLED(): string {
    return AppStrings.get('permission_application_disabled')
  }

  static get SET_SUCCESS(): string {
    return AppStrings.get('permission_application_set_success')
  }

  static get SET_FAILED(): string {
    return AppStrings.get('permission_application_set_failed')
  }

  static get POLICY_READ_FAILED(): string {
    return AppStrings.get('permission_application_policy_read_failed')
  }

  static get ACCOUNT_CONTEXT_CHANGED(): string {
    return AppStrings.get('permission_application_account_context_changed')
  }

  static get APPLICATION_CONTEXT_CHANGED(): string {
    return AppStrings.get('permission_application_application_context_changed')
  }

  static get POLICY_CONTEXT_CHANGED(): string {
    return AppStrings.get('permission_application_policy_context_changed')
  }

  static get INSTALL_BLOCK_EMPTY(): string {
    return AppStrings.get('permission_application_install_block_empty')
  }

  static get INSTALL_BLOCK_INVALID(): string {
    return AppStrings.get('permission_application_install_block_invalid')
  }

  static get MISSING_UID(): string {
    return AppStrings.get('permission_application_missing_uid')
  }

  static get THREE_D_UNDECLARED(): string {
    return AppStrings.get('permission_application_three_d_undeclared')
  }

  static get THREE_D_UNSUPPORTED(): string {
    return AppStrings.get('permission_application_three_d_unsupported')
  }
}

export class PermissionThreeDStrings {
  static get DOWNLOADS(): string {
    return AppStrings.get('permission_three_d_downloads')
  }

  static get DOWNLOADS_DESC(): string {
    return AppStrings.get('permission_three_d_downloads_desc')
  }

  static get DESKTOP(): string {
    return AppStrings.get('permission_three_d_desktop')
  }

  static get DESKTOP_DESC(): string {
    return AppStrings.get('permission_three_d_desktop_desc')
  }

  static get DOCUMENTS(): string {
    return AppStrings.get('permission_three_d_documents')
  }

  static get DOCUMENTS_DESC(): string {
    return AppStrings.get('permission_three_d_documents_desc')
  }

  static get NO_DECLARED(): string {
    return AppStrings.get('permission_three_d_no_declared')
  }

  static get DETAIL_LOADING(): string {
    return AppStrings.get('permission_three_d_detail_loading')
  }

  static get DETAIL_FAILED(): string {
    return AppStrings.get('permission_three_d_detail_failed')
  }
}
