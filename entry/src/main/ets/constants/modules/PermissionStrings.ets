export class PermissionPageStrings {
  static readonly SUBTITLE: string = '按账号查看应用级安装、运行、目录、网络和保活管控状态'
  static readonly LOADING: string = '正在加载权限管理状态'
}

export class PermissionSectionStrings {
  static readonly ACCOUNT_SCOPE: string = '作用账号'
  static readonly SUMMARY: string = '策略摘要'
  static readonly APPLICATIONS: string = '应用管控对象'
  static readonly APPLICATION_DETAIL: string = '应用详情'
  static readonly SCOPE: string = '首版范围'
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
  static readonly APPLICATIONS_DESC: string = '非系统预装应用'
  static readonly POLICIES_TITLE: string = '策略'
  static readonly POLICIES_DESC: string = '已托管策略'
}

export class PermissionScopeStrings {
  static readonly READONLY_TITLE: string = '只读清单已接入'
  static readonly READONLY_DESC: string = '当前版本已接入账号和应用清单读取，不执行安装、卸载、运行、6D 权限、网络或保活写操作。'
  static readonly ADMIN_TITLE: string = '依赖企业管理员'
  static readonly ADMIN_DESC: string = '后续开放写操作前，将统一校验企业管理员激活态、权限声明和签名模板。'
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
  static readonly POLICY_DEFAULT: string = '默认'
  static readonly POLICY_ALLOWED: string = '允许'
  static readonly POLICY_DENIED: string = '禁止'
  static readonly ENABLED: string = '已启用'
  static readonly DISABLED: string = '未启用'
}
