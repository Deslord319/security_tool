import { PermissionInitialData, PermissionPageState } from '../../models/PermissionModels'
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
      let initialData = PermissionService.loadInitialState()
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
    await this.loadInitialState()
  }

  private applyInitialData(initialData: PermissionInitialData): void {
    this.state.adminActivated = initialData.adminActivated
    this.state.selectedAccountId = initialData.selectedAccountId
    this.state.summary = initialData.summary
    this.state.accountOptions = initialData.accountOptions
    this.state.applications = initialData.applications
  }
}
