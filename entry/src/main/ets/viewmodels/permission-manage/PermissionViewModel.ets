import {
  ApplicationPermissionProfile,
  ApplicationInventoryResult,
  ManagedApplicationInfo,
  PermissionActionResult,
  PermissionInitialData,
  PermissionPageState,
  PermissionPolicyState,
  SixDManagedState
} from '../../models/PermissionModels'
import { PermissionService } from '../../services/permission-manage/PermissionService'
import { MessageText } from '../../constants/StringCatalog'
import { LogUtils } from '../../utils/LogUtils'

const TAG = 'PermissionViewModel'

@ObservedV2
export class PermissionViewModel {
  @Trace state: PermissionPageState = new PermissionPageState()

  async loadInitialState(): Promise<void> {
    if (this.state.loading) {
      return
    }
    this.state.loading = true
    this.state.errorMessage = ''
    try {
      let initialData = await PermissionService.loadInitialState()
      this.applyInitialData(initialData)
      this.state.initialized = true
      await this.loadSelectedPermissionProfile()
    } catch (err) {
      LogUtils.warn(TAG, `loadInitialState failed: ${JSON.stringify(err)}`)
      this.state.errorMessage = MessageText.RETRY_LATER
    } finally {
      this.state.loading = false
    }
  }

  async refreshApplications(): Promise<void> {
    if (this.state.loading) {
      return
    }
    this.state.loading = true
    this.state.errorMessage = ''
    try {
      let inventory = await PermissionService.loadApplications(this.state.selectedAccountId)
      this.applyInventory(inventory)
      await this.loadSelectedPermissionProfile()
    } catch (err) {
      LogUtils.warn(TAG, `refreshApplications failed: ${JSON.stringify(err)}`)
      this.state.errorMessage = MessageText.RETRY_LATER
    } finally {
      this.state.loading = false
    }
  }

  setSearchKeyword(keyword: string): void {
    this.state.searchKeyword = keyword
    this.updateFilteredApplications()
  }

  selectApplication(appKey: string): void {
    let exists = this.state.filteredApplications.some((app: ManagedApplicationInfo): boolean => app.key === appKey)
    this.state.selectedAppKey = exists ? appKey : ''
    this.state.selectedPermissionProfile = null
  }

  async selectApplicationAndLoadProfile(appKey: string): Promise<void> {
    this.selectApplication(appKey)
    await this.loadSelectedPermissionProfile()
  }

  async switchAccount(accountId: number): Promise<void> {
    if (this.state.selectedAccountId === accountId && this.state.initialized) {
      return
    }
    this.state.selectedAccountId = accountId
    this.state.selectedAppKey = ''
    this.state.selectedPermissionProfile = null
    await this.refreshApplications()
  }

  async loadSelectedPermissionProfile(): Promise<void> {
    let selectedApp = this.getSelectedApplication()
    if (selectedApp === undefined) {
      this.state.selectedPermissionProfile = null
      return
    }
    try {
      let profile = await PermissionService.loadPermissionProfile(selectedApp)
      if (this.state.selectedAppKey === profile.appKey) {
        this.state.selectedPermissionProfile = profile
      }
    } catch (err) {
      LogUtils.warn(TAG, `loadSelectedPermissionProfile failed: ${JSON.stringify(err)}`)
      this.state.selectedPermissionProfile = null
    }
  }

  async setSelectedInstallPolicy(policy: PermissionPolicyState): Promise<PermissionActionResult> {
    return this.runSelectedAppAction(
      async (app: ManagedApplicationInfo): Promise<PermissionActionResult> =>
        await PermissionService.setInstallPolicy(app, policy),
      (app: ManagedApplicationInfo): void => {
        app.installPolicy = policy
      }
    )
  }

  async setSelectedUninstallProtected(enabled: boolean): Promise<PermissionActionResult> {
    return this.runSelectedAppAction(
      async (app: ManagedApplicationInfo): Promise<PermissionActionResult> =>
        await PermissionService.setUninstallProtected(app, enabled),
      (app: ManagedApplicationInfo): void => {
        app.uninstallProtected = enabled
      }
    )
  }

  async setSelectedRunningPolicy(policy: PermissionPolicyState): Promise<PermissionActionResult> {
    return this.runSelectedAppAction(
      async (app: ManagedApplicationInfo): Promise<PermissionActionResult> =>
        await PermissionService.setRunningPolicy(app, policy),
      (app: ManagedApplicationInfo): void => {
        app.runningPolicy = policy
      }
    )
  }

