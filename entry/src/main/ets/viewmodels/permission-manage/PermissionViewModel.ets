import {
  ApplicationPermissionProfile,
  ApplicationInventoryResult,
  ManagedApplicationInfo,
  PermissionActionResult,
  PermissionInitialData,
  PermissionPageState,
  PermissionPolicyRecord,
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
  private policyRefreshPromise: Promise<void> | null = null
  private policyRefreshRerunRequested: boolean = false

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
    } catch (err) {
      LogUtils.warn(TAG, `loadInitialState failed: ${JSON.stringify(err)}`)
      this.state.errorMessage = MessageText.RETRY_LATER
    } finally {
      this.state.loading = false
    }
    if (this.state.initialized) {
      this.refreshPolicyStates().catch((err: Error) => {
        LogUtils.warn(TAG, `load initial policy snapshot failed: ${JSON.stringify(err)}`)
      })
      this.loadSelectedPermissionProfile().catch((err: Error) => {
        LogUtils.warn(TAG, `load initial permission profile failed: ${JSON.stringify(err)}`)
      })
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
    } catch (err) {
      LogUtils.warn(TAG, `refreshApplications failed: ${JSON.stringify(err)}`)
      this.state.errorMessage = MessageText.RETRY_LATER
    } finally {
      this.state.loading = false
    }
    if (this.state.initialized) {
      this.refreshPolicyStates().catch((err: Error) => {
        LogUtils.warn(TAG, `load refreshed policy snapshot failed: ${JSON.stringify(err)}`)
      })
      this.loadSelectedPermissionProfile().catch((err: Error) => {
        LogUtils.warn(TAG, `load refreshed permission profile failed: ${JSON.stringify(err)}`)
      })
    }
  }

  setSearchKeyword(keyword: string): void {
    this.state.searchKeyword = keyword
    this.updateFilteredApplications()
  }

  setInstallBlockKeyword(keyword: string): void {
    this.state.installBlockKeyword = keyword
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

  async refreshPolicyStates(): Promise<void> {
    if (!this.state.initialized) {
      return
    }
    if (this.policyRefreshPromise) {
      this.policyRefreshRerunRequested = true
      await this.policyRefreshPromise
      return
    }
    this.policyRefreshPromise = this.runPolicyRefreshLoop()
    await this.policyRefreshPromise
  }

  private async runPolicyRefreshLoop(): Promise<void> {
    try {
      do {
        this.policyRefreshRerunRequested = false
        await this.refreshPolicyStatesOnce()
      } while (this.policyRefreshRerunRequested && this.state.initialized)
    } finally {
      this.policyRefreshPromise = null
      this.policyRefreshRerunRequested = false
    }
  }

  private async refreshPolicyStatesOnce(): Promise<void> {
    let accountId = this.state.selectedAccountId
    let applications = this.state.applications
    this.state.policyLoading = true
    try {
      let snapshot = await PermissionService.loadPolicySnapshot(accountId, applications)
      if (this.state.selectedAccountId === accountId) {
        this.applyPolicySnapshot(snapshot)
      }
    } catch (err) {
      LogUtils.warn(TAG, `refreshPolicyStates failed: ${JSON.stringify(err)}`)
      if (this.state.selectedAccountId === accountId) {
        this.state.policyRecords = []
      }
    } finally {
      if (this.state.selectedAccountId === accountId) {
        this.state.policyLoading = false
      }
    }
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

  async setDisallowedInstallByKeyword(): Promise<PermissionActionResult> {
    if (this.state.processingAction) {
      return { success: false, message: MessageText.RETRY_LATER } as PermissionActionResult
    }
    this.state.processingAction = true
    try {
      let packageName = PermissionService.normalizeInstallBlockPackageName(this.state.installBlockKeyword)
      let result = await PermissionService.setDisallowedInstallPolicyId(this.state.selectedAccountId, packageName)
      if (result.success) {
        this.updateInstalledApplicationInstallPolicy(packageName)
        this.state.installBlockKeyword = ''
        await this.refreshPolicyStates()
      }
      return result
    } catch (err) {
      LogUtils.warn(TAG, `setDisallowedInstallByKeyword failed: ${JSON.stringify(err)}`)
      return {
        success: false,
        message: PermissionService.mapInstallPolicyTargetError(err)
      } as PermissionActionResult
    } finally {
      this.state.processingAction = false
    }
  }

  async deletePolicyRecord(recordKey: string): Promise<PermissionActionResult> {
    if (this.state.processingAction) {
      return { success: false, message: MessageText.RETRY_LATER } as PermissionActionResult
    }
    let record = this.state.policyRecords.find((item: PermissionPolicyRecord): boolean => item.key === recordKey)
    if (record === undefined) {
      return { success: false, message: MessageText.RETRY_LATER } as PermissionActionResult
    }
    this.state.processingAction = true
    try {
      let result = await PermissionService.deletePolicyRecord(
        this.state.selectedAccountId,
        record,
        this.state.applications
      )
      if (result.success) {
        await this.refreshPolicyStates()
      }
      return result
    } finally {
      this.state.processingAction = false
    }
  }

  private updateInstalledApplicationInstallPolicy(packageName: string): void {
    let installedApp = this.state.applications.find((app: ManagedApplicationInfo): boolean =>
      app.bundleName === packageName
    )
    if (installedApp === undefined) {
      return
    }
    this.updateApplicationByKey(installedApp.key, (app: ManagedApplicationInfo): void => {
      app.installPolicy = 'denied'
    })
  }

  private applyInitialData(initialData: PermissionInitialData): void {
    this.state.adminActivated = initialData.adminActivated
    this.state.selectedAccountId = initialData.selectedAccountId
    this.state.selectedAppKey = initialData.selectedAppKey
    this.state.inventoryMessage = initialData.inventoryMessage
    this.state.summary = initialData.summary
    this.state.accounts = initialData.accounts
    this.state.applications = initialData.applications
    this.state.policyRecords = initialData.policyRecords
    this.updateFilteredApplications()
  }

  private applyInventory(inventory: ApplicationInventoryResult): void {
    this.state.applications = inventory.applications
    this.state.inventoryMessage = inventory.message ?? ''
    this.state.summary = PermissionService.buildSummary(inventory.applications)
    this.state.policyRecords = inventory.policyRecords
    this.updateFilteredApplications()
  }

  private applyPolicySnapshot(inventory: ApplicationInventoryResult): void {
    this.state.applications = inventory.applications
    let summary = PermissionService.buildSummary(inventory.applications)
    summary.managedCount = inventory.policyRecords.length
    this.state.summary = summary
    this.state.policyRecords = inventory.policyRecords
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
        await this.refreshPolicyStates()
      }
      return result
    } finally {
      this.state.processingAction = false
    }
  }

  private updateSelectedApplication(applySuccess: (app: ManagedApplicationInfo) => void): void {
    this.updateApplicationByKey(this.state.selectedAppKey, applySuccess)
  }

  private updateApplicationByKey(
    appKey: string,
    applySuccess: (app: ManagedApplicationInfo) => void
  ): void {
    this.state.applications = this.state.applications.map((app: ManagedApplicationInfo): ManagedApplicationInfo => {
      if (app.key === appKey) {
        applySuccess(app)
      }
      return app
    })
    this.state.summary = PermissionService.buildSummary(this.state.applications)
    this.updateFilteredApplications()
  }
}
