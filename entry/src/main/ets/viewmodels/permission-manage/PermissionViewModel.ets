import {
  AccountInstallPolicySnapshot,
  ApplicationPermissionProfile,
  ApplicationInventoryResult,
  ManagedApplicationInfo,
  PermissionActionResult,
  PermissionAccountListResult,
  PermissionAppSnapshot,
  PermissionInitialData,
  PermissionLocalPolicyRecord,
  PermissionManagedAccount,
  PermissionPageState,
  PermissionPolicyActionKind,
  PermissionPolicyRecord,
  PermissionPolicyState,
  PermissionSummary,
  PermissionThreeDPolicySnapshot,
  ThreeDManagedState,
  ThreeDPermissionItem
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
    this.state.selectedAppRefreshing = false
    this.state.policyLoading = false
    this.permissionProfileRequestSeq++
  }

  async selectApplicationAndLoadDetails(appKey: string): Promise<boolean> {
    let previousState = this.createTargetSelectionSnapshot()
    this.state.errorMessage = ''
    this.selectApplication(appKey)
    let selectedAppKey = this.state.selectedAppKey
    if (selectedAppKey.length === 0) {
      return true
    }
    let requestSeq = this.permissionProfileRequestSeq
    this.state.selectedAppRefreshing = true
    this.state.policyLoading = true
    try {
      await this.waitForCommittedState()
      await this.loadSelectedApplicationDetailsForKey(selectedAppKey, requestSeq)
      return true
    } catch (err) {
      LogUtils.warn(TAG, `load selected application details failed: ${JSON.stringify(err)}`)
      if (this.state.selectedAppKey === selectedAppKey && this.permissionProfileRequestSeq === requestSeq) {
        this.state.errorMessage = PermissionApplicationStrings.POLICY_READ_FAILED
        this.restoreTargetSelectionSnapshot(previousState)
      }
      return false
    }
  }

  async refreshAccountsAndApplicationList(): Promise<boolean> {
    if (this.state.loading) {
      return false
    }
    this.state.loading = true
    this.state.errorMessage = ''
    try {
      let accountResult = await PermissionService.loadAccounts()
      let selectedAccountId = this.resolveRefreshedAccountId(accountResult)
      let inventory = await PermissionService.loadApplications(selectedAccountId)
      let accountChanged = this.state.selectedAccountId !== selectedAccountId
      this.state.accounts = accountResult.accounts
      this.state.selectedAccountId = selectedAccountId
      if (accountChanged) {
        this.clearSelectedApplication()
        this.state.policyRecords = []
        this.state.appSnapshots = []
        this.state.installPolicies = []
        this.state.filteredAppKeys = []
      }
      this.applyApplicationList({
        applications: inventory.applications,
        appSnapshots: inventory.appSnapshots,
        installPolicies: inventory.installPolicies,
        policyRecords: inventory.policyRecords,
        message: inventory.message ?? accountResult.message
      } as ApplicationInventoryResult)
      return true
    } catch (err) {
      LogUtils.warn(TAG, `refreshAccountsAndApplicationList failed: ${JSON.stringify(err)}`)
      this.state.errorMessage = MessageText.RETRY_LATER
      return false
    } finally {
      this.state.loading = false
    }
  }

  async switchAccount(accountId: number): Promise<boolean> {
    if (this.state.selectedAccountId === accountId && this.state.initialized) {
      return true
    }
    let previousState = this.createAccountSwitchSnapshot()
    this.state.selectedAccountId = accountId
    this.state.selectedAppKey = ''
    this.state.policyRecords = []
    this.state.appSnapshots = []
    this.state.installPolicies = []
    this.state.filteredAppKeys = []
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
      return
    }
    try {
      let profile = await PermissionService.loadPermissionProfile(selectedApp)
      if (this.state.selectedAppKey === profile.appKey && this.permissionProfileRequestSeq === requestSeq) {
        this.applySelectedPermissionProfile(profile)
      }
    } catch (err) {
      LogUtils.warn(TAG, `loadSelectedPermissionProfile failed: ${JSON.stringify(err)}`)
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
      let policySnapshotPromise = PermissionService.loadAccountPolicySnapshot(
        this.state.selectedAccountId,
        this.state.applications
      )
      let permissionProfilePromise = PermissionService.loadPermissionProfile(selectedApp)
      let policySnapshot = await policySnapshotPromise
      let permissionProfile = await permissionProfilePromise
      if (this.state.selectedAppKey === appKey && this.permissionProfileRequestSeq === requestSeq) {
        this.applyAccountPolicySnapshot(policySnapshot)
        this.applySelectedPermissionProfile(permissionProfile)
      }
    } finally {
      if (this.state.selectedAppKey === appKey && this.permissionProfileRequestSeq === requestSeq) {
        this.state.selectedAppRefreshing = false
        this.state.policyLoading = false
      }
    }
  }

  async setSelectedUninstallProtected(enabled: boolean): Promise<PermissionActionResult> {
    return this.runSelectedAppPolicyAction(
      `uninstall:${this.state.selectedAppKey}`,
      async (app: ManagedApplicationInfo): Promise<PermissionActionResult> =>
        await PermissionService.setUninstallProtected(app, enabled)
    )
  }

  async setSelectedRunningPolicy(policy: PermissionPolicyState): Promise<PermissionActionResult> {
    return this.runSelectedAppPolicyAction(
      `running:${this.state.selectedAppKey}`,
      async (app: ManagedApplicationInfo): Promise<PermissionActionResult> =>
        await PermissionService.setRunningPolicy(app, policy)
    )
  }

  async setSelectedNetworkPolicy(policy: PermissionPolicyState): Promise<PermissionActionResult> {
    return this.runSelectedAppPolicyAction(
      `network:${this.state.selectedAppKey}`,
      async (app: ManagedApplicationInfo): Promise<PermissionActionResult> =>
        await PermissionService.setNetworkPolicy(app, policy)
    )
  }

  async setSelectedThreeDPermissionState(groupKey: string, state: ThreeDManagedState): Promise<PermissionActionResult> {
    let selectedApp = this.getSelectedApplication()
    if (selectedApp === undefined) {
      return { success: false, message: MessageText.RETRY_LATER } as PermissionActionResult
    }
    if (this.state.processingAction) {
      return { success: false, message: MessageText.RETRY_LATER } as PermissionActionResult
    }
    let actionKey = this.getThreeDRecordKey(selectedApp.key, groupKey)
    this.setProcessingAction(actionKey)
    try {
      await this.waitForCommittedState()
      let item = this.getSelectedThreeDItem(groupKey)
      let result = await PermissionService.setThreeDPermissionState(
        selectedApp,
        this.buildSelectedPermissionProfile(selectedApp),
        groupKey,
        state
      )
      if (result.success && item !== undefined) {
        if (state === 'default') {
          await PermissionPolicyLocalRepository.remove(actionKey)
        } else {
          await this.upsertLocalPolicyRecord({
            recordId: actionKey,
            app: selectedApp,
            policyType: item.title,
            policyValue: state,
            statusLabel: this.formatThreeDState(state),
            actionKind: 'three-d',
            policyId: groupKey,
            targetName: selectedApp.label,
            targetDetail: `${selectedApp.bundleName} / ${item.title}`
          })
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
        await this.refreshAccountPolicyState()
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
        if (record.actionKind === 'three-d') {
          await PermissionPolicyLocalRepository.remove(recordKey)
          this.removeThreeDPolicySnapshot(record)
          await this.refreshSelectedPermissionProfileAfterDelete(record)
        } else {
          await this.refreshAccountPolicyState()
        }
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
    this.state.accounts = initialData.accounts
    this.state.appSnapshots = initialData.appSnapshots.length > 0
      ? initialData.appSnapshots
      : PermissionService.buildDefaultAppSnapshots(initialData.applications)
    this.state.installPolicies = initialData.installPolicies
    this.deriveVisibleStateFromSnapshots()
  }

  private createAccountSwitchSnapshot(): AccountSwitchSnapshot {
    return {
      selectedAccountId: this.state.selectedAccountId,
      selectedAppKey: this.state.selectedAppKey,
      inventoryMessage: this.state.inventoryMessage,
      policyRecords: this.state.policyRecords,
      applications: this.state.applications,
      filteredApplications: this.state.filteredApplications,
      appSnapshots: this.state.appSnapshots,
      installPolicies: this.state.installPolicies,
      filteredAppKeys: this.state.filteredAppKeys,
      summary: this.state.summary,
      selectedAppRefreshing: this.state.selectedAppRefreshing,
      policyLoading: this.state.policyLoading,
      permissionProfileRequestSeq: this.permissionProfileRequestSeq
    } as AccountSwitchSnapshot
  }

  private createTargetSelectionSnapshot(): TargetSelectionSnapshot {
    return {
      selectedAppKey: this.state.selectedAppKey,
      selectedAppRefreshing: this.state.selectedAppRefreshing,
      policyLoading: this.state.policyLoading,
      permissionProfileRequestSeq: this.permissionProfileRequestSeq
    } as TargetSelectionSnapshot
  }

  private restoreTargetSelectionSnapshot(snapshot: TargetSelectionSnapshot): void {
    this.state.selectedAppKey = snapshot.selectedAppKey
    this.state.selectedAppRefreshing = snapshot.selectedAppRefreshing
    this.state.policyLoading = snapshot.policyLoading
    this.permissionProfileRequestSeq = snapshot.permissionProfileRequestSeq
  }

  private restoreAccountSwitchSnapshot(snapshot: AccountSwitchSnapshot): void {
    this.state.selectedAccountId = snapshot.selectedAccountId
    this.state.selectedAppKey = snapshot.selectedAppKey
    this.state.inventoryMessage = snapshot.inventoryMessage
    this.state.policyRecords = snapshot.policyRecords
    this.state.applications = snapshot.applications
    this.state.filteredApplications = snapshot.filteredApplications
    this.state.appSnapshots = snapshot.appSnapshots
    this.state.installPolicies = snapshot.installPolicies
    this.state.filteredAppKeys = snapshot.filteredAppKeys
    this.state.summary = snapshot.summary
    this.state.selectedAppRefreshing = snapshot.selectedAppRefreshing
    this.state.policyLoading = snapshot.policyLoading
    this.permissionProfileRequestSeq = snapshot.permissionProfileRequestSeq
  }

  private resolveRefreshedAccountId(accountResult: PermissionAccountListResult): number {
    let currentExists = accountResult.accounts.some((account: PermissionManagedAccount): boolean =>
      account.accountId === this.state.selectedAccountId
    )
    if (currentExists) {
      return this.state.selectedAccountId
    }
    let fallbackExists = accountResult.accounts.some((account: PermissionManagedAccount): boolean =>
      account.accountId === accountResult.selectedAccountId
    )
    if (fallbackExists || accountResult.accounts.length === 0) {
      return accountResult.selectedAccountId
    }
    return accountResult.accounts[0].accountId
  }

  private applyInventory(inventory: ApplicationInventoryResult): void {
    this.state.appSnapshots = inventory.appSnapshots.length > 0
      ? this.mergePolicySnapshots(inventory.appSnapshots)
      : this.mergeApplicationListIntoSnapshots(inventory.applications)
    this.state.installPolicies = inventory.installPolicies
    this.state.inventoryMessage = inventory.message ?? ''
    this.deriveVisibleStateFromSnapshots()
  }

  private applyApplicationList(inventory: ApplicationInventoryResult): void {
    this.state.appSnapshots = this.mergeApplicationListIntoSnapshots(inventory.applications)
    this.state.inventoryMessage = inventory.message ?? ''
    this.deriveVisibleStateFromSnapshots()
  }

  private applyAccountPolicySnapshot(inventory: ApplicationInventoryResult): void {
    this.state.appSnapshots = this.mergePolicySnapshots(inventory.appSnapshots)
    this.state.installPolicies = inventory.installPolicies
    this.state.inventoryMessage = inventory.message ?? this.state.inventoryMessage
    this.deriveVisibleStateFromSnapshots()
  }

  private mergeApplicationListIntoSnapshots(applications: ManagedApplicationInfo[]): PermissionAppSnapshot[] {
    return applications.map((app: ManagedApplicationInfo): PermissionAppSnapshot => {
      let previous = this.findAppSnapshot(app.key)
      if (previous === undefined) {
        return PermissionService.buildDefaultAppSnapshots([app])[0]
      }
      return this.mergeApplicationMetadata(previous, app)
    })
  }

  private mergePolicySnapshots(nextSnapshots: PermissionAppSnapshot[]): PermissionAppSnapshot[] {
    return nextSnapshots.map((snapshot: PermissionAppSnapshot): PermissionAppSnapshot => {
      let previous = this.findAppSnapshot(snapshot.appKey)
      if (previous === undefined || previous.threeDLoadState !== 'loaded') {
        return snapshot
      }
      let nextGroups = snapshot.threeDGroups.length > 0 ? snapshot.threeDGroups : previous.threeDGroups
      let nextPolicies = snapshot.threeDPolicies.length > 0
        ? snapshot.threeDPolicies
        : this.buildThreeDPolicySnapshotsFromGroups(snapshot, nextGroups)
      return {
        appKey: snapshot.appKey,
        accountId: snapshot.accountId,
        bundleName: snapshot.bundleName,
        label: snapshot.label,
        uid: snapshot.uid,
        appIndex: snapshot.appIndex,
        uninstallProtected: snapshot.uninstallProtected,
        runningBlocked: snapshot.runningBlocked,
        networkBlocked: snapshot.networkBlocked,
        threeDGroups: nextGroups,
        threeDPolicies: nextPolicies,
        threeDLoadState: previous.threeDLoadState,
        threeDMessage: previous.threeDMessage
      } as PermissionAppSnapshot
    })
  }

  private mergeApplicationMetadata(
    previous: PermissionAppSnapshot,
    app: ManagedApplicationInfo
  ): PermissionAppSnapshot {
    return {
      appKey: app.key,
      accountId: app.accountId,
      bundleName: app.bundleName,
      label: app.label,
      uid: app.uid,
      appIndex: app.appIndex,
      uninstallProtected: previous.uninstallProtected,
      runningBlocked: previous.runningBlocked,
      networkBlocked: previous.networkBlocked,
      threeDGroups: previous.threeDGroups,
      threeDPolicies: previous.threeDPolicies,
      threeDLoadState: previous.threeDLoadState,
      threeDMessage: previous.threeDMessage
    } as PermissionAppSnapshot
  }

  private deriveVisibleStateFromSnapshots(): void {
    this.state.applications = this.state.appSnapshots.map((snapshot: PermissionAppSnapshot): ManagedApplicationInfo =>
      this.toManagedApplication(snapshot)
    )
    this.state.policyRecords = PermissionService.buildPolicyRecordsFromSnapshots(
      this.state.appSnapshots,
      this.state.installPolicies
    )
    this.state.summary = PermissionService.buildSummaryFromSnapshots(this.state.appSnapshots, this.state.policyRecords)
    this.updateFilteredApplications()
  }

  private toManagedApplication(snapshot: PermissionAppSnapshot): ManagedApplicationInfo {
    let previous = this.state.applications.find((app: ManagedApplicationInfo): boolean => app.key === snapshot.appKey)
    return {
      key: snapshot.appKey,
      accountId: snapshot.accountId,
      bundleName: snapshot.bundleName,
      appIdentifier: previous?.appIdentifier ?? '',
      appIndex: snapshot.appIndex,
      uid: snapshot.uid,
      label: snapshot.label,
      versionName: previous?.versionName ?? '',
      iconData: previous?.iconData ?? '',
      systemApp: previous?.systemApp ?? false,
      removable: previous?.removable ?? true,
      installSource: previous?.installSource ?? '',
      appDistributionType: previous?.appDistributionType ?? '',
      mainAbilityName: previous?.mainAbilityName ?? '',
      installPolicy: 'default',
      uninstallProtected: snapshot.uninstallProtected,
      runningPolicy: snapshot.runningBlocked ? 'denied' : 'default',
      networkPolicy: snapshot.networkBlocked ? 'denied' : 'default'
    } as ManagedApplicationInfo
  }

  private findAppSnapshot(appKey: string): PermissionAppSnapshot | undefined {
    return this.state.appSnapshots.find((snapshot: PermissionAppSnapshot): boolean => snapshot.appKey === appKey)
  }

  private updateFilteredApplications(): void {
    this.state.filteredApplications = PermissionService.filterApplications(this.state.applications, this.state.searchKeyword)
    this.state.filteredAppKeys = this.state.filteredApplications.map((app: ManagedApplicationInfo): string => app.key)
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
  }

  private getSelectedApplication(): ManagedApplicationInfo | undefined {
    if (this.state.selectedAppKey.length === 0) {
      return undefined
    }
    return this.getApplicationByKey(this.state.selectedAppKey)
  }

  private getSelectedThreeDItem(groupKey: string): ThreeDPermissionItem | undefined {
    let snapshot = this.findAppSnapshot(this.state.selectedAppKey)
    return snapshot?.threeDGroups.find((item: ThreeDPermissionItem): boolean => item.groupKey === groupKey)
  }

  private buildSelectedPermissionProfile(app: ManagedApplicationInfo): ApplicationPermissionProfile | null {
    let snapshot = this.findAppSnapshot(app.key)
    if (snapshot === undefined) {
      return null
    }
    return {
      appKey: snapshot.appKey,
      bundleName: snapshot.bundleName,
      requestedPermissions: [],
      mainAbilityName: app.mainAbilityName,
      sensitivePermissionCount: snapshot.threeDGroups.filter((item: ThreeDPermissionItem): boolean => item.canManage).length,
      message: snapshot.threeDMessage,
      threeDGroups: snapshot.threeDGroups
    } as ApplicationPermissionProfile
  }

  private getApplicationByKey(appKey: string): ManagedApplicationInfo | undefined {
    return this.state.applications.find((app: ManagedApplicationInfo): boolean => app.key === appKey)
  }

  private hasSelectedApplicationState(): boolean {
    return this.state.selectedAppKey.length > 0
  }

  private clearSelectedApplication(): void {
    this.state.selectedAppKey = ''
    this.state.selectedAppRefreshing = false
    this.state.policyLoading = false
    this.permissionProfileRequestSeq++
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
    action: (app: ManagedApplicationInfo) => Promise<PermissionActionResult>
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
        await this.refreshAccountPolicyState(selectedApp.key, this.permissionProfileRequestSeq)
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

  private getThreeDRecordKey(appKey: string, groupKey: string): string {
    return `three-d:${appKey}:${groupKey}`
  }

  private applySelectedPermissionProfile(profile: ApplicationPermissionProfile): void {
    this.state.appSnapshots = this.state.appSnapshots.map((snapshot: PermissionAppSnapshot): PermissionAppSnapshot => {
      if (snapshot.appKey !== profile.appKey) {
        return snapshot
      }
      return {
        appKey: snapshot.appKey,
        accountId: snapshot.accountId,
        bundleName: snapshot.bundleName,
        label: snapshot.label,
        uid: snapshot.uid,
        appIndex: snapshot.appIndex,
        uninstallProtected: snapshot.uninstallProtected,
        runningBlocked: snapshot.runningBlocked,
        networkBlocked: snapshot.networkBlocked,
        threeDGroups: profile.threeDGroups,
        threeDPolicies: this.buildThreeDPolicySnapshotsFromGroups(snapshot, profile.threeDGroups),
        threeDLoadState: 'loaded',
        threeDMessage: profile.message
      } as PermissionAppSnapshot
    })
    this.deriveVisibleStateFromSnapshots()
  }

  private buildThreeDPolicySnapshotsFromGroups(
    snapshot: PermissionAppSnapshot,
    groups: ThreeDPermissionItem[]
  ): PermissionThreeDPolicySnapshot[] {
    return groups
      .filter((item: ThreeDPermissionItem): boolean =>
        item.canManage && (item.managedState === 'granted' || item.managedState === 'denied')
      )
      .map((item: ThreeDPermissionItem): PermissionThreeDPolicySnapshot => ({
        recordId: this.getThreeDRecordKey(snapshot.appKey, item.groupKey),
        appKey: snapshot.appKey,
        groupKey: item.groupKey,
        actionKind: 'three-d',
        policyValue: item.managedState,
        policyType: item.title,
        targetName: snapshot.label,
        targetDetail: `${snapshot.bundleName} / ${item.title}`,
        statusLabel: this.formatThreeDState(item.managedState),
        scopeLabel: `${PermissionApplicationStrings.POLICY_SCOPE_ACCOUNT_PREFIX} ${snapshot.accountId}`
      } as PermissionThreeDPolicySnapshot))
  }

  private removeThreeDPolicySnapshot(record: PermissionPolicyRecord): void {
    this.state.appSnapshots = this.state.appSnapshots.map((snapshot: PermissionAppSnapshot): PermissionAppSnapshot => {
      if (snapshot.appKey !== record.appKey) {
        return snapshot
      }
      let groups = snapshot.threeDGroups.map((item: ThreeDPermissionItem): ThreeDPermissionItem => {
        if (item.groupKey !== record.policyId) {
          return item
        }
        return {
          groupKey: item.groupKey,
          title: item.title,
          permissionNames: item.permissionNames,
          declaredPermissions: item.declaredPermissions,
          managedState: 'default',
          canManage: item.canManage,
          disabledReason: item.disabledReason
        } as ThreeDPermissionItem
      })
      return {
        appKey: snapshot.appKey,
        accountId: snapshot.accountId,
        bundleName: snapshot.bundleName,
        label: snapshot.label,
        uid: snapshot.uid,
        appIndex: snapshot.appIndex,
        uninstallProtected: snapshot.uninstallProtected,
        runningBlocked: snapshot.runningBlocked,
        networkBlocked: snapshot.networkBlocked,
        threeDGroups: groups,
        threeDPolicies: snapshot.threeDPolicies.filter((policy: PermissionThreeDPolicySnapshot): boolean =>
          policy.groupKey !== record.policyId
        ),
        threeDLoadState: snapshot.threeDLoadState,
        threeDMessage: snapshot.threeDMessage
      } as PermissionAppSnapshot
    })
    this.deriveVisibleStateFromSnapshots()
  }

  private async refreshSelectedPermissionProfileAfterDelete(record: PermissionPolicyRecord): Promise<void> {
    if (record.actionKind !== 'three-d') {
      return
    }
    if (record.appKey !== this.state.selectedAppKey) {
      return
    }
    await this.loadSelectedPermissionProfileForKey(record.appKey, this.permissionProfileRequestSeq)
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

  private formatThreeDState(state: ThreeDManagedState): string {
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
  actionKind: PermissionPolicyActionKind
  policyId: string
  targetName: string
  targetDetail: string
}

interface AccountSwitchSnapshot {
  selectedAccountId: number
  selectedAppKey: string
  inventoryMessage: string
  policyRecords: PermissionPolicyRecord[]
  applications: ManagedApplicationInfo[]
  filteredApplications: ManagedApplicationInfo[]
  appSnapshots: PermissionAppSnapshot[]
  installPolicies: AccountInstallPolicySnapshot[]
  filteredAppKeys: string[]
  summary: PermissionSummary
  selectedAppRefreshing: boolean
  policyLoading: boolean
  permissionProfileRequestSeq: number
}

interface TargetSelectionSnapshot {
  selectedAppKey: string
  selectedAppRefreshing: boolean
  policyLoading: boolean
  permissionProfileRequestSeq: number
}
