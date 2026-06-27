import {
  ApplicationPermissionProfile,
  ApplicationInventoryResult,
  ManagedApplicationInfo,
  PermissionActionResult,
  PermissionInitialData,
  PermissionLocalPolicyRecord,
  PermissionPolicyState,
  PermissionPolicyRecord,
  PermissionSummary,
  SixDManagedState
} from '../../models/PermissionModels'
import { PermissionApplicationStrings, PermissionSixDStrings } from '../../constants/modules/PermissionStrings'
import { ApplicationInventoryRepository } from './ApplicationInventoryRepository'
import { ApplicationControlLists, ApplicationControlRepository } from './ApplicationControlRepository'
import { ApplicationNetworkPolicyRepository } from './ApplicationNetworkPolicyRepository'
import { PermissionAccountProvider } from './PermissionAccountProvider'
import { PermissionPolicyLocalRepository } from './PermissionPolicyLocalRepository'
import { SixDPermissionRepository } from './SixDPermissionRepository'
import { LogUtils } from '../../utils/LogUtils'

const TAG = 'PermissionService'

export class PermissionService {
  private static readonly PERMISSION_PROFILE_TIMEOUT_MS: number = 5000

  static async loadInitialState(): Promise<PermissionInitialData> {
    let accountResult = await PermissionAccountProvider.loadAccounts()
    let selectedAccountId = accountResult.selectedAccountId
    let inventory = await ApplicationInventoryRepository.loadApplications(selectedAccountId)
    return {
      adminActivated: false,
      selectedAccountId: selectedAccountId,
      selectedAppKey: '',
      inventoryMessage: inventory.message ?? accountResult.message ?? '',
      summary: PermissionService.buildSummary(inventory.applications),
      accounts: accountResult.accounts,
      applications: inventory.applications,
      policyRecords: []
    }
  }

  static async loadApplications(accountId: number): Promise<ApplicationInventoryResult> {
    let inventory = await ApplicationInventoryRepository.loadApplications(accountId)
    return {
      applications: inventory.applications,
      policyRecords: [],
      message: inventory.message
    } as ApplicationInventoryResult
  }

  static async loadAccountPolicySnapshot(
    accountId: number,
    applications: ManagedApplicationInfo[]
  ): Promise<ApplicationInventoryResult> {
    return await PermissionService.loadPolicySnapshot(accountId, applications)
  }

  static filterApplications(applications: ManagedApplicationInfo[], keyword: string): ManagedApplicationInfo[] {
    return ApplicationInventoryRepository.filterApplications(applications, keyword)
  }

  private static async loadPolicySnapshot(
    accountId: number,
    applications: ManagedApplicationInfo[]
  ): Promise<ApplicationInventoryResult> {
    let controlLists = ApplicationControlRepository.loadControlLists(accountId)
    let applicationsWithControl = ApplicationControlRepository.mergeControlStates(applications, controlLists)
    let restrictedAppUids = ApplicationNetworkPolicyRepository.loadRestrictedAppUids()
    let applicationsWithNetwork = ApplicationNetworkPolicyRepository.mergeNetworkStates(
      applicationsWithControl,
      restrictedAppUids
    )
    let policyRecords = PermissionService.mergeLocalPolicyRecords(
      PermissionService.buildPolicyRecords(accountId, applicationsWithNetwork, controlLists),
      PermissionPolicyLocalRepository.listActiveByAccount(accountId)
    )
    return {
      applications: applicationsWithNetwork,
      policyRecords: policyRecords
    } as ApplicationInventoryResult
  }

  static buildSummary(applications: ManagedApplicationInfo[]): PermissionSummary {
    let managedCount = applications.filter((app: ManagedApplicationInfo): boolean =>
      app.installPolicy !== 'default' ||
        app.uninstallProtected ||
        app.runningPolicy !== 'default' ||
        app.networkPolicy !== 'default'
    ).length
    let networkRestrictedCount = applications.filter((app: ManagedApplicationInfo): boolean => app.networkPolicy === 'denied').length
    return {
      appCount: applications.length,
      managedCount: managedCount,
      sixDSensitiveCount: 0,
      networkRestrictedCount: networkRestrictedCount
    } as PermissionSummary
  }

