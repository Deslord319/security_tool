import { applicationManager, bundleManager as enterpriseBundleManager } from '@kit.MDMKit'
import { ADMIN_WANT } from '../../constants/AppConstants'
import { ManagedApplicationInfo, PermissionPolicyState } from '../../models/PermissionModels'
import { LogUtils } from '../../utils/LogUtils'

const TAG = 'ApplicationControlRepository'

export interface ApplicationControlLists {
  allowedInstallIds: string[]
  disallowedInstallIds: string[]
  disallowedUninstallIds: string[]
  allowedRunningIds: string[]
  disallowedRunningIds: string[]
}

export class ApplicationControlRepository {
  static loadControlLists(accountId: number): ApplicationControlLists {
    let controlLists = ApplicationControlRepository.createEmptyControlLists()
    ApplicationControlRepository.tryLoadBundlePolicies(accountId, controlLists)
    ApplicationControlRepository.tryLoadApplicationPolicies(accountId, controlLists)
    return controlLists
  }

  static mergeControlStates(
    applications: ManagedApplicationInfo[],
    controlLists: ApplicationControlLists
  ): ManagedApplicationInfo[] {
    return applications.map((app: ManagedApplicationInfo): ManagedApplicationInfo =>
      ApplicationControlRepository.mergeControlState(app, controlLists)
    )
  }

  private static mergeControlState(
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
      installPolicy: ApplicationControlRepository.resolvePolicy(
        app,
        controlLists.allowedInstallIds,
        controlLists.disallowedInstallIds
      ),
      uninstallProtected: ApplicationControlRepository.containsApp(controlLists.disallowedUninstallIds, app),
      runningPolicy: ApplicationControlRepository.resolvePolicy(
        app,
        controlLists.allowedRunningIds,
        controlLists.disallowedRunningIds
      ),
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
    let policyIds = ApplicationControlRepository.getRunningPolicyIds(app)
    let disallowedPolicyIds = ApplicationControlRepository.getExistingPolicyIds(
      applicationManager.getDisallowedRunningBundlesSync(ADMIN_WANT, app.accountId),
      policyIds
    )
    let allowedPolicyIds = ApplicationControlRepository.getExistingPolicyIds(
      applicationManager.getAllowedRunningBundles(ADMIN_WANT, app.accountId),
      policyIds
    )
    if (disallowedPolicyIds.length > 0) {
      await applicationManager.removeDisallowedRunningBundlesSync(ADMIN_WANT, disallowedPolicyIds, app.accountId)
    }
    if (allowedPolicyIds.length > 0) {
      await applicationManager.removeAllowedRunningBundles(ADMIN_WANT, allowedPolicyIds, app.accountId)
    }
    if (policy === 'allowed') {
      await applicationManager.addAllowedRunningBundles(ADMIN_WANT, policyIds, app.accountId)
      return
    }
    if (policy === 'denied') {
      await applicationManager.addDisallowedRunningBundlesSync(ADMIN_WANT, policyIds, app.accountId)
    }
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

  private static tryLoadBundlePolicies(accountId: number, controlLists: ApplicationControlLists): void {
    try {
      controlLists.allowedInstallIds = enterpriseBundleManager.getAllowedInstallBundlesSync(ADMIN_WANT, accountId)
      controlLists.disallowedInstallIds = enterpriseBundleManager.getDisallowedInstallBundlesSync(ADMIN_WANT, accountId)
      controlLists.disallowedUninstallIds = enterpriseBundleManager.getDisallowedUninstallBundlesSync(ADMIN_WANT, accountId)
    } catch (err) {
      LogUtils.warn(TAG, `load bundle policies failed: ${JSON.stringify(err)}`)
    }
  }

  private static tryLoadApplicationPolicies(accountId: number, controlLists: ApplicationControlLists): void {
    try {
      controlLists.disallowedRunningIds = applicationManager.getDisallowedRunningBundlesSync(ADMIN_WANT, accountId)
      controlLists.allowedRunningIds = applicationManager.getAllowedRunningBundles(ADMIN_WANT, accountId)
    } catch (err) {
      LogUtils.warn(TAG, `load application policies failed: ${JSON.stringify(err)}`)
    }
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
    return policyIds.includes(app.bundleName) || policyIds.includes(app.appIdentifier)
  }

  private static getPrimaryPolicyId(app: ManagedApplicationInfo): string {
    return app.appIdentifier.length > 0 ? app.appIdentifier : app.bundleName
  }

  private static getPolicyIds(app: ManagedApplicationInfo): string[] {
    let ids: string[] = [app.bundleName]
    if (app.appIdentifier.length > 0 && app.appIdentifier !== app.bundleName) {
      ids.push(app.appIdentifier)
    }
    return ids
  }

  private static getRunningPolicyIds(app: ManagedApplicationInfo): string[] {
    if (app.appIdentifier.length === 0) {
      throw new Error('missing appIdentifier')
    }
    return [app.appIdentifier]
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
