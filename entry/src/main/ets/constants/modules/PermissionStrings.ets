export class PermissionPageStrings {
  static readonly SUBTITLE: string = '按账号查看应用级安装、运行、目录和网络管控状态'
}

export class PermissionSectionStrings {
  static readonly ACCOUNT_SCOPE: string = '作用账号'
  static readonly SUMMARY: string = '策略摘要'
  static readonly APPLICATIONS: string = '应用管控对象'
  static readonly APPLICATION_DETAIL: string = '应用详情'
  static readonly TARGET_APPLICATION: string = '目标应用'
  static readonly TARGET_APPLICATION_DESC: string = '选择后下方策略作用于该应用'
  static readonly TARGET_APPLICATION_PLACEHOLDER: string = '请选择应用'
  static readonly CURRENT_POLICIES: string = '当前策略'
  static readonly APPLICATION_CONTROL: string = '应用策略'
  static readonly SIX_D_PERMISSION: string = '6D 权限托管'
}

export class PermissionAccountStrings {
  static readonly SELECT_TITLE: string = '当前账号'
  static readonly SELECT_DESC: string = '策略读取和后续写入均按账号隔离'
  static readonly NO_ACCOUNTS: string = '未获取到可管理账号'
}

export class PermissionSummaryStrings {
  static readonly ACCOUNTS_TITLE: string = '账号'
  static readonly ACCOUNTS_DESC: string = '当前可管理账号'
  static readonly APPLICATIONS_TITLE: string = '应用'
  static readonly APPLICATIONS_DESC: string = '可管控应用'
  static readonly POLICIES_TITLE: string = '策略'
  static readonly POLICIES_DESC: string = '当前已生效'
}

export class PermissionEmptyStrings {
  static readonly APPLICATIONS: string = '当前账号没有可管理的非系统预装应用。'
  static readonly INVENTORY_LOAD_FAILED: string = '应用清单读取失败，请确认企业管理员激活态和应用清单权限。'
  static readonly SEARCH_RESULT: string = '没有匹配的应用。'
  static readonly DETAIL: string = '选择应用后展示基础信息和策略详情。'
  static readonly SELECT_APPLICATION_FIRST: string = '请选择应用。'
  static readonly POLICIES: string = '当前账号暂无已生效策略。'
}

export class PermissionApplicationStrings {
  static readonly BUNDLE_NAME: string = '包名'
  static readonly VERSION_NAME: string = '版本'
  static readonly UID: string = 'UID'
  static readonly UNINSTALL_PROTECTED: string = '卸载保护'
  static readonly RUNNING_POLICY: string = '运行策略'
  static readonly NETWORK_POLICY: string = '网络策略'
  static readonly INSTALL_BLOCK_TARGET: string = '禁止安装应用'
  static readonly INSTALL_BLOCK_TARGET_DESC: string = '输入应用包名，写入禁止安装列表'
  static readonly INSTALL_BLOCK_PLACEHOLDER: string = 'com.example.app'
  static readonly INSTALL_BLOCK_ACTION: string = '禁止安装'
  static readonly POLICY_TYPE_INSTALL_DENY: string = '禁止安装'
  static readonly POLICY_TYPE_INSTALL_ALLOW: string = '允许安装'
  static readonly POLICY_TYPE_UNINSTALL: string = '卸载保护'
  static readonly POLICY_TYPE_RUNNING: string = '运行策略'
  static readonly POLICY_TYPE_NETWORK: string = '网络策略'
  static readonly POLICY_TABLE_TYPE: string = '策略类型'
  static readonly POLICY_TABLE_TARGET: string = '对象'
  static readonly POLICY_TABLE_STATUS: string = '状态'
  static readonly POLICY_TABLE_SCOPE: string = '作用范围'
  static readonly POLICY_TABLE_ACTION: string = '操作'
  static readonly DELETE_POLICY_ACTION: string = '删除'
  static readonly DELETE_POLICY_CONFIRM_TITLE: string = '删除当前策略'
  static readonly DELETE_POLICY_CONFIRM_MESSAGE: string = '删除后将清理系统策略，确认继续？'
  static readonly UNINSTALL_PROTECTED_ENABLE_CONFIRM_TITLE: string = '开启卸载保护'
  static readonly UNINSTALL_PROTECTED_DISABLE_CONFIRM_TITLE: string = '关闭卸载保护'
  static readonly UNINSTALL_PROTECTED_ENABLE_CONFIRM_MESSAGE: string = '开启后将阻止当前账号卸载该应用，确认继续？'
  static readonly UNINSTALL_PROTECTED_DISABLE_CONFIRM_MESSAGE: string = '关闭后当前账号可卸载该应用，确认继续？'
  static readonly POLICY_TARGET_NOT_INSTALLED: string = '未安装应用'
  static readonly POLICY_SCOPE_ACCOUNT_PREFIX: string = '账号'
  static readonly UNINSTALL_PROTECTED_DESC: string = '阻止当前账号卸载该应用'
  static readonly RUNNING_POLICY_DESC: string = '控制应用是否允许启动'
  static readonly NETWORK_POLICY_DESC: string = '控制应用全部网络访问'
  static readonly CURRENT_STATE_PREFIX: string = '当前'
  static readonly SIX_D_GROUP_DESC: string = '可托管'
  static readonly SIX_D_FULL_FILE_DESC: string = '全盘权限覆盖'
  static readonly POLICY_DEFAULT: string = '默认'
  static readonly POLICY_ALLOWED: string = '允许'
  static readonly POLICY_DENIED: string = '禁止'
  static readonly ENABLED: string = '已启用'
  static readonly DISABLED: string = '未启用'
  static readonly SET_SUCCESS: string = '策略已下发。'
  static readonly SET_FAILED: string = '策略下发失败，请确认企业管理员激活态、签名权限和设备能力。'
  static readonly INSTALL_BLOCK_EMPTY: string = '请输入要禁止安装的应用包名。'
  static readonly INSTALL_BLOCK_INVALID: string = '请输入完整应用包名，例如 com.example.app。'
  static readonly MISSING_UID: string = '未读取到有效 UID，不能设置网络策略。'
  static readonly SIX_D_UNDECLARED: string = '未声明此权限'
  static readonly SIX_D_UNSUPPORTED: string = '不可用'
}

export class PermissionSixDStrings {
  static readonly DOWNLOADS: string = '下载目录'
  static readonly DESKTOP: string = '桌面目录'
  static readonly DOCUMENTS: string = '文档目录'
  static readonly GALLERY: string = '图库'
  static readonly MUSIC: string = '音乐'
  static readonly DOCUMENT_FILE: string = '文档文件'
  static readonly NO_DECLARED: string = '未声明'
  static readonly DETAIL_LOADING: string = '权限详情读取中'
  static readonly DETAIL_FAILED: string = '权限详情读取失败'
}
