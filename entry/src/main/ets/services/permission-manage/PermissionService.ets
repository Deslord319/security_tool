import {
  AccountInstallPolicySnapshot,
  ApplicationPermissionProfile,
  ApplicationInventoryResult,
  PermissionActionResult,
  PermissionAccountListResult,
  PermissionAppSnapshot,
  PermissionInitialData,
  PermissionPolicyActionKind,
  PermissionPolicyState,
  PermissionPolicyRecord,
  PermissionSummary,
  PermissionThreeDPolicySnapshot,
  PermissionLocalPolicyRecord,
  ThreeDManagedState
} from '../../models/PermissionModels'
import { PermissionApplicationStrings, PermissionThreeDStrings } from '../../constants/modules/PermissionStrings'
import { ApplicationInventoryRepository } from './ApplicationInventoryRepository'
import { ApplicationControlLists, ApplicationControlRepository } from './ApplicationControlRepository'
import { ApplicationNetworkPolicyRepository } from './ApplicationNetworkPolicyRepository'
import { PermissionAccountPolicyTaskRunner } from './PermissionAccountPolicyTasks'
import { PermissionAccountProvider } from './PermissionAccountProvider'
import { PermissionPolicyLocalRepository } from './PermissionPolicyLocalRepository'
import { ThreeDPermissionRepository } from './ThreeDPermissionRepository'
import { LogUtils } from '../../utils/LogUtils'

const TAG = 'PermissionService'

export class PermissionService {
  private static readonly PERMISSION_PROFILE_TIMEOUT_MS: number = 5000

  static async loadInitialState(): Promise<PermissionInitialData> {
    let accountResult = await PermissionAccountProvider.loadAccounts()
    let selectedAccountId = accountResult.selectedAccountId
    let inventory = await PermissionService.loadApplications(selectedAccountId)
    return {
      selectedAccountId: selectedAccountId,
      selectedAppKey: '',
      inventoryMessage: inventory.message ?? accountResult.message ?? '',
      accounts: accountResult.accounts,
      appSnapshots: inventory.appSnapshots,
      installPolicies: inventory.installPolicies
    }
  }

  static async loadApplications(accountId: number): Promise<ApplicationInventoryResult> {
    let inventory = await ApplicationInventoryRepository.loadApplications(accountId)
    let policySnapshot = await PermissionService.loadAccountPolicySnapshot(accountId, inventory.appSnapshots)
    return {
      appSnapshots: policySnapshot.appSnapshots,
      installPolicies: policySnapshot.installPolicies,
      message: inventory.message ?? policySnapshot.message
    } as ApplicationInventoryResult
  }

  static async loadAccounts(): Promise<PermissionAccountListResult> {
    return await PermissionAccountProvider.loadAccounts()
  }

  static async loadAccountPolicySnapshot(
    accountId: number,
    appSnapshots: PermissionAppSnapshot[]
  ): Promise<ApplicationInventoryResult> {
    let snapshotData = await PermissionAccountPolicyTaskRunner.loadSnapshot(accountId)
    let controlLists = snapshotData.controlLists
    let merged = ApplicationControlRepository.mergeControlStates(accountId, appSnapshots, controlLists)
    let mergedWithNetwork = ApplicationNetworkPolicyRepository.mergeNetworkStates(
      accountId,
      merged,
      snapshotData.restrictedAppUids
    )
    let localRecords = PermissionPolicyLocalRepository.listActiveByAccount(accountId)
    let nextSnapshots = mergedWithNetwork.map((app: PermissionAppSnapshot): PermissionAppSnapshot => ({
      appKey: app.appKey,
      accountId: app.accountId,
      bundleName: app.bundleName,
      appId: app.appId,
      appIdentifier: app.appIdentifier,
      label: app.label,
      uid: app.uid,
      appIndex: app.appIndex,
      uninstallProtected: app.uninstallProtected,
      runningBlocked: app.runningBlocked,
      networkBlocked: app.networkBlocked,
      threeDGroups: app.threeDGroups,
      threeDPolicies: PermissionService.buildThreeDPolicySnapshots(app, localRecords),
      threeDLoadState: app.threeDLoadState,
      threeDMessage: app.threeDMessage
    } as PermissionAppSnapshot))
    let installPolicies = PermissionService.buildInstallPolicySnapshots(accountId, controlLists)
    return {
      appSnapshots: nextSnapshots,
      installPolicies: installPolicies,
      message: ''
    } as ApplicationInventoryResult
  }

  static buildSummaryFromState(
    appSnapshots: PermissionAppSnapshot[],
    policyRecords: PermissionPolicyRecord[]
  ): PermissionSummary {
    return {
      appCount: appSnapshots.length,
      managedCount: policyRecords.length,
      threeDSensitiveCount: appSnapshots
        .map((snapshot: PermissionAppSnapshot): number =>
          snapshot.threeDGroups.filter((item): boolean => item.canManage).length
        )
        .reduce((total: number, count: number): number => total + count, 0),
      networkRestrictedCount: appSnapshots.filter((snapshot: PermissionAppSnapshot): boolean =>
        snapshot.networkBlocked
      ).length
    } as PermissionSummary
  }

