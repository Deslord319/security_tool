import {
  ApplicationPermissionProfile,
  ApplicationInventoryResult,
  ManagedApplicationInfo,
  PermissionActionResult,
  PermissionInitialData,
  PermissionPolicyState,
  PermissionSummary,
  SixDManagedState
} from '../../models/PermissionModels'
import { PermissionApplicationStrings, PermissionSixDStrings } from '../../constants/modules/PermissionStrings'
import { ApplicationInventoryRepository } from './ApplicationInventoryRepository'
import { ApplicationControlRepository } from './ApplicationControlRepository'
import { ApplicationNetworkPolicyRepository } from './ApplicationNetworkPolicyRepository'
import { PermissionAccountProvider } from './PermissionAccountProvider'
import { SixDPermissionRepository } from './SixDPermissionRepository'
import { LogUtils } from '../../utils/LogUtils'

const TAG = 'PermissionService'

export class PermissionService {
  private static readonly PERMISSION_PROFILE_TIMEOUT_MS: number = 5000

  static async loadInitialState(): Promise<PermissionInitialData> {
    let accountResult = await PermissionAccountProvider.loadAccounts()
    let selectedAccountId = accountResult.selectedAccountId
    let inventory = await ApplicationInventoryRepository.loadApplications(selectedAccountId)
    let applications = PermissionService.loadControlStates(selectedAccountId, inventory.applications)
    return {
      adminActivated: false,
      selectedAccountId: selectedAccountId,
      selectedAppKey: '',
      inventoryMessage: inventory.message ?? accountResult.message ?? '',
      summary: PermissionService.buildSummary(applications),
      accounts: accountResult.accounts,
      applications: applications
    }
  }

  static async loadApplications(accountId: number): Promise<ApplicationInventoryResult> {
    let inventory = await ApplicationInventoryRepository.loadApplications(accountId)
    return {
      applications: PermissionService.loadControlStates(accountId, inventory.applications),
      message: inventory.message
    } as ApplicationInventoryResult
  }

  static filterApplications(applications: ManagedApplicationInfo[], keyword: string): ManagedApplicationInfo[] {
    return ApplicationInventoryRepository.filterApplications(applications, keyword)
  }

  static buildSummary(applications: ManagedApplicationInfo[]): PermissionSummary {
    let managedCount = applications.filter((app: ManagedApplicationInfo): boolean =>
      app.installPolicy !== 'default' ||
        app.uninstallProtected ||
        app.runningPolicy !== 'default' ||
        app.networkPolicy !== 'default' ||
        app.keepAliveEnabled ||
        app.autoStartEnabled
    ).length
    let networkRestrictedCount = applications.filter((app: ManagedApplicationInfo): boolean => app.networkPolicy === 'denied').length
    let keepAliveCount = applications.filter((app: ManagedApplicationInfo): boolean => app.keepAliveEnabled).length
    return {
      appCount: applications.length,
      managedCount: managedCount,
      sixDSensitiveCount: 0,
      networkRestrictedCount: networkRestrictedCount,
      keepAliveCount: keepAliveCount
    } as PermissionSummary
  }

  static async loadPermissionProfile(app: ManagedApplicationInfo): Promise<ApplicationPermissionProfile> {
    return await Promise.race([
      SixDPermissionRepository.loadPermissionProfile(app),
      PermissionService.buildPermissionProfileTimeout(app)
    ]) as ApplicationPermissionProfile
  }

  static async setInstallPolicy(app: ManagedApplicationInfo, policy: PermissionPolicyState): Promise<PermissionActionResult> {
    return await PermissionService.runAction(async (): Promise<void> => {
      await ApplicationControlRepository.setInstallPolicy(app, policy)
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

  static async setKeepAlive(app: ManagedApplicationInfo, enabled: boolean): Promise<PermissionActionResult> {
    return await PermissionService.runAction(async (): Promise<void> => {
      await ApplicationControlRepository.setKeepAlive(app, enabled)
    })
  }

  static async setAutoStart(
    app: ManagedApplicationInfo,
    enabled: boolean,
    permissionProfile: ApplicationPermissionProfile | null
  ): Promise<PermissionActionResult> {
    return await PermissionService.runAction(async (): Promise<void> => {
      await ApplicationControlRepository.setAutoStart(app, enabled, permissionProfile?.mainAbilityName ?? app.mainAbilityName)
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

  private static loadControlStates(accountId: number, applications: ManagedApplicationInfo[]): ManagedApplicationInfo[] {
    if (applications.length === 0) {
      return applications
    }
    let controlLists = ApplicationControlRepository.loadControlLists(accountId)
    let applicationsWithControl = ApplicationControlRepository.mergeControlStates(applications, controlLists)
    let restrictedAppUids = ApplicationNetworkPolicyRepository.loadRestrictedAppUids()
    return ApplicationNetworkPolicyRepository.mergeNetworkStates(applicationsWithControl, restrictedAppUids)
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
    if (message.includes('missing main ability')) {
      return PermissionApplicationStrings.MISSING_ABILITY
    }
    if (message.includes('missing uid')) {
      return PermissionApplicationStrings.MISSING_UID
    }
    if (message.includes('permission undeclared')) {
      return PermissionApplicationStrings.SIX_D_UNDECLARED
    }
    return PermissionApplicationStrings.SET_FAILED
  }
}
