export type PermissionPolicyState = 'default' | 'allowed' | 'denied'

export interface PermissionSummaryState {
  accountCount: number
  applicationCount: number
  managedPolicyCount: number
}

export interface PermissionAccountOption {
  accountId: number
  displayName: string
}

export interface PermissionApplicationSummary {
  appKey: string
  bundleName: string
  label: string
  accountId: number
  installPolicy: PermissionPolicyState
  runningPolicy: PermissionPolicyState
  networkPolicy: PermissionPolicyState
  keepAliveEnabled: boolean
}

@ObservedV2
export class PermissionPageState {
  @Trace initialized: boolean = false
  @Trace loading: boolean = false
  @Trace errorMessage: string = ''
  @Trace adminActivated: boolean = false
  @Trace selectedAccountId: number = 0
  @Trace summary: PermissionSummaryState = {
    accountCount: 0,
    applicationCount: 0,
    managedPolicyCount: 0
  }
  @Trace accountOptions: PermissionAccountOption[] = []
  @Trace applications: PermissionApplicationSummary[] = []
}

export interface PermissionInitialData {
  adminActivated: boolean
  selectedAccountId: number
  summary: PermissionSummaryState
  accountOptions: PermissionAccountOption[]
  applications: PermissionApplicationSummary[]
}
