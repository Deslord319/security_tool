import {
  ApplicationPermissionProfile,
  ApplicationInventoryResult,
  ManagedApplicationInfo,
  PermissionActionResult,
  PermissionInitialData,
  PermissionLocalPolicyRecord,
  PermissionPageState,
  PermissionPolicyRecord,
  PermissionPolicyState,
  PermissionSummary,
  SixDManagedState
} from '../../models/PermissionModels'
import { PermissionService } from '../../services/permission-manage/PermissionService'
import { MessageText } from '../../constants/StringCatalog'
import { PermissionApplicationStrings } from '../../constants/modules/PermissionStrings'
import { PermissionPolicyLocalRepository } from '../../services/permission-manage/PermissionPolicyLocalRepository'
import { LogUtils } from '../../utils/LogUtils'

const TAG = 'PermissionViewModel'

@ObservedV2
export class PermissionViewModel {
  @Trace state: PermissionPageState = new PermissionPageState()
  private permissionProfileRequestSeq: number = 0

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

  async refreshApplications(): Promise<boolean> {
    if (this.state.loading) {
      return false
    }
    this.state.loading = true
    this.state.errorMessage = ''
    try {
      let inventory = await PermissionService.loadApplications(this.state.selectedAccountId)
      this.applyInventory(inventory)
      return true
    } catch (err) {
      LogUtils.warn(TAG, `refreshApplications failed: ${JSON.stringify(err)}`)
      this.state.errorMessage = MessageText.RETRY_LATER
      return false
    } finally {
      this.state.loading = false
    }
  }

