export type PermissionPolicyState = 'default' | 'allowed' | 'denied'
export type SixDManagedState = 'default' | 'granted' | 'denied' | 'undeclared' | 'unsupported'

export interface PermissionActionResult {
  success: boolean
  message: string
}

export interface PermissionSummary {
  appCount: number
  managedCount: number
  sixDSensitiveCount: number
  networkRestrictedCount: number
}

export interface PermissionPolicyRecord {
  key: string
  policyType: string
  targetName: string
  targetDetail: string
  statusLabel: string
  scopeLabel: string
  actionKind: string
  appKey: string
  policyId: string
}

export interface PermissionLocalPolicyRecord {
  recordId: string
  accountId: number
  appKey: string
  bundleName: string
  appIdentifier: string
  appIndex: number
  policyType: string
  policyValue: string
  targetName: string
  targetDetail: string
  statusLabel: string
  scopeLabel: string
  actionKind: string
  policyId: string
  status: string
  createdAt: number
  updatedAt: number
  lastError: string
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
  iconData: string
  systemApp: boolean
  removable: boolean
  installSource: string
  appDistributionType: string
  mainAbilityName: string
  installPolicy: PermissionPolicyState
  uninstallProtected: boolean
  runningPolicy: PermissionPolicyState
  networkPolicy: PermissionPolicyState
}

export interface SixDPermissionItem {
  groupKey: string
  title: string
  permissionNames: string[]
  declaredPermissions: string[]
  managedState: SixDManagedState
  canManage: boolean
  disabledReason: string
}

export interface ApplicationPermissionProfile {
  appKey: string
  bundleName: string
  requestedPermissions: string[]
  mainAbilityName: string
  sensitivePermissionCount: number
  message: string
  sixDGroups: SixDPermissionItem[]
}

@ObservedV2
export class PermissionPageState {
  @Trace initialized: boolean = false
  @Trace loading: boolean = false
  @Trace errorMessage: string = ''
  @Trace adminActivated: boolean = false
  @Trace selectedAccountId: number = 0
  @Trace selectedAppKey: string = ''
  @Trace selectedApplication: ManagedApplicationInfo | null = null
  @Trace searchKeyword: string = ''
  @Trace installBlockKeyword: string = ''
  @Trace inventoryMessage: string = ''
  @Trace policyLoading: boolean = false
  @Trace selectedAppRefreshing: boolean = false
  @Trace processingAction: boolean = false
  @Trace processingActionKey: string = ''
  @Trace selectedPermissionProfile: ApplicationPermissionProfile | null = null
  @Trace summary: PermissionSummary = {
    appCount: 0,
    managedCount: 0,
    sixDSensitiveCount: 0,
    networkRestrictedCount: 0
  }
  @Trace accounts: PermissionManagedAccount[] = []
  @Trace applications: ManagedApplicationInfo[] = []
  @Trace filteredApplications: ManagedApplicationInfo[] = []
  @Trace policyRecords: PermissionPolicyRecord[] = []
}

export interface PermissionInitialData {
  adminActivated: boolean
  selectedAccountId: number
  selectedAppKey: string
  inventoryMessage: string
  summary: PermissionSummary
  accounts: PermissionManagedAccount[]
  applications: ManagedApplicationInfo[]
  policyRecords: PermissionPolicyRecord[]
}

export interface PermissionAccountListResult {
  accounts: PermissionManagedAccount[]
  selectedAccountId: number
  message?: string
}

export interface ApplicationInventoryResult {
  applications: ManagedApplicationInfo[]
  policyRecords: PermissionPolicyRecord[]
  message?: string
}
