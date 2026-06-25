import {
  ApplicationInventoryResult,
  ManagedApplicationInfo,
  PermissionInitialData,
  PermissionSummary
} from '../../models/PermissionModels'
import { ApplicationInventoryRepository } from './ApplicationInventoryRepository'
import { ApplicationControlRepository } from './ApplicationControlRepository'
import { PermissionAccountProvider } from './PermissionAccountProvider'

export class PermissionService {
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

  private static loadControlStates(accountId: number, applications: ManagedApplicationInfo[]): ManagedApplicationInfo[] {
    if (applications.length === 0) {
      return applications
    }
    let controlLists = ApplicationControlRepository.loadControlLists(accountId)
    return ApplicationControlRepository.mergeControlStates(applications, controlLists)
  }
}