  static async loadPermissionProfile(app: ManagedApplicationInfo): Promise<ApplicationPermissionProfile> {
    return await Promise.race([
      SixDPermissionRepository.loadPermissionProfile(app),
      PermissionService.buildPermissionProfileTimeout(app)
    ]) as ApplicationPermissionProfile
  }

  static normalizeInstallBlockPackageName(keyword: string): string {
    let packageName = keyword.trim()
    if (packageName.length === 0) {
      throw new Error('missing install policy target')
    }
    if (!PermissionService.isValidPackageName(packageName)) {
      throw new Error('invalid install package name')
    }
    return packageName
  }

  static async setDisallowedInstallPolicyId(
    accountId: number,
    policyId: string
  ): Promise<PermissionActionResult> {
    return await PermissionService.runAction(async (): Promise<void> => {
      await ApplicationControlRepository.setDisallowedInstallPolicyId(accountId, policyId)
    })
  }

  static mapInstallPolicyTargetError(err: Object): string {
    return PermissionService.mapActionError(err)
  }

  static async deletePolicyRecord(
    accountId: number,
    record: PermissionPolicyRecord,
    applications: ManagedApplicationInfo[]
  ): Promise<PermissionActionResult> {
    return await PermissionService.runAction(async (): Promise<void> => {
      await PermissionService.deletePolicyRecordInternal(accountId, record, applications)
    })
  }

  static async setUninstallProtected(app: ManagedApplicationInfo, enabled: boolean): Promise<PermissionActionResult> {
    return await PermissionService.runAction(async (): Promise<void> => {
      await ApplicationControlRepository.setUninstallProtected(app, enabled)
    })
  }

  static async setRunningPolicy(app: ManagedApplicationInfo, policy: PermissionPolicyState): Promise<PermissionActionResult> {
    return await PermissionService.runAction(async (): Promise<void> => {
      await ApplicationControlRepository.setRunningPolicy(app, policy)
    })
  }

  static async setNetworkPolicy(app: ManagedApplicationInfo, policy: PermissionPolicyState): Promise<PermissionActionResult> {
    return await PermissionService.runAction(async (): Promise<void> => {
      await ApplicationNetworkPolicyRepository.setNetworkPolicy(app, policy)
    })
  }

  static async setSixDPermissionState(
    app: ManagedApplicationInfo,
    permissionProfile: ApplicationPermissionProfile | null,
    groupKey: string,
    state: SixDManagedState
  ): Promise<PermissionActionResult> {
    return await PermissionService.runAction(async (): Promise<void> => {
      let item = SixDPermissionRepository.findPermissionItem(permissionProfile, groupKey)
      if (item === undefined) {
        throw new Error('permission undeclared')
      }
      await SixDPermissionRepository.setPermissionState(app, item, state)
    })
  }

  private static async runAction(action: () => Promise<void>): Promise<PermissionActionResult> {
    try {
      await action()
      return {
        success: true,
        message: PermissionApplicationStrings.SET_SUCCESS
      } as PermissionActionResult
    } catch (err) {
      LogUtils.warn(TAG, `permission action failed: ${JSON.stringify(err)}`)
      return {
        success: false,
        message: PermissionService.mapActionError(err)
      } as PermissionActionResult
    }
  }

  private static async buildPermissionProfileTimeout(app: ManagedApplicationInfo): Promise<ApplicationPermissionProfile> {
    return await new Promise<ApplicationPermissionProfile>((resolve: (value: ApplicationPermissionProfile) => void): void => {
      setTimeout((): void => {
        resolve(SixDPermissionRepository.buildUnsupportedProfile(app, PermissionSixDStrings.DETAIL_FAILED))
      }, PermissionService.PERMISSION_PROFILE_TIMEOUT_MS)
    })
  }

  private static mapActionError(err: Object): string {
    let message = `${err}`
    if (message.includes('missing uid')) {
      return PermissionApplicationStrings.MISSING_UID
    }
    if (message.includes('missing appIdentifier')) {
      return PermissionApplicationStrings.SET_FAILED
    }
    if (message.includes('missing install policy target')) {
      return PermissionApplicationStrings.INSTALL_BLOCK_EMPTY
    }
    if (message.includes('invalid install package name')) {
      return PermissionApplicationStrings.INSTALL_BLOCK_INVALID
    }
    if (message.includes('permission undeclared')) {
      return PermissionApplicationStrings.SIX_D_UNDECLARED
    }
    return PermissionApplicationStrings.SET_FAILED
  }

