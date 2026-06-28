import { applicationManager, bundleManager as enterpriseBundleManager } from '@kit.MDMKit'
import { ADMIN_WANT } from '../../constants/AppConstants'
import { PermissionAppSnapshot, PermissionPolicyState } from '../../models/PermissionModels'
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
  static loadControlListsStrict(accountId: number): ApplicationControlLists {
    return {
      allowedInstallIds: ApplicationControlRepository.getAllowedInstallBundles(accountId),
      disallowedInstallIds: ApplicationControlRepository.getDisallowedInstallBundles(accountId),
      disallowedUninstallIds: ApplicationControlRepository.getDisallowedUninstallBundles(accountId),
      allowedRunningIds: ApplicationControlRepository.getAllowedRunningBundles(accountId),
      disallowedRunningIds: ApplicationControlRepository.getDisallowedRunningBundles(accountId)
    } as ApplicationControlLists
  }

  static mergeControlStates(
    accountId: number,
    applications: PermissionAppSnapshot[],
    controlLists: ApplicationControlLists
  ): PermissionAppSnapshot[] {
    return applications.map((app: PermissionAppSnapshot): PermissionAppSnapshot =>
      ApplicationControlRepository.mergeControlState(accountId, app, controlLists)
    )
  }

  private static mergeControlState(
    accountId: number,
    app: PermissionAppSnapshot,
    controlLists: ApplicationControlLists
  ): PermissionAppSnapshot {
    return {
      appKey: app.appKey,
      accountId: app.accountId,
      bundleName: app.bundleName,
      appId: app.appId,
      appIdentifier: app.appIdentifier,
      appIndex: app.appIndex,
      uid: app.uid,
      label: app.label,
      uninstallProtected: app.accountId === accountId && ApplicationControlRepository.containsApp(controlLists.disallowedUninstallIds, app),
      runningBlocked: app.accountId === accountId && ApplicationControlRepository.containsApp(
        controlLists.disallowedRunningIds,
        app
      ) ? true : false,
      networkBlocked: app.networkBlocked,
      threeDGroups: app.threeDGroups,
      threeDPolicies: app.threeDPolicies,
      threeDLoadState: app.threeDLoadState,
      threeDMessage: app.threeDMessage
    } as PermissionAppSnapshot
  }

  static async setDisallowedInstallPolicyId(accountId: number, policyId: string): Promise<void> {
    let normalizedPolicyId = policyId.trim()
    if (normalizedPolicyId.length === 0) {
      throw new Error('missing install policy target')
    }
    let allowedPolicyIds = ApplicationControlRepository.getExistingPolicyIds(
      ApplicationControlRepository.getAllowedInstallBundles(accountId),
      [normalizedPolicyId]
    )
    let disallowedPolicyIds = ApplicationControlRepository.getExistingPolicyIds(
      ApplicationControlRepository.getDisallowedInstallBundles(accountId),
      [normalizedPolicyId]
    )
    if (allowedPolicyIds.length > 0) {
      await ApplicationControlRepository.safeAwait(
        () => enterpriseBundleManager.removeAllowedInstallBundlesSync(ADMIN_WANT, allowedPolicyIds, accountId),
        'removeAllowedInstallBundlesSync'
      )
    }
    if (disallowedPolicyIds.length === 0) {
      await ApplicationControlRepository.safeAwait(
        () => enterpriseBundleManager.addDisallowedInstallBundlesSync(ADMIN_WANT, [normalizedPolicyId], accountId),
        'addDisallowedInstallBundlesSync'
      )
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
        ApplicationControlRepository.getAllowedInstallBundles(accountId),
        [normalizedPolicyId]
      )
      if (allowedPolicyIds.length > 0) {
        await ApplicationControlRepository.safeAwait(
        () => enterpriseBundleManager.removeAllowedInstallBundlesSync(ADMIN_WANT, allowedPolicyIds, accountId),
        'removeAllowedInstallBundlesSync'
      )
      }
      return
    }
    if (policy === 'denied') {
      let disallowedPolicyIds = ApplicationControlRepository.getExistingPolicyIds(
        ApplicationControlRepository.getDisallowedInstallBundles(accountId),
        [normalizedPolicyId]
      )
      if (disallowedPolicyIds.length > 0) {
        await ApplicationControlRepository.safeAwait(
        () => enterpriseBundleManager.removeDisallowedInstallBundlesSync(ADMIN_WANT, disallowedPolicyIds, accountId),
        'removeDisallowedInstallBundlesSync'
      )
      }
    }
  }

  static async setUninstallProtected(app: PermissionAppSnapshot, enabled: boolean): Promise<void> {
    let policyIds = ApplicationControlRepository.getPolicyIds(app)
    let existingPolicyIds = ApplicationControlRepository.getExistingPolicyIds(
      ApplicationControlRepository.getDisallowedUninstallBundles(app.accountId),
      policyIds
    )
    if (enabled) {
      let missingPolicyIds = policyIds.filter((policyId: string): boolean => !existingPolicyIds.includes(policyId))
      if (missingPolicyIds.length === 0) {
        ApplicationControlRepository.assertUninstallProtected(app, policyIds)
        return
      }
      await ApplicationControlRepository.safeAwait(
        () => enterpriseBundleManager.addDisallowedUninstallBundlesSync(ADMIN_WANT, missingPolicyIds, app.accountId),
        'addDisallowedUninstallBundlesSync'
      )
      ApplicationControlRepository.assertUninstallProtected(app, policyIds)
      return
    }
    if (existingPolicyIds.length > 0) {
      await ApplicationControlRepository.safeAwait(
        () => enterpriseBundleManager.removeDisallowedUninstallBundlesSync(ADMIN_WANT, existingPolicyIds, app.accountId),
        'removeDisallowedUninstallBundlesSync'
      )
    }
    ApplicationControlRepository.assertUninstallUnprotected(app, policyIds)
  }

  static async setRunningPolicy(app: PermissionAppSnapshot, policy: PermissionPolicyState): Promise<void> {
    let policyIds = ApplicationControlRepository.getPolicyIds(app)
    let disallowedPolicyIds = ApplicationControlRepository.getExistingPolicyIds(
      ApplicationControlRepository.getDisallowedRunningBundles(app.accountId),
      policyIds
    )
    let allowedPolicyIds = ApplicationControlRepository.getExistingPolicyIds(
      ApplicationControlRepository.getAllowedRunningBundles(app.accountId),
      policyIds
    )
    if (disallowedPolicyIds.length > 0) {
      await ApplicationControlRepository.safeAwait(
        () => applicationManager.removeDisallowedRunningBundlesSync(ADMIN_WANT, disallowedPolicyIds, app.accountId),
        'removeDisallowedRunningBundlesSync'
      )
    }
    if (allowedPolicyIds.length > 0) {
      await ApplicationControlRepository.safeAwait(
        () => applicationManager.removeAllowedRunningBundles(ADMIN_WANT, allowedPolicyIds, app.accountId),
        'removeAllowedRunningBundles'
      )
    }
    if (policy === 'denied') {
      await ApplicationControlRepository.safeAwait(
        () => applicationManager.addDisallowedRunningBundlesSync(ADMIN_WANT, policyIds, app.accountId),
        'addDisallowedRunningBundlesSync'
      )
      ApplicationControlRepository.assertRunningBlocked(app, policyIds)
      return
    }
    ApplicationControlRepository.assertRunningUnblocked(app, policyIds)
  }

  static buildRunningPolicyCleanupIdsForTest(app: PermissionAppSnapshot): string[] {
    return ApplicationControlRepository.getPolicyIds(app)
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

  private static safeGetList(fn: () => string[], fallback: string[], name: string): string[] {
    try {
      return fn()
    } catch (err) {
      LogUtils.warn(TAG, `${name} failed: ${JSON.stringify(err)}`)
      return fallback
    }
  }

  private static async safeAwait(operation: () => Promise<void> | void, name: string): Promise<void> {
    try {
      await operation()
    } catch (err) {
      LogUtils.warn(TAG, `${name} failed: ${JSON.stringify(err)}`)
      throw new Error(`${name} failed: ${JSON.stringify(err)}`)
    }
  }

  private static getAllowedInstallBundles(accountId: number): string[] {
    return ApplicationControlRepository.safeGetList(
      () => enterpriseBundleManager.getAllowedInstallBundlesSync(ADMIN_WANT, accountId),
      [],
      'getAllowedInstallBundlesSync'
    )
  }

  private static getDisallowedInstallBundles(accountId: number): string[] {
    return ApplicationControlRepository.safeGetList(
      () => enterpriseBundleManager.getDisallowedInstallBundlesSync(ADMIN_WANT, accountId),
      [],
      'getDisallowedInstallBundlesSync'
    )
  }

  private static getDisallowedUninstallBundles(accountId: number): string[] {
    return ApplicationControlRepository.safeGetList(
      () => enterpriseBundleManager.getDisallowedUninstallBundlesSync(ADMIN_WANT, accountId),
      [],
      'getDisallowedUninstallBundlesSync'
    )
  }

  private static getAllowedRunningBundles(accountId: number): string[] {
    return ApplicationControlRepository.safeGetList(
      () => applicationManager.getAllowedRunningBundles(ADMIN_WANT, accountId),
      [],
      'getAllowedRunningBundles'
    )
  }

  private static getDisallowedRunningBundles(accountId: number): string[] {
    return ApplicationControlRepository.safeGetList(
      () => applicationManager.getDisallowedRunningBundlesSync(ADMIN_WANT, accountId),
      [],
      'getDisallowedRunningBundlesSync'
    )
  }

  private static containsApp(policyIds: string[], app: PermissionAppSnapshot): boolean {
    let appId = ApplicationControlRepository.getAppPolicyId(app)
    return appId.length > 0 && policyIds.includes(appId)
  }

  private static getPolicyIds(app: PermissionAppSnapshot): string[] {
    let appId = ApplicationControlRepository.getAppPolicyId(app)
    if (appId.length === 0) {
      throw new Error('missing app policy id')
    }
    return [appId]
  }

  private static getAppPolicyId(app: PermissionAppSnapshot): string {
    return app.appId.trim()
  }

  private static getExistingPolicyIds(existingIds: string[], candidateIds: string[]): string[] {
    return candidateIds.filter((id: string): boolean => existingIds.includes(id))
  }

  private static assertUninstallProtected(app: PermissionAppSnapshot, policyIds: string[]): void {
    let currentPolicyIds = ApplicationControlRepository.getDisallowedUninstallBundles(app.accountId)
    let missingPolicyIds = policyIds.filter((policyId: string): boolean => !currentPolicyIds.includes(policyId))
    if (missingPolicyIds.length > 0) {
      throw new Error('uninstall protection verify failed')
    }
  }

  private static assertUninstallUnprotected(app: PermissionAppSnapshot, policyIds: string[]): void {
    let currentPolicyIds = ApplicationControlRepository.getDisallowedUninstallBundles(app.accountId)
    let remainingPolicyIds = policyIds.filter((policyId: string): boolean => currentPolicyIds.includes(policyId))
    if (remainingPolicyIds.length > 0) {
      throw new Error('uninstall protection remove verify failed')
    }
  }

  private static assertRunningBlocked(app: PermissionAppSnapshot, policyIds: string[]): void {
    let currentPolicyIds = ApplicationControlRepository.getDisallowedRunningBundles(app.accountId)
    let missingPolicyIds = policyIds.filter((policyId: string): boolean => !currentPolicyIds.includes(policyId))
    if (missingPolicyIds.length > 0) {
      throw new Error('running policy verify failed')
    }
  }

  private static assertRunningUnblocked(app: PermissionAppSnapshot, policyIds: string[]): void {
    let currentPolicyIds = ApplicationControlRepository.getDisallowedRunningBundles(app.accountId)
    let remainingPolicyIds = policyIds.filter((policyId: string): boolean => currentPolicyIds.includes(policyId))
    if (remainingPolicyIds.length > 0) {
      throw new Error('running policy remove verify failed')
    }
  }
}