  static filterAppKeys(appSnapshots: PermissionAppSnapshot[], keyword: string): string[] {
    let normalizedKeyword = keyword.trim().toLowerCase()
    if (normalizedKeyword.length === 0) {
      return appSnapshots.map((snapshot: PermissionAppSnapshot): string => snapshot.appKey)
    }
    return appSnapshots
      .filter((snapshot: PermissionAppSnapshot): boolean =>
        snapshot.label.toLowerCase().includes(normalizedKeyword) ||
          snapshot.bundleName.toLowerCase().includes(normalizedKeyword)
      )
      .map((snapshot: PermissionAppSnapshot): string => snapshot.appKey)
  }

  static buildPolicyRecordsFromState(
    appSnapshots: PermissionAppSnapshot[],
    installPolicies: AccountInstallPolicySnapshot[]
  ): PermissionPolicyRecord[] {
    let records: PermissionPolicyRecord[] = []
    installPolicies.forEach((policy: AccountInstallPolicySnapshot): void => {
      records.push(PermissionService.buildInstallPolicyRecord(policy.accountId, policy.policyId, policy.policy))
    })
    appSnapshots.forEach((snapshot: PermissionAppSnapshot): void => {
      if (snapshot.uninstallProtected) {
        records.push(PermissionService.createPolicyRecord(
          `uninstall-protect:${snapshot.appKey}`,
          PermissionApplicationStrings.POLICY_TYPE_UNINSTALL,
          snapshot.label,
          snapshot.bundleName,
          PermissionApplicationStrings.ENABLED,
          PermissionService.formatAccountScope(snapshot.accountId),
          'uninstall-protect',
          snapshot.appKey,
          ''
        ))
      }
      if (snapshot.runningBlocked) {
        records.push(PermissionService.createPolicyRecord(
          `running:${snapshot.appKey}`,
          PermissionApplicationStrings.POLICY_TYPE_RUNNING,
          snapshot.label,
          snapshot.bundleName,
          PermissionApplicationStrings.POLICY_DENIED,
          PermissionService.formatAccountScope(snapshot.accountId),
          'running',
          snapshot.appKey,
          ''
        ))
      }
      if (snapshot.networkBlocked) {
        records.push(PermissionService.createPolicyRecord(
          `network:${snapshot.appKey}`,
          PermissionApplicationStrings.POLICY_TYPE_NETWORK,
          snapshot.label,
          snapshot.bundleName,
          PermissionApplicationStrings.POLICY_DENIED,
          PermissionService.formatAccountScope(snapshot.accountId),
          'network',
          snapshot.appKey,
          ''
        ))
      }
      snapshot.threeDPolicies.forEach((policy: PermissionThreeDPolicySnapshot): void => {
        records.push(PermissionService.createPolicyRecord(
          policy.recordId,
          policy.policyType,
          policy.targetName,
          policy.targetDetail,
          policy.statusLabel,
          policy.scopeLabel,
          policy.actionKind,
          policy.appKey,
          policy.groupKey
        ))
      })
    })
    return records
  }

