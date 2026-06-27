import { applicationManager, bundleManager as enterpriseBundleManager } from '@kit.MDMKit'
import { ADMIN_WANT } from '../../constants/AppConstants'
import { ManagedApplicationInfo, PermissionPolicyState } from '../../models/PermissionModels'

export interface ApplicationControlLists {
  allowedInstallIds: string[]
  disallowedInstallIds: string[]
  disallowedUninstallIds: string[]
  allowedRunningIds: string[]
  disallowedRunningIds: string[]
}

export class ApplicationControlRepository {
  static loadControlListsStrict(accountId: number): ApplicationControlLists {
    return {
      allowedInstallIds: enterpriseBundleManager.getAllowedInstallBundlesSync(ADMIN_WANT, accountId),
      disallowedInstallIds: enterpriseBundleManager.getDisallowedInstallBundlesSync(ADMIN_WANT, accountId),
      disallowedUninstallIds: enterpriseBundleManager.getDisallowedUninstallBundlesSync(ADMIN_WANT, accountId),
      allowedRunningIds: applicationManager.getAllowedRunningBundles(ADMIN_WANT, accountId),
      disallowedRunningIds: applicationManager.getDisallowedRunningBundlesSync(ADMIN_WANT, accountId)
    } as ApplicationControlLists
  }

  static mergeControlStates(
    accountId: number,
    applications: ManagedApplicationInfo[],
    controlLists: ApplicationControlLists
  ): ManagedApplicationInfo[] {
    return applications.map((app: ManagedApplicationInfo): ManagedApplicationInfo =>
      ApplicationControlRepository.mergeControlState(accountId, app, controlLists)
    )
  }

  private static mergeControlState(
    accountId: number,
    app: ManagedApplicationInfo,
    controlLists: ApplicationControlLists
  ): ManagedApplicationInfo {
    return {
      key: app.key,
      accountId: app.accountId,
      bundleName: app.bundleName,
      appIdentifier: app.appIdentifier,
      appIndex: app.appIndex,
      uid: app.uid,
      label: app.label,
      versionName: app.versionName,
      iconData: app.iconData,
      systemApp: app.systemApp,
      removable: app.removable,
      installSource: app.installSource,
      appDistributionType: app.appDistributionType,
      mainAbilityName: app.mainAbilityName,
      installPolicy: app.accountId === accountId ? ApplicationControlRepository.resolvePolicy(
        app,
        controlLists.allowedInstallIds,
        controlLists.disallowedInstallIds
      ) : 'default',
      uninstallProtected: app.accountId === accountId && ApplicationControlRepository.containsApp(controlLists.disallowedUninstallIds, app),
      runningPolicy: app.accountId === accountId && ApplicationControlRepository.containsApp(
        controlLists.disallowedRunningIds,
        app
      ) ? 'denied' : 'default',
      networkPolicy: app.networkPolicy
    } as ManagedApplicationInfo
  }

  static async setDisallowedInstallPolicyId(accountId: number, policyId: string): Promise<void> {
    let normalizedPolicyId = policyId.trim()
    if (normalizedPolicyId.length === 0) {
      throw new Error('missing install policy target')
    }
    let allowedPolicyIds = ApplicationControlRepository.getExistingPolicyIds(
      enterpriseBundleManager.getAllowedInstallBundlesSync(ADMIN_WANT, accountId),
      [normalizedPolicyId]
    )
    let disallowedPolicyIds = ApplicationControlRepository.getExistingPolicyIds(
      enterpriseBundleManager.getDisallowedInstallBundlesSync(ADMIN_WANT, accountId),
      [normalizedPolicyId]
    )
    if (allowedPolicyIds.length > 0) {
      await enterpriseBundleManager.removeAllowedInstallBundlesSync(ADMIN_WANT, allowedPolicyIds, accountId)
    }
    if (disallowedPolicyIds.length === 0) {
      await enterpriseBundleManager.addDisallowedInstallBundlesSync(ADMIN_WANT, [normalizedPolicyId], accountId)
    }
  }

  static async removeInstallPolicyId(
    accountId: number,
    policyId: string,
    policy: PermissionPolicyState
  ): Promise<void> {
    let normalizedPolicyId = policyId.trim()
    if (normalizedPolicyId.length === 0) {
      throw new Error('missing install policy target')
    }
    if (policy === 'allowed') {
      let allowedPolicyIds = ApplicationControlRepository.getExistingPolicyIds(
        enterpriseBundleManager.getAllowedInstallBundlesSync(ADMIN_WANT, accountId),
        [normalizedPolicyId]
      )
      if (allowedPolicyIds.length > 0) {
        await enterpriseBundleManager.removeAllowedInstallBundlesSync(ADMIN_WANT, allowedPolicyIds, accountId)
      }
      return
    }
    if (policy === 'denied') {
      let disallowedPolicyIds = ApplicationControlRepository.getExistingPolicyIds(
        enterpriseBundleManager.getDisallowedInstallBundlesSync(ADMIN_WANT, accountId),
        [normalizedPolicyId]
      )
      if (disallowedPolicyIds.length > 0) {
        await enterpriseBundleManager.removeDisallowedInstallBundlesSync(ADMIN_WANT, disallowedPolicyIds, accountId)
      }
    }
  }