  private static isValidPackageName(value: string): boolean {
    return /^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$/.test(value)
  }

  private static async deletePolicyRecordInternal(
    accountId: number,
    record: PermissionPolicyRecord,
    applications: ManagedApplicationInfo[]
  ): Promise<void> {
    if (record.actionKind === 'install-deny') {
      await ApplicationControlRepository.removeInstallPolicyId(accountId, record.policyId, 'denied')
      return
    }
    if (record.actionKind === 'install-allow') {
      await ApplicationControlRepository.removeInstallPolicyId(accountId, record.policyId, 'allowed')
      return
    }
    let app = PermissionService.findRecordApplication(record, applications)
    if (record.actionKind === 'uninstall-protect') {
      await ApplicationControlRepository.setUninstallProtected(app, false)
      return
    }
    if (record.actionKind === 'running') {
      await ApplicationControlRepository.setRunningPolicy(app, 'default')
      return
    }
    if (record.actionKind === 'network') {
      await ApplicationNetworkPolicyRepository.setNetworkPolicy(app, 'default')
      return
    }
    if (record.actionKind === 'sixd') {
      let profile = await PermissionService.loadPermissionProfile(app)
      let result = await PermissionService.setSixDPermissionState(app, profile, record.policyId, 'default')
      if (!result.success) {
        throw new Error(result.message)
      }
      return
    }
    throw new Error('unsupported policy action')
  }

  private static findRecordApplication(
    record: PermissionPolicyRecord,
    applications: ManagedApplicationInfo[]
  ): ManagedApplicationInfo {
    let app = applications.find((item: ManagedApplicationInfo): boolean => item.key === record.appKey)
    if (app === undefined) {
      throw new Error('policy target missing')
    }
    return app
  }

  private static buildPolicyRecords(
    accountId: number,
    applications: ManagedApplicationInfo[],
    controlLists: ApplicationControlLists
  ): PermissionPolicyRecord[] {
    let records: PermissionPolicyRecord[] = []
    controlLists.disallowedInstallIds.forEach((policyId: string): void => {
      records.push(PermissionService.buildInstallPolicyRecord(accountId, policyId, 'denied'))
    })
    controlLists.allowedInstallIds.forEach((policyId: string): void => {
      records.push(PermissionService.buildInstallPolicyRecord(accountId, policyId, 'allowed'))
    })
    applications.forEach((app: ManagedApplicationInfo): void => {
      PermissionService.appendApplicationPolicyRecords(records, app)
    })
    return records
  }

  private static mergeLocalPolicyRecords(
    systemRecords: PermissionPolicyRecord[],
    localRecords: PermissionLocalPolicyRecord[]
  ): PermissionPolicyRecord[] {
    let merged = systemRecords.slice()
    let existingKeys = new Set<string>()
    systemRecords.forEach((record: PermissionPolicyRecord): void => {
      existingKeys.add(record.key)
    })
    localRecords.forEach((record: PermissionLocalPolicyRecord): void => {
      if (!PermissionService.shouldMergeLocalPolicyRecord(record)) {
        return
      }
      if (existingKeys.has(record.recordId)) {
        return
      }
      merged.push(PermissionService.createPolicyRecord(
        record.recordId,
        record.policyType,
        record.targetName,
        record.targetDetail,
        record.statusLabel,
        record.scopeLabel,
        record.actionKind,
        record.appKey,
        record.policyId
      ))
      existingKeys.add(record.recordId)
    })
    return merged
  }

  static mergePolicyRecordsForTest(
    systemRecords: PermissionPolicyRecord[],
    localRecords: PermissionLocalPolicyRecord[]
  ): PermissionPolicyRecord[] {
    return PermissionService.mergeLocalPolicyRecords(systemRecords, localRecords)
  }

