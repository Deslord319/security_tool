import {
  ApplicationInventoryResult,
  ManagedApplicationInfo,
  PermissionInitialData,
  PermissionPageState
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
  }

  async switchAccount(accountId: number): Promise<void> {
    if (this.state.selectedAccountId === accountId && this.state.initialized) {
      return
    }
    this.state.selectedAccountId = accountId
    this.state.selectedAppKey = ''
    await this.refreshApplications()
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
      return
    }
    let selectedExists = this.state.filteredApplications.some((app: ManagedApplicationInfo): boolean =>
      app.key === this.state.selectedAppKey
    )
    if (!selectedExists) {
      this.state.selectedAppKey = this.state.filteredApplications[0].key
    }
  }
}
