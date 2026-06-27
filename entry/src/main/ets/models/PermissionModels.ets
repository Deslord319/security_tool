export type PermissionPolicyState = 'default' | 'allowed' | 'denied'
export type ThreeDManagedState = 'default' | 'granted' | 'denied' | 'undeclared' | 'unsupported'
export type ThreeDLoadState = 'idle' | 'loading' | 'loaded' | 'failed'
export type PermissionPolicyActionKind =
  'install-deny' |
  'install-allow' |
  'uninstall-protect' |
  'running' |
  'network' |
  'three-d'

export interface PermissionActionResult {
  success: boolean
  message: string
}

export interface PermissionSummary {
  appCount: number
  managedCount: number
  threeDSensitiveCount: number
  networkRestrictedCount: number
}

export interface PermissionPolicyRecord {
  key: string
  policyType: string
  targetName: string
  targetDetail: string
  statusLabel: string
  scopeLabel: string
  actionKind: PermissionPolicyActionKind
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
  actionKind: PermissionPolicyActionKind
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

export interface PermissionThreeDPolicySnapshot {
  recordId: string
  appKey: string
  groupKey: string
  actionKind: PermissionPolicyActionKind
  policyValue: ThreeDManagedState
  policyType: string
  targetName: string
  targetDetail: string
  statusLabel: string
  scopeLabel: string
}

export interface AccountInstallPolicySnapshot {
  accountId: number
  policyId: string
  policy: 'denied' | 'allowed'
}

export interface PermissionAppSnapshot {
  appKey: string
  accountId: number
  bundleName: string
  appId: string
  appIdentifier: string
  label: string
  uid: number
  appIndex: number
  uninstallProtected: boolean
  runningBlocked: boolean
  networkBlocked: boolean
  threeDGroups: ThreeDPermissionItem[]
  threeDPolicies: PermissionThreeDPolicySnapshot[]
  threeDLoadState: ThreeDLoadState
  threeDMessage: string
}

export interface ThreeDPermissionItem {
  groupKey: string
  title: string
  permissionNames: string[]
  declaredPermissions: string[]
  managedState: ThreeDManagedState
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
  threeDGroups: ThreeDPermissionItem[]
}

@ObservedV2
export class PermissionPageState {
  @Trace initialized: boolean = false
  @Trace loading: boolean = false
  @Trace errorMessage: string = ''
  @Trace selectedAccountId: number = 0
  @Trace selectedAppKey: string = ''
  @Trace searchKeyword: string = ''
  @Trace installBlockKeyword: string = ''
  @Trace inventoryMessage: string = ''
  @Trace loadingSelectedApp: boolean = false
  @Trace processingActionKey: string = ''
  @Trace summary: PermissionSummary = {
    appCount: 0,
    managedCount: 0,
    threeDSensitiveCount: 0,
    networkRestrictedCount: 0
  }
  @Trace accounts: PermissionManagedAccount[] = []
  @Trace appSnapshots: PermissionAppSnapshot[] = []
  @Trace installPolicies: AccountInstallPolicySnapshot[] = []
  @Trace filteredAppKeys: string[] = []
  @Trace policyRecords: PermissionPolicyRecord[] = []
}

export interface PermissionInitialData {
  selectedAccountId: number
  selectedAppKey: string
  inventoryMessage: string
  accounts: PermissionManagedAccount[]
  appSnapshots: PermissionAppSnapshot[]
  installPolicies: AccountInstallPolicySnapshot[]
}

export interface PermissionAccountListResult {
  accounts: PermissionManagedAccount[]
  selectedAccountId: number
  message?: string
}

export interface ApplicationInventoryResult {
  appSnapshots: PermissionAppSnapshot[]
  installPolicies: AccountInstallPolicySnapshot[]
  message?: string
}
