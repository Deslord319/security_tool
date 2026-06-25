export class PermissionPageStrings {
  static readonly SUBTITLE: string = '按账号查看应用级安装、运行、目录、网络和保活管控状态'
  static readonly LOADING: string = '正在加载权限管理状态'
}

export class PermissionSectionStrings {
  static readonly ACCOUNT_SCOPE: string = '作用账号'
  static readonly SUMMARY: string = '策略摘要'
  static readonly APPLICATIONS: string = '应用管控对象'
  static readonly APPLICATION_DETAIL: string = '应用详情'
  static readonly TARGET_APPLICATION: string = '目标应用'
  static readonly TARGET_APPLICATION_DESC: string = '选择后下方策略作用于该应用'
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
}

export class PermissionSearchStrings {
  static readonly PLACEHOLDER: string = '搜索应用名称或包名'
}

export class PermissionApplicationStrings {
  static readonly BUNDLE_NAME: string = '包名'
  static readonly VERSION_NAME: string = '版本'
  static readonly UID: string = 'UID'
  static readonly INSTALL_POLICY: string = '安装策略'
  static readonly UNINSTALL_PROTECTED: string = '卸载保护'
  static readonly RUNNING_POLICY: string = '运行策略'
  static readonly NETWORK_POLICY: string = '网络策略'
  static readonly KEEP_ALIVE: string = '保活'
  static readonly AUTO_START: string = '自启动'
  static readonly INSTALL_POLICY_DESC: string = '控制该应用后续安装限制'
  static readonly UNINSTALL_PROTECTED_DESC: string = '阻止当前账号卸载该应用'
  static readonly RUNNING_POLICY_DESC: string = '控制应用是否允许启动'
  static readonly NETWORK_POLICY_DESC: string = '控制应用全部网络访问'
  static readonly KEEP_ALIVE_DESC: string = '保持应用后台运行能力'
  static readonly AUTO_START_DESC: string = '控制应用随系统自启动'
  static readonly SIX_D_GROUP_DESC: string = '可托管'
  static readonly POLICY_DEFAULT: string = '默认'
  static readonly POLICY_ALLOWED: string = '允许'
  static readonly POLICY_DENIED: string = '禁止'
  static readonly ENABLED: string = '已启用'
  static readonly DISABLED: string = '未启用'
  static readonly SET_SUCCESS: string = '策略已下发。'
  static readonly SET_FAILED: string = '策略下发失败，请确认企业管理员激活态、签名权限和设备能力。'
  static readonly PACKAGE_DETAIL_UNAVAILABLE: string = '包详情不可用，无法读取声明权限或入口 Ability。'
  static readonly MISSING_ABILITY: string = '未读取到入口 Ability，不能设置自启动。'
  static readonly MISSING_UID: string = '未读取到有效 UID，不能设置网络策略。'
  static readonly NO_POLICY_CHANGES: string = '当前应用策略没有待下发变更。'
  static readonly SIX_D_UNDECLARED: string = '未声明此权限'
  static readonly SIX_D_UNSUPPORTED: string = '不可用'
  static readonly PROCESSING: string = '处理中'
}

export class PermissionSixDStrings {
  static readonly DOWNLOADS: string = '下载目录'
  static readonly DESKTOP: string = '桌面目录'
  static readonly DOCUMENTS: string = '文档目录'
  static readonly GALLERY: string = '图库'
  static readonly MUSIC: string = '音乐'
  static readonly DOCUMENT_FILE: string = '文档文件'
  static readonly NO_DECLARED: string = '未声明'
  static readonly DETAIL_FAILED: string = '权限详情读取失败'
}
