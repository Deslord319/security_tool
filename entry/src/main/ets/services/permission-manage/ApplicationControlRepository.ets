import { applicationManager, bundleManager as enterpriseBundleManager } from '@kit.MDMKit'
import { Want } from '@kit.AbilityKit'
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
  keepAliveBundleNames: string[]
  autoStartBundleNames: string[]
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
      networkPolicy: app.networkPolicy,
      keepAliveEnabled: controlLists.keepAliveBundleNames.includes(app.bundleName),
      autoStartEnabled: controlLists.autoStartBundleNames.includes(app.bundleName)
    } as ManagedApplicationInfo
  }

  static async setInstallPolicy(app: ManagedApplicationInfo, policy: PermissionPolicyState): Promise<void> {
    let policyIds = ApplicationControlRepository.getPolicyIds(app)
    await enterpriseBundleManager.removeAllowedInstallBundlesSync(ADMIN_WANT, policyIds, app.accountId)
    await enterpriseBundleManager.removeDisallowedInstallBundlesSync(ADMIN_WANT, policyIds, app.accountId)
    if (policy === 'allowed') {
      await enterpriseBundleManager.addAllowedInstallBundlesSync(ADMIN_WANT, [ApplicationControlRepository.getPrimaryPolicyId(app)], app.accountId)
      return
    }
    if (policy === 'denied') {
      await enterpriseBundleManager.addDisallowedInstallBundlesSync(ADMIN_WANT, [ApplicationControlRepository.getPrimaryPolicyId(app)], app.accountId)
    }
  }

  static async setUninstallProtected(app: ManagedApplicationInfo, enabled: boolean): Promise<void> {
    let policyId = ApplicationControlRepository.getPrimaryPolicyId(app)
    if (enabled) {
      await enterpriseBundleManager.addDisallowedUninstallBundlesSync(ADMIN_WANT, [policyId], app.accountId)
      return
    }
    await enterpriseBundleManager.removeDisallowedUninstallBundlesSync(ADMIN_WANT, ApplicationControlRepository.getPolicyIds(app), app.accountId)
  }

  static async setRunningPolicy(app: ManagedApplicationInfo, policy: PermissionPolicyState): Promise<void> {
    let policyIds = ApplicationControlRepository.getPolicyIds(app)
    await applicationManager.removeDisallowedRunningBundlesSync(ADMIN_WANT, policyIds, app.accountId)
    await applicationManager.removeAllowedRunningBundles(ADMIN_WANT, policyIds, app.accountId)
    if (policy === 'allowed') {
      await applicationManager.addAllowedRunningBundles(ADMIN_WANT, [ApplicationControlRepository.getPrimaryPolicyId(app)], app.accountId)
      return
    }
    if (policy === 'denied') {
      await applicationManager.addDisallowedRunningBundlesSync(ADMIN_WANT, [ApplicationControlRepository.getPrimaryPolicyId(app)], app.accountId)
    }
  }

  static async setKeepAlive(app: ManagedApplicationInfo, enabled: boolean): Promise<void> {
    if (enabled) {
      await applicationManager.addKeepAliveApps(ADMIN_WANT, [app.bundleName], app.accountId, true)
      return
    }
    await applicationManager.removeKeepAliveApps(ADMIN_WANT, [app.bundleName], app.accountId)
  }

  static async setAutoStart(app: ManagedApplicationInfo, enabled: boolean, abilityName: string): Promise<void> {
    let normalizedAbilityName = abilityName.trim()
    if (normalizedAbilityName.length === 0) {
      throw new Error('missing main ability')
    }
    let want: Want = {
      bundleName: app.bundleName,
      abilityName: normalizedAbilityName
    }
    if (enabled) {
      await applicationManager.addAutoStartApps(ADMIN_WANT, [want], app.accountId, true)
      return
    }
    await applicationManager.removeAutoStartApps(ADMIN_WANT, [want], app.accountId)
  }

  static createEmptyControlLists(): ApplicationControlLists {
    return {
      allowedInstallIds: [],
      disallowedInstallIds: [],
      disallowedUninstallIds: [],
      allowedRunningIds: [],
      disallowedRunningIds: [],
      keepAliveBundleNames: [],
      autoStartBundleNames: []
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
      controlLists.keepAliveBundleNames = applicationManager.getKeepAliveApps(ADMIN_WANT, accountId)
      controlLists.autoStartBundleNames = applicationManager.getAutoStartApps(ADMIN_WANT, accountId)
        .map((want: Want): string => want.bundleName ?? '')
        .filter((bundleName: string): boolean => bundleName.length > 0)
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
}