  static buildApplicationPolicyRecords(applications: ManagedApplicationInfo[]): PermissionPolicyRecord[] {
    let records: PermissionPolicyRecord[] = []
    applications.forEach((app: ManagedApplicationInfo): void => {
      PermissionService.appendApplicationPolicyRecords(records, app)
    })
    return records
  }

  static buildInstallPolicyRecord(
    accountId: number,
    policyId: string,
    policy: PermissionPolicyState
  ): PermissionPolicyRecord {
    let isAllowed = policy === 'allowed'
    return PermissionService.createPolicyRecord(
      `${isAllowed ? 'install-allow' : 'install-deny'}:${accountId}:${policyId}`,
      isAllowed ? PermissionApplicationStrings.POLICY_TYPE_INSTALL_ALLOW : PermissionApplicationStrings.POLICY_TYPE_INSTALL_DENY,
      PermissionApplicationStrings.POLICY_TARGET_NOT_INSTALLED,
      policyId,
      isAllowed ? PermissionApplicationStrings.POLICY_ALLOWED : PermissionApplicationStrings.POLICY_DENIED,
      PermissionService.formatAccountScope(accountId),
      isAllowed ? 'install-allow' : 'install-deny',
      '',
      policyId
    )
  }

  static buildPolicyRecordFromLocal(record: PermissionLocalPolicyRecord): PermissionPolicyRecord {
    return PermissionService.createPolicyRecord(
      record.recordId,
      record.policyType,
      record.targetName,
      record.targetDetail,
      record.statusLabel,
      record.scopeLabel,
      record.actionKind,
      record.appKey,
      record.policyId
    )
  }

  private static shouldMergeLocalPolicyRecord(record: PermissionLocalPolicyRecord): boolean {
    return record.actionKind === 'sixd'
  }

  private static appendApplicationPolicyRecords(records: PermissionPolicyRecord[], app: ManagedApplicationInfo): void {
    if (app.uninstallProtected) {
      records.push(PermissionService.createAppPolicyRecord(
        app,
        PermissionApplicationStrings.POLICY_TYPE_UNINSTALL,
        PermissionApplicationStrings.ENABLED,
        'uninstall-protect'
      ))
    }
    if (app.runningPolicy !== 'default') {
      records.push(PermissionService.createAppPolicyRecord(
        app,
        PermissionApplicationStrings.POLICY_TYPE_RUNNING,
        PermissionService.formatPolicy(app.runningPolicy),
        'running'
      ))
    }
    if (app.networkPolicy !== 'default') {
      records.push(PermissionService.createAppPolicyRecord(
        app,
        PermissionApplicationStrings.POLICY_TYPE_NETWORK,
        PermissionService.formatPolicy(app.networkPolicy),
        'network'
      ))
    }
  }

  private static createAppPolicyRecord(
    app: ManagedApplicationInfo,
    policyType: string,
    statusLabel: string,
    actionKind: string
  ): PermissionPolicyRecord {
    return PermissionService.createPolicyRecord(
      `${actionKind}:${app.key}`,
      policyType,
      app.label,
      app.bundleName,
      statusLabel,
      PermissionService.formatAccountScope(app.accountId),
      actionKind,
      app.key,
      ''
    )
  }

  private static createPolicyRecord(
    key: string,
    policyType: string,
    targetName: string,
    targetDetail: string,
    statusLabel: string,
    scopeLabel: string,
    actionKind: string,
    appKey: string,
    policyId: string
  ): PermissionPolicyRecord {
    return {
      key: key,
      policyType: policyType,
      targetName: targetName,
      targetDetail: targetDetail,
      statusLabel: statusLabel,
      scopeLabel: scopeLabel,
      actionKind: actionKind,
      appKey: appKey,
      policyId: policyId
    } as PermissionPolicyRecord
  }

  private static formatPolicy(policy: PermissionPolicyState): string {
    if (policy === 'allowed') {
      return PermissionApplicationStrings.POLICY_ALLOWED
    }
    if (policy === 'denied') {
      return PermissionApplicationStrings.POLICY_DENIED
    }
    return PermissionApplicationStrings.POLICY_DEFAULT
  }

  private static formatAccountScope(accountId: number): string {
    return `${PermissionApplicationStrings.POLICY_SCOPE_ACCOUNT_PREFIX} ${accountId}`
  }
}
