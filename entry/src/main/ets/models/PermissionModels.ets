export type PermissionPolicyState = 'default' | 'allowed' | 'denied'

export interface PermissionSummary {
  appCount: number
  managedCount: number
  sixDSensitiveCount: number
  networkRestrictedCount: number
  keepAliveCount: number
}

export interface PermissionManagedAccount {
  accountId: number
  displayName: string
  isForeground: boolean
  isAvailable: boolean
}

export interface ManagedApplicationInfo {
  key: string
  accountId: number
  bundleName: string
  appIdentifier: string
  appIndex: number
  uid: number
  label: string
  versionName: string
  systemApp: boolean
  removable: boolean
  installSource: string
  appDistributionType: string
  installPolicy: PermissionPolicyState
  uninstallProtected: boolean
  runningPolicy: PermissionPolicyState
  networkPolicy: PermissionPolicyState
  keepAliveEnabled: boolean
  autoStartEnabled: boolean
}

@ObservedV2
export class PermissionPageState {
  @Trace initialized: boolean = false
  @Trace loading: boolean = false
  @Trace errorMessage: string = ''
  @Trace adminActivated: boolean = false
  @Trace selectedAccountId: number = 0
  @Trace selectedAppKey: string = ''
  @Trace searchKeyword: string = ''
  @Trace inventoryMessage: string = ''
  @Trace summary: PermissionSummary = {
    appCount: 0,
    managedCount: 0,
    sixDSensitiveCount: 0,
    networkRestrictedCount: 0,
    keepAliveCount: 0
  }
  @Trace accounts: PermissionManagedAccount[] = []
  @Trace applications: ManagedApplicationInfo[] = []
  @Trace filteredApplications: ManagedApplicationInfo[] = []
}

export interface PermissionInitialData {
  adminActivated: boolean
  selectedAccountId: number
  selectedAppKey: string
  inventoryMessage: string
  summary: PermissionSummary
  accounts: PermissionManagedAccount[]
  applications: ManagedApplicationInfo[]
}

export interface PermissionAccountListResult {
  accounts: PermissionManagedAccount[]
  selectedAccountId: number
  message?: string
}

export interface ApplicationInventoryResult {
  applications: ManagedApplicationInfo[]
  message?: string
}
