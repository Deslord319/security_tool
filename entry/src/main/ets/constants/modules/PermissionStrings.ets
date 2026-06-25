export class PermissionPageStrings {
  static readonly SUBTITLE: string = '按账号查看应用级安装、运行、目录、网络和保活管控状态'
  static readonly LOADING: string = '正在加载权限管理状态'
}

export class PermissionSectionStrings {
  static readonly SUMMARY: string = '策略摘要'
  static readonly APPLICATIONS: string = '应用管控对象'
  static readonly SCOPE: string = '首版范围'
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
  static readonly READONLY_TITLE: string = '只读骨架已接入'
  static readonly READONLY_DESC: string = '当前版本先完成入口、路由和状态模型，不执行安装、卸载、运行、6D 权限、网络或保活写操作。'
  static readonly ADMIN_TITLE: string = '依赖企业管理员'
  static readonly ADMIN_DESC: string = '后续开放写操作前，将统一校验企业管理员激活态、权限声明和签名模板。'
}

export class PermissionEmptyStrings {
  static readonly APPLICATIONS: string = '应用清单能力尚未接入，后续按账号展示非系统预装应用。'
}