  async refreshApplicationList(): Promise<boolean> {
    if (this.state.loading) {
      return false
    }
    this.state.loading = true
    this.state.errorMessage = ''
    try {
      let inventory = await PermissionService.loadApplications(this.state.selectedAccountId)
      this.applyApplicationList(inventory)
      return true
    } catch (err) {
      LogUtils.warn(TAG, `refreshApplicationList failed: ${JSON.stringify(err)}`)
      this.state.errorMessage = MessageText.RETRY_LATER
      return false
    } finally {
      this.state.loading = false
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
    let selectedApp = this.state.filteredApplications.find((app: ManagedApplicationInfo): boolean => app.key === appKey)
    this.state.selectedAppKey = selectedApp?.key ?? ''
    this.state.selectedApplication = selectedApp ?? null
    this.state.selectedPermissionProfile = null
    this.state.selectedAppRefreshing = false
    this.state.policyLoading = false
    this.permissionProfileRequestSeq++
  }

  async selectApplicationAndLoadDetails(appKey: string): Promise<void> {
    this.selectApplication(appKey)
    let selectedAppKey = this.state.selectedAppKey
    if (selectedAppKey.length === 0) {
      return
    }
    let requestSeq = this.permissionProfileRequestSeq
    this.state.selectedAppRefreshing = true
    this.state.policyLoading = true
    try {
      await this.waitForCommittedState()
      await this.loadSelectedApplicationDetailsForKey(selectedAppKey, requestSeq)
    } catch (err) {
      LogUtils.warn(TAG, `load selected application details failed: ${JSON.stringify(err)}`)
      if (this.state.selectedAppKey === selectedAppKey && this.permissionProfileRequestSeq === requestSeq) {
        this.state.policyLoading = false
      }
    }
  }

  async switchAccount(accountId: number): Promise<boolean> {
    if (this.state.selectedAccountId === accountId && this.state.initialized) {
      return true
    }
    let previousState = this.createAccountSwitchSnapshot()
    this.state.selectedAccountId = accountId
    this.state.selectedAppKey = ''
    this.state.selectedApplication = null
    this.state.selectedPermissionProfile = null
    this.state.policyRecords = []
    this.state.selectedAppRefreshing = false
    this.state.policyLoading = false
    this.permissionProfileRequestSeq++
    let success = await this.refreshApplications()
    if (!success) {
      this.restoreAccountSwitchSnapshot(previousState)
    }
    return success
  }

  private async loadSelectedPermissionProfileForKey(appKey: string, requestSeq: number): Promise<void> {
    let selectedApp = this.getApplicationByKey(appKey)
    if (selectedApp === undefined) {
      if (this.state.selectedAppKey === appKey && this.permissionProfileRequestSeq === requestSeq) {
        this.state.selectedPermissionProfile = null
      }
      return
    }
    try {
      let profile = await PermissionService.loadPermissionProfile(selectedApp)
      if (this.state.selectedAppKey === profile.appKey && this.permissionProfileRequestSeq === requestSeq) {
        this.state.selectedPermissionProfile = profile
      }
    } catch (err) {
      LogUtils.warn(TAG, `loadSelectedPermissionProfile failed: ${JSON.stringify(err)}`)
      if (this.state.selectedAppKey === appKey && this.permissionProfileRequestSeq === requestSeq) {
        this.state.selectedPermissionProfile = null
      }
    }
  }

  private async loadSelectedApplicationDetailsForKey(appKey: string, requestSeq: number): Promise<void> {
    let selectedApp = this.getApplicationByKey(appKey)
    if (selectedApp === undefined) {
      if (this.state.selectedAppKey === appKey && this.permissionProfileRequestSeq === requestSeq) {
        this.state.selectedAppRefreshing = false
        this.state.policyLoading = false
      }
      return
    }
    try {
      if (this.state.selectedAppKey === appKey && this.permissionProfileRequestSeq === requestSeq) {
        await this.refreshAccountPolicyState(appKey, requestSeq)
      }
      if (this.state.selectedAppKey === appKey && this.permissionProfileRequestSeq === requestSeq) {
        await this.loadSelectedPermissionProfileForKey(appKey, requestSeq)
      }
    } finally {
      if (this.state.selectedAppKey === appKey && this.permissionProfileRequestSeq === requestSeq) {
        this.state.selectedAppRefreshing = false
      }
    }
  }

  async setSelectedUninstallProtected(enabled: boolean): Promise<PermissionActionResult> {
    return this.runSelectedAppPolicyAction(
      `uninstall:${this.state.selectedAppKey}`,
      async (app: ManagedApplicationInfo): Promise<PermissionActionResult> =>
        await PermissionService.setUninstallProtected(app, enabled),
      (): ApplicationPolicyUpdate => ({ uninstallProtected: enabled } as ApplicationPolicyUpdate)
    )
  }

  async setSelectedRunningPolicy(policy: PermissionPolicyState): Promise<PermissionActionResult> {
    return this.runSelectedAppPolicyAction(
      `running:${this.state.selectedAppKey}`,
      async (app: ManagedApplicationInfo): Promise<PermissionActionResult> =>
        await PermissionService.setRunningPolicy(app, policy),
      (): ApplicationPolicyUpdate => ({ runningPolicy: policy } as ApplicationPolicyUpdate)
    )
  }

  async setSelectedNetworkPolicy(policy: PermissionPolicyState): Promise<PermissionActionResult> {
    return this.runSelectedAppPolicyAction(
      `network:${this.state.selectedAppKey}`,
      async (app: ManagedApplicationInfo): Promise<PermissionActionResult> =>
        await PermissionService.setNetworkPolicy(app, policy),
      (): ApplicationPolicyUpdate => ({ networkPolicy: policy } as ApplicationPolicyUpdate)
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
    let actionKey = `sixd:${selectedApp.key}:${groupKey}`
    this.setProcessingAction(actionKey)
    try {
      await this.waitForCommittedState()
      let item = this.state.selectedPermissionProfile?.sixDGroups.find((value): boolean => value.groupKey === groupKey)
      let result = await PermissionService.setSixDPermissionState(
        selectedApp,
        this.state.selectedPermissionProfile,
        groupKey,
        state
      )
      if (result.success && item !== undefined) {
        if (state === 'default') {
          await PermissionPolicyLocalRepository.remove(actionKey)
          this.removePolicyRecord(actionKey)
        } else {
          let localRecord = await this.upsertLocalPolicyRecord({
            recordId: actionKey,
            app: selectedApp,
            policyType: item.title,
            policyValue: state,
            statusLabel: this.formatSixDState(state),
            actionKind: 'sixd',
            policyId: groupKey,
            targetName: selectedApp.label,
            targetDetail: `${selectedApp.bundleName} / ${item.title}`
          })
          this.upsertPolicyRecord(PermissionService.buildPolicyRecordFromLocal(localRecord))
        }
        await this.loadSelectedPermissionProfileForKey(selectedApp.key, this.permissionProfileRequestSeq)
      }
      return result
    } finally {
      this.clearProcessingAction()
    }
  }

  async setDisallowedInstallByKeyword(): Promise<PermissionActionResult> {
    if (this.state.processingAction) {
      return { success: false, message: MessageText.RETRY_LATER } as PermissionActionResult
    }
    this.setProcessingAction('install-deny')
    try {
      await this.waitForCommittedState()
      let packageName = PermissionService.normalizeInstallBlockPackageName(this.state.installBlockKeyword)
      let result = await PermissionService.setDisallowedInstallPolicyId(this.state.selectedAccountId, packageName)
      if (result.success) {
        this.state.installBlockKeyword = ''
        this.upsertPolicyRecord(PermissionService.buildInstallPolicyRecord(
          this.state.selectedAccountId,
          packageName,
          'denied'
        ))
      }
      return result
    } catch (err) {
      LogUtils.warn(TAG, `setDisallowedInstallByKeyword failed: ${JSON.stringify(err)}`)
      return {
        success: false,
        message: PermissionService.mapInstallPolicyTargetError(err)
      } as PermissionActionResult
    } finally {
      this.clearProcessingAction()
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
    this.setProcessingAction(`delete-policy:${recordKey}`)
    try {
      await this.waitForCommittedState()
      let result = await PermissionService.deletePolicyRecord(
        this.state.selectedAccountId,
        record,
        this.state.applications
      )
      if (result.success) {
        if (record.actionKind === 'sixd') {
          await PermissionPolicyLocalRepository.remove(recordKey)
        }
        this.applyDeletedPolicyRecord(record)
        await this.refreshSelectedPermissionProfileAfterDelete(record)
      }
      return result
    } finally {
      this.clearProcessingAction()
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
    this.state.policyRecords = initialData.policyRecords
    this.updateFilteredApplications()
  }

  private createAccountSwitchSnapshot(): AccountSwitchSnapshot {
    return {
      selectedAccountId: this.state.selectedAccountId,
      selectedAppKey: this.state.selectedAppKey,
      selectedApplication: this.state.selectedApplication,
      selectedPermissionProfile: this.state.selectedPermissionProfile,
      inventoryMessage: this.state.inventoryMessage,
      policyRecords: this.state.policyRecords,
      applications: this.state.applications,
      filteredApplications: this.state.filteredApplications,
      summary: this.state.summary,
      selectedAppRefreshing: this.state.selectedAppRefreshing,
      policyLoading: this.state.policyLoading,
      permissionProfileRequestSeq: this.permissionProfileRequestSeq
    } as AccountSwitchSnapshot
  }

  private restoreAccountSwitchSnapshot(snapshot: AccountSwitchSnapshot): void {
    this.state.selectedAccountId = snapshot.selectedAccountId
    this.state.selectedAppKey = snapshot.selectedAppKey
    this.state.selectedApplication = snapshot.selectedApplication
    this.state.selectedPermissionProfile = snapshot.selectedPermissionProfile
    this.state.inventoryMessage = snapshot.inventoryMessage
    this.state.policyRecords = snapshot.policyRecords
    this.state.applications = snapshot.applications
    this.state.filteredApplications = snapshot.filteredApplications
    this.state.summary = snapshot.summary
    this.state.selectedAppRefreshing = snapshot.selectedAppRefreshing
    this.state.policyLoading = snapshot.policyLoading
    this.permissionProfileRequestSeq = snapshot.permissionProfileRequestSeq
  }

  private applyInventory(inventory: ApplicationInventoryResult): void {
    this.state.applications = inventory.applications
    this.state.inventoryMessage = inventory.message ?? ''
    this.state.summary = PermissionService.buildSummary(inventory.applications)
    this.state.policyRecords = inventory.policyRecords
    this.updateFilteredApplications()
  }

  private applyApplicationList(inventory: ApplicationInventoryResult): void {
    this.state.applications = inventory.applications.map((app: ManagedApplicationInfo): ManagedApplicationInfo => {
      let previous = this.state.applications.find((item: ManagedApplicationInfo): boolean => item.key === app.key)
      if (previous !== undefined) {
        app.installPolicy = previous.installPolicy
        app.uninstallProtected = previous.uninstallProtected
        app.runningPolicy = previous.runningPolicy
        app.networkPolicy = previous.networkPolicy
      }
      return app
    })
    this.state.inventoryMessage = inventory.message ?? ''
    let summary = PermissionService.buildSummary(this.state.applications)
    summary.managedCount = this.state.policyRecords.length
    this.state.summary = summary
    this.updateFilteredApplications()
  }

  private applyAccountPolicySnapshot(inventory: ApplicationInventoryResult): void {
    this.state.applications = inventory.applications
    this.state.policyRecords = inventory.policyRecords
    let summary = PermissionService.buildSummary(this.state.applications)
    summary.managedCount = this.state.policyRecords.length
    this.state.summary = summary
    this.updateFilteredApplications()
  }

  private updateFilteredApplications(): void {
    this.state.filteredApplications = PermissionService.filterApplications(this.state.applications, this.state.searchKeyword)
    if (this.state.filteredApplications.length === 0) {
      if (this.hasSelectedApplicationState()) {
        this.clearSelectedApplication()
      }
      return
    }
    let selectedExists = this.state.filteredApplications.some((app: ManagedApplicationInfo): boolean =>
      app.key === this.state.selectedAppKey
    )
    if (!selectedExists && this.state.selectedAppKey.length > 0) {
      this.clearSelectedApplication()
      return
    }
    this.syncSelectedApplicationFromApplications()
  }

  private getSelectedApplication(): ManagedApplicationInfo | undefined {
    return this.state.selectedApplication ?? undefined
  }

  private getApplicationByKey(appKey: string): ManagedApplicationInfo | undefined {
    return this.state.applications.find((app: ManagedApplicationInfo): boolean => app.key === appKey)
  }

  private hasSelectedApplicationState(): boolean {
    return this.state.selectedAppKey.length > 0 ||
      this.state.selectedApplication !== null ||
      this.state.selectedPermissionProfile !== null
  }

  private clearSelectedApplication(): void {
    this.state.selectedAppKey = ''
    this.state.selectedApplication = null
    this.state.selectedPermissionProfile = null
    this.state.selectedAppRefreshing = false
    this.state.policyLoading = false
    this.permissionProfileRequestSeq++
  }

  private syncSelectedApplicationFromApplications(): void {
    if (this.state.selectedAppKey.length === 0) {
      this.state.selectedApplication = null
      return
    }
    this.state.selectedApplication = this.getApplicationByKey(this.state.selectedAppKey) ?? null
  }

  private async refreshAccountPolicyState(appKey: string = '', requestSeq: number = -1): Promise<void> {
    this.state.policyLoading = true
    try {
      let snapshot = await PermissionService.loadAccountPolicySnapshot(this.state.selectedAccountId, this.state.applications)
      if (!this.isCurrentRequest(appKey, requestSeq)) {
        return
      }
      this.applyAccountPolicySnapshot(snapshot)
    } finally {
      if (this.isCurrentRequest(appKey, requestSeq)) {
        this.state.policyLoading = false
      }
    }
  }

  private isCurrentRequest(appKey: string, requestSeq: number): boolean {
    if (requestSeq < 0) {
      return true
    }
    return this.state.selectedAppKey === appKey && this.permissionProfileRequestSeq === requestSeq
  }

  private async waitForCommittedState(): Promise<void> {
    await new Promise<void>((resolve: () => void): void => {
      setTimeout((): void => {
        resolve()
      }, 0)
    })
  }

  private async runSelectedAppPolicyAction(
    actionKey: string,
    action: (app: ManagedApplicationInfo) => Promise<PermissionActionResult>,
    buildUpdate: () => ApplicationPolicyUpdate
  ): Promise<PermissionActionResult> {
    let selectedApp = this.getSelectedApplication()
    if (selectedApp === undefined) {
      return { success: false, message: MessageText.RETRY_LATER } as PermissionActionResult
    }
    if (this.state.processingAction) {
      return { success: false, message: MessageText.RETRY_LATER } as PermissionActionResult
    }
    this.setProcessingAction(actionKey)
    try {
      await this.waitForCommittedState()
      let result = await action(selectedApp)
      if (result.success) {
        this.applySelectedApplicationPolicyUpdate(selectedApp.key, buildUpdate())
      }
      return result
    } finally {
      this.clearProcessingAction()
    }
  }

  private setProcessingAction(actionKey: string): void {
    this.state.processingAction = true
    this.state.processingActionKey = actionKey
  }

  private clearProcessingAction(): void {
    this.state.processingAction = false
    this.state.processingActionKey = ''
  }

  private async refreshSelectedPermissionProfileAfterDelete(record: PermissionPolicyRecord): Promise<void> {
    if (record.actionKind !== 'sixd') {
      return
    }
    if (record.appKey !== this.state.selectedAppKey) {
      return
    }
    await this.loadSelectedPermissionProfileForKey(record.appKey, this.permissionProfileRequestSeq)
  }

  private applySelectedApplicationPolicyUpdate(appKey: string, update: ApplicationPolicyUpdate): void {
    let changed = false
    this.state.applications = this.state.applications.map((app: ManagedApplicationInfo): ManagedApplicationInfo => {
      if (app.key !== appKey) {
        return app
      }
      changed = true
      return this.mergeApplicationPolicyUpdate(app, update)
    })
    if (!changed) {
      return
    }
    this.rebuildApplicationPolicyRecords()
  }

  private upsertPolicyRecord(record: PermissionPolicyRecord): void {
    this.state.policyRecords = [record].concat(
      this.state.policyRecords.filter((item: PermissionPolicyRecord): boolean => item.key !== record.key)
    )
    this.refreshSummaryFromCurrentState()
  }

  private removePolicyRecord(recordKey: string): void {
    this.state.policyRecords = this.state.policyRecords.filter((item: PermissionPolicyRecord): boolean =>
      item.key !== recordKey
    )
    this.refreshSummaryFromCurrentState()
  }

  private applyDeletedPolicyRecord(record: PermissionPolicyRecord): void {
    if (record.actionKind === 'install-deny' || record.actionKind === 'install-allow' || record.actionKind === 'sixd') {
      this.removePolicyRecord(record.key)
      return
    }
    if (record.actionKind === 'uninstall-protect') {
      this.applySelectedApplicationPolicyUpdate(record.appKey, { uninstallProtected: false } as ApplicationPolicyUpdate)
      return
    }
    if (record.actionKind === 'running') {
      this.applySelectedApplicationPolicyUpdate(record.appKey, { runningPolicy: 'default' } as ApplicationPolicyUpdate)
      return
    }
    if (record.actionKind === 'network') {
      this.applySelectedApplicationPolicyUpdate(record.appKey, { networkPolicy: 'default' } as ApplicationPolicyUpdate)
    }
  }

  private rebuildApplicationPolicyRecords(): void {
    let preservedRecords = this.state.policyRecords.filter((record: PermissionPolicyRecord): boolean =>
      !this.isApplicationPolicyActionKind(record.actionKind)
    )
    let installRecords = preservedRecords.filter((record: PermissionPolicyRecord): boolean =>
      this.isInstallPolicyActionKind(record.actionKind)
    )
    let otherRecords = preservedRecords.filter((record: PermissionPolicyRecord): boolean =>
      !this.isInstallPolicyActionKind(record.actionKind)
    )
    this.state.policyRecords = installRecords
      .concat(PermissionService.buildApplicationPolicyRecords(this.state.applications))
      .concat(otherRecords)
    this.refreshSummaryFromCurrentState()
    this.updateFilteredApplications()
  }

  private mergeApplicationPolicyUpdate(
    app: ManagedApplicationInfo,
    update: ApplicationPolicyUpdate
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
      installPolicy: app.installPolicy,
      uninstallProtected: update.uninstallProtected === undefined ? app.uninstallProtected : update.uninstallProtected,
      runningPolicy: update.runningPolicy === undefined ? app.runningPolicy : update.runningPolicy,
      networkPolicy: update.networkPolicy === undefined ? app.networkPolicy : update.networkPolicy
    } as ManagedApplicationInfo
  }

  private refreshSummaryFromCurrentState(): void {
    let summary = PermissionService.buildSummary(this.state.applications)
    summary.managedCount = this.state.policyRecords.length
    this.state.summary = summary
  }

  private isApplicationPolicyActionKind(actionKind: string): boolean {
    return actionKind === 'uninstall-protect' || actionKind === 'running' || actionKind === 'network'
  }

  private isInstallPolicyActionKind(actionKind: string): boolean {
    return actionKind === 'install-deny' || actionKind === 'install-allow'
  }

  private async upsertLocalPolicyRecord(params: LocalPolicyRecordParams): Promise<PermissionLocalPolicyRecord> {
    let now = Date.now()
    let record = {
      recordId: params.recordId,
      accountId: params.app.accountId,
      appKey: params.app.key,
      bundleName: params.app.bundleName,
      appIdentifier: params.app.appIdentifier,
      appIndex: params.app.appIndex,
      policyType: params.policyType,
      policyValue: params.policyValue,
      targetName: params.targetName,
      targetDetail: params.targetDetail,
      statusLabel: params.statusLabel,
      scopeLabel: `${PermissionApplicationStrings.POLICY_SCOPE_ACCOUNT_PREFIX} ${params.app.accountId}`,
      actionKind: params.actionKind,
      policyId: params.policyId,
      status: 'active',
      createdAt: now,
      updatedAt: now,
      lastError: ''
    } as PermissionLocalPolicyRecord
    await PermissionPolicyLocalRepository.upsertActive(record)
    return record
  }

  private formatSixDState(state: SixDManagedState): string {
    if (state === 'granted') {
      return PermissionApplicationStrings.POLICY_ALLOWED
    }
    if (state === 'denied') {
      return PermissionApplicationStrings.POLICY_DENIED
    }
    return PermissionApplicationStrings.POLICY_DEFAULT
  }
}

interface LocalPolicyRecordParams {
  recordId: string
  app: ManagedApplicationInfo
  policyType: string
  policyValue: string
  statusLabel: string
  actionKind: string
  policyId: string
  targetName: string
  targetDetail: string
}

interface ApplicationPolicyUpdate {
  uninstallProtected?: boolean
  runningPolicy?: PermissionPolicyState
  networkPolicy?: PermissionPolicyState
}

interface AccountSwitchSnapshot {
  selectedAccountId: number
  selectedAppKey: string
  selectedApplication: ManagedApplicationInfo | null
  selectedPermissionProfile: ApplicationPermissionProfile | null
  inventoryMessage: string
  policyRecords: PermissionPolicyRecord[]
  applications: ManagedApplicationInfo[]
  filteredApplications: ManagedApplicationInfo[]
  summary: PermissionSummary
  selectedAppRefreshing: boolean
  policyLoading: boolean
  permissionProfileRequestSeq: number
}