  async setSelectedNetworkPolicy(policy: PermissionPolicyState): Promise<PermissionActionResult> {
    return this.runSelectedAppAction(
      async (app: ManagedApplicationInfo): Promise<PermissionActionResult> =>
        await PermissionService.setNetworkPolicy(app, policy),
      (app: ManagedApplicationInfo): void => {
        app.networkPolicy = policy
      }
    )
  }

  async setSelectedKeepAlive(enabled: boolean): Promise<PermissionActionResult> {
    return this.runSelectedAppAction(
      async (app: ManagedApplicationInfo): Promise<PermissionActionResult> =>
        await PermissionService.setKeepAlive(app, enabled),
      (app: ManagedApplicationInfo): void => {
        app.keepAliveEnabled = enabled
      }
    )
  }

  async setSelectedAutoStart(enabled: boolean): Promise<PermissionActionResult> {
    return this.runSelectedAppAction(
      async (app: ManagedApplicationInfo): Promise<PermissionActionResult> =>
        await PermissionService.setAutoStart(app, enabled, this.state.selectedPermissionProfile),
      (app: ManagedApplicationInfo): void => {
        app.autoStartEnabled = enabled
      }
    )
  }

  async setSelectedSixDPermissionState(groupKey: string, state: SixDManagedState): Promise<PermissionActionResult> {
    let selectedApp = this.getSelectedApplication()
    if (selectedApp === undefined) {
      return { success: false, message: MessageText.RETRY_LATER } as PermissionActionResult
    }
    if (this.state.processingAction) {
      return { success: false, message: MessageText.RETRY_LATER } as PermissionActionResult
    }
    this.state.processingAction = true
    try {
      let result = await PermissionService.setSixDPermissionState(
        selectedApp,
        this.state.selectedPermissionProfile,
        groupKey,
        state
      )
      await this.loadSelectedPermissionProfile()
      return result
    } finally {
      this.state.processingAction = false
    }
  }

  private applyInitialData(initialData: PermissionInitialData): void {
    this.state.adminActivated = initialData.adminActivated
    this.state.selectedAccountId = initialData.selectedAccountId
    this.state.selectedAppKey = initialData.selectedAppKey
    this.state.inventoryMessage = initialData.inventoryMessage
    this.state.summary = initialData.summary
    this.state.accounts = initialData.accounts
    this.state.applications = initialData.applications
    this.updateFilteredApplications()
  }

  private applyInventory(inventory: ApplicationInventoryResult): void {
    this.state.applications = inventory.applications
    this.state.inventoryMessage = inventory.message ?? ''
    this.state.summary = PermissionService.buildSummary(inventory.applications)
    this.updateFilteredApplications()
  }

  private updateFilteredApplications(): void {
    this.state.filteredApplications = PermissionService.filterApplications(this.state.applications, this.state.searchKeyword)
    if (this.state.filteredApplications.length === 0) {
      this.state.selectedAppKey = ''
      this.state.selectedPermissionProfile = null
      return
    }
    let selectedExists = this.state.filteredApplications.some((app: ManagedApplicationInfo): boolean =>
      app.key === this.state.selectedAppKey
    )
    if (!selectedExists) {
      this.state.selectedAppKey = this.state.filteredApplications[0].key
      this.state.selectedPermissionProfile = null
    }
  }

  private getSelectedApplication(): ManagedApplicationInfo | undefined {
    return this.state.applications.find((app: ManagedApplicationInfo): boolean => app.key === this.state.selectedAppKey)
  }

  private async runSelectedAppAction(
    action: (app: ManagedApplicationInfo) => Promise<PermissionActionResult>,
    applySuccess: (app: ManagedApplicationInfo) => void
  ): Promise<PermissionActionResult> {
    let selectedApp = this.getSelectedApplication()
    if (selectedApp === undefined) {
      return { success: false, message: MessageText.RETRY_LATER } as PermissionActionResult
    }
    if (this.state.processingAction) {
      return { success: false, message: MessageText.RETRY_LATER } as PermissionActionResult
    }
    this.state.processingAction = true
    try {
      let result = await action(selectedApp)
      if (result.success) {
        this.updateSelectedApplication(applySuccess)
      }
      return result
    } finally {
      this.state.processingAction = false
    }
  }

  private updateSelectedApplication(applySuccess: (app: ManagedApplicationInfo) => void): void {
    let selectedKey = this.state.selectedAppKey
    this.state.applications = this.state.applications.map((app: ManagedApplicationInfo): ManagedApplicationInfo => {
      if (app.key === selectedKey) {
        applySuccess(app)
      }
      return app
    })
    this.state.summary = PermissionService.buildSummary(this.state.applications)
    this.updateFilteredApplications()
  }
}