  static async setUninstallProtected(app: ManagedApplicationInfo, enabled: boolean): Promise<void> {
    let policyIds = ApplicationControlRepository.getPolicyIds(app)
    let existingPolicyIds = ApplicationControlRepository.getExistingPolicyIds(
      enterpriseBundleManager.getDisallowedUninstallBundlesSync(ADMIN_WANT, app.accountId),
      policyIds
    )
    if (enabled) {
      if (existingPolicyIds.length === policyIds.length) {
        return
      }
      let missingPolicyIds = policyIds.filter((policyId: string): boolean => !existingPolicyIds.includes(policyId))
      await enterpriseBundleManager.addDisallowedUninstallBundlesSync(ADMIN_WANT, missingPolicyIds, app.accountId)
      ApplicationControlRepository.assertUninstallProtected(app, policyIds)
      return
    }
    if (existingPolicyIds.length > 0) {
      await enterpriseBundleManager.removeDisallowedUninstallBundlesSync(ADMIN_WANT, existingPolicyIds, app.accountId)
    }
    ApplicationControlRepository.assertUninstallUnprotected(app, policyIds)
  }

  static async setRunningPolicy(app: ManagedApplicationInfo, policy: PermissionPolicyState): Promise<void> {
    let cleanupPolicyIds = ApplicationControlRepository.getRunningPolicyCleanupIds(app)
    let disallowedPolicyIds = ApplicationControlRepository.getExistingPolicyIds(
      applicationManager.getDisallowedRunningBundlesSync(ADMIN_WANT, app.accountId),
      cleanupPolicyIds
    )
    let allowedPolicyIds = ApplicationControlRepository.getExistingPolicyIds(
      applicationManager.getAllowedRunningBundles(ADMIN_WANT, app.accountId),
      cleanupPolicyIds
    )
    if (disallowedPolicyIds.length > 0) {
      await applicationManager.removeDisallowedRunningBundlesSync(ADMIN_WANT, disallowedPolicyIds, app.accountId)
    }
    if (allowedPolicyIds.length > 0) {
      await applicationManager.removeAllowedRunningBundles(ADMIN_WANT, allowedPolicyIds, app.accountId)
    }
    if (policy === 'denied') {
      await applicationManager.addDisallowedRunningBundlesSync(
        ADMIN_WANT,
        ApplicationControlRepository.getRunningPolicyIds(app),
        app.accountId
      )
    }
  }

  static buildRunningPolicyCleanupIdsForTest(app: ManagedApplicationInfo): string[] {
    return ApplicationControlRepository.getRunningPolicyCleanupIds(app)
  }

  static createEmptyControlLists(): ApplicationControlLists {
    return {
      allowedInstallIds: [],
      disallowedInstallIds: [],
      disallowedUninstallIds: [],
      allowedRunningIds: [],
      disallowedRunningIds: []
    } as ApplicationControlLists
  }

  private static resolvePolicy(
    app: ManagedApplicationInfo,
    allowedIds: string[],
    disallowedIds: string[]
  ): PermissionPolicyState {
    if (ApplicationControlRepository.containsApp(disallowedIds, app)) {
      return 'denied'
    }
    if (ApplicationControlRepository.containsApp(allowedIds, app)) {
      return 'allowed'
    }
    return 'default'
  }

  private static containsApp(policyIds: string[], app: ManagedApplicationInfo): boolean {
    return policyIds.includes(app.bundleName)
  }

  private static getPolicyIds(app: ManagedApplicationInfo): string[] {
    return [app.bundleName]
  }

  private static getRunningPolicyIds(app: ManagedApplicationInfo): string[] {
    return [app.bundleName]
  }

  private static getRunningPolicyCleanupIds(app: ManagedApplicationInfo): string[] {
    return ApplicationControlRepository.getPolicyIds(app)
  }

  private static getExistingPolicyIds(existingIds: string[], candidateIds: string[]): string[] {
    return candidateIds.filter((id: string): boolean => existingIds.includes(id))
  }

  private static assertUninstallProtected(app: ManagedApplicationInfo, policyIds: string[]): void {
    let currentPolicyIds = enterpriseBundleManager.getDisallowedUninstallBundlesSync(ADMIN_WANT, app.accountId)
    let missingPolicyIds = policyIds.filter((policyId: string): boolean => !currentPolicyIds.includes(policyId))
    if (missingPolicyIds.length > 0) {
      throw new Error('uninstall protection verify failed')
    }
  }

  private static assertUninstallUnprotected(app: ManagedApplicationInfo, policyIds: string[]): void {
    let currentPolicyIds = enterpriseBundleManager.getDisallowedUninstallBundlesSync(ADMIN_WANT, app.accountId)
    let remainingPolicyIds = policyIds.filter((policyId: string): boolean => currentPolicyIds.includes(policyId))
    if (remainingPolicyIds.length > 0) {
      throw new Error('uninstall protection remove verify failed')
    }
  }
}
