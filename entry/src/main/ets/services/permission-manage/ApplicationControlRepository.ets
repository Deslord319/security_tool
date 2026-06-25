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
}