  static async loadPermissionProfile(app: PermissionAppSnapshot): Promise<ApplicationPermissionProfile> {
    return await Promise.race([
      ThreeDPermissionRepository.loadPermissionProfile(app),
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
    record: PermissionPolicyRecord,
    appSnapshots: PermissionAppSnapshot[],
    installPolicies: AccountInstallPolicySnapshot[]
  ): Promise<PermissionActionResult> {
    return await PermissionService.runAction(async (): Promise<void> => {
      await PermissionService.deletePolicyRecordInternal(record, appSnapshots, installPolicies)
    })
  }

  static async setUninstallProtected(app: PermissionAppSnapshot, enabled: boolean): Promise<PermissionActionResult> {
    return await PermissionService.runAction(async (): Promise<void> => {
      await ApplicationControlRepository.setUninstallProtected(app, enabled)
    })
  }

  static async setRunningBlocked(app: PermissionAppSnapshot, blocked: boolean): Promise<PermissionActionResult> {
    return await PermissionService.runAction(async (): Promise<void> => {
      await ApplicationControlRepository.setRunningPolicy(app, blocked ? 'denied' : 'default')
    })
  }

  static async setNetworkBlocked(app: PermissionAppSnapshot, blocked: boolean): Promise<PermissionActionResult> {
    return await PermissionService.runAction(async (): Promise<void> => {
      await ApplicationNetworkPolicyRepository.setNetworkPolicy(app, blocked ? 'denied' : 'default')
    })
  }

  static async setThreeDState(
    app: PermissionAppSnapshot,
    permissionProfile: ApplicationPermissionProfile | null,
    groupKey: string,
    state: ThreeDManagedState
  ): Promise<PermissionActionResult> {
    return await PermissionService.runAction(async (): Promise<void> => {
      let item = ThreeDPermissionRepository.findPermissionItem(permissionProfile, groupKey)
      if (item === undefined) {
        throw new Error('permission undeclared')
      }
      await ThreeDPermissionRepository.setPermissionState(app, item, state)
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

  private static async buildPermissionProfileTimeout(app: PermissionAppSnapshot): Promise<ApplicationPermissionProfile> {
    return await new Promise<ApplicationPermissionProfile>((resolve: (value: ApplicationPermissionProfile) => void): void => {
      setTimeout((): void => {
        resolve(ThreeDPermissionRepository.buildUnsupportedProfile(app, PermissionThreeDStrings.DETAIL_FAILED))
      }, PermissionService.PERMISSION_PROFILE_TIMEOUT_MS)
    })
  }

  private static mapActionError(err: Object): string {
    let message = `${err}`
    if (message.includes('missing uid')) {
      return PermissionApplicationStrings.MISSING_UID
    }
    if (message.includes('missing install policy target')) {
      return PermissionApplicationStrings.INSTALL_BLOCK_EMPTY
    }
    if (message.includes('invalid install package name')) {
      return PermissionApplicationStrings.INSTALL_BLOCK_INVALID
    }
    if (message.includes('permission undeclared')) {
      return PermissionApplicationStrings.THREE_D_UNDECLARED
    }
    return PermissionApplicationStrings.SET_FAILED
  }

  private static isValidPackageName(value: string): boolean {
    return /^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$/.test(value)
  }

  private static async deletePolicyRecordInternal(
    record: PermissionPolicyRecord,
    appSnapshots: PermissionAppSnapshot[],
    installPolicies: AccountInstallPolicySnapshot[]
  ): Promise<void> {
    if (record.actionKind === 'install-deny') {
      await PermissionService.removeInstallPolicyByRecord(record, installPolicies, 'denied')
      return
    }
    if (record.actionKind === 'install-allow') {
      await PermissionService.removeInstallPolicyByRecord(record, installPolicies, 'allowed')
      return
    }
    let app = PermissionService.findRecordApplication(record, appSnapshots)
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
    if (record.actionKind === 'three-d') {
      let profile = await PermissionService.loadPermissionProfile(app)
      let result = await PermissionService.setThreeDState(app, profile, record.policyId, 'default')
      if (!result.success) {
        throw new Error(result.message)
      }
      return
    }
    throw new Error('unsupported policy action')
  }

  private static async removeInstallPolicyByRecord(
    record: PermissionPolicyRecord,
    installPolicies: AccountInstallPolicySnapshot[],
    policy: PermissionPolicyState
  ): Promise<void> {
    let matched = installPolicies.find((item: AccountInstallPolicySnapshot): boolean => item.policyId === record.policyId)
    let accountId = matched !== undefined ? matched.accountId : 0
    await ApplicationControlRepository.removeInstallPolicyId(accountId, record.policyId, policy)
  }

  private static findRecordApplication(
    record: PermissionPolicyRecord,
    appSnapshots: PermissionAppSnapshot[]
  ): PermissionAppSnapshot {
    let snapshot = appSnapshots.find((item: PermissionAppSnapshot): boolean => item.appKey === record.appKey)
    if (snapshot === undefined) {
      throw new Error('policy target missing')
    }
    return snapshot
  }

  private static buildThreeDPolicySnapshots(
    app: PermissionAppSnapshot,
    localRecords: PermissionLocalPolicyRecord[]
  ): PermissionThreeDPolicySnapshot[] {
    return localRecords
      .filter((record: PermissionLocalPolicyRecord): boolean =>
        record.accountId === app.accountId &&
          record.appKey === app.appKey &&
          (record.actionKind === 'three-d') &&
          record.status === 'active' &&
          record.policyValue !== 'default'
      )
      .map((record: PermissionLocalPolicyRecord): PermissionThreeDPolicySnapshot => ({
        recordId: record.recordId,
        appKey: record.appKey,
        groupKey: record.policyId,
        actionKind: record.actionKind,
        policyValue: record.policyValue as ThreeDManagedState,
        policyType: record.policyType,
        targetName: record.targetName,
        targetDetail: record.targetDetail,
        statusLabel: record.statusLabel,
        scopeLabel: record.scopeLabel
      } as PermissionThreeDPolicySnapshot))
  }

  private static buildInstallPolicySnapshots(
    accountId: number,
    controlLists: ApplicationControlLists
  ): AccountInstallPolicySnapshot[] {
    let policies: AccountInstallPolicySnapshot[] = []
    controlLists.disallowedInstallIds.forEach((policyId: string): void => {
      policies.push({
        accountId: accountId,
        policyId: policyId,
        policy: 'denied'
      } as AccountInstallPolicySnapshot)
    })
    controlLists.allowedInstallIds.forEach((policyId: string): void => {
      policies.push({
        accountId: accountId,
        policyId: policyId,
        policy: 'allowed'
      } as AccountInstallPolicySnapshot)
    })
    return policies
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

  private static createPolicyRecord(
    key: string,
    policyType: string,
    targetName: string,
    targetDetail: string,
    statusLabel: string,
    scopeLabel: string,
    actionKind: PermissionPolicyActionKind,
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

  private static formatAccountScope(accountId: number): string {
    return `${PermissionApplicationStrings.POLICY_SCOPE_ACCOUNT_PREFIX} ${accountId}`
  }
}
