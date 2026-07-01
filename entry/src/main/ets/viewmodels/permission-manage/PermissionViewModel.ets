import {
  AccountInstallPolicySnapshot,
  ApplicationPermissionProfile,
  ApplicationInventoryResult,
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
  PermissionThreeDPolicySnapshot,
  ThreeDManagedState,
  ThreeDPermissionItem,
  ThreeDLoadState
} from '../../models/PermissionModels'
import { PermissionService } from '../../services/permission-manage/PermissionService'
import { MessageText } from '../../constants/StringCatalog'
import { PermissionApplicationStrings } from '../../constants/modules/PermissionStrings'
import { PermissionPolicyLocalRepository } from '../../services/permission-manage/PermissionPolicyLocalRepository'
import { LogUtils } from '../../utils/LogUtils'

const TAG = 'PermissionViewModel'
const PERMISSION_RENDER_READY_DELAY_MS = 32

@ObservedV2
export class PermissionViewModel {
  @Trace state: PermissionPageState = new PermissionPageState()
  private permissionProfileRequestSeq: number = 0

  async loadInitialState(): Promise<void> {
    if (this.state.loading || this.state.initialized) {
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
    this.rebuildDerivedState()
  }

  setInstallBlockKeyword(keyword: string): void {
    this.state.installBlockKeyword = keyword
  }

  selectApplication(appKey: string): void {
    let exists = this.findAppSnapshot(appKey) !== undefined
    this.commitPermissionState({ selectedAppKey: exists ? appKey : '' })
    this.state.loadingSelectedApp = false
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
    this.state.loadingSelectedApp = true
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
        this.commitPermissionState({
          appSnapshots: [],
          installPolicies: []
        })
      }
      this.applyApplicationList(inventory)
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
    this.commitPermissionState({
      selectedAppKey: '',
      appSnapshots: [],
      installPolicies: []
    })
    this.state.loadingSelectedApp = false
    this.permissionProfileRequestSeq++
    let success = await this.refreshApplications()
    if (!success) {
      this.restoreAccountSwitchSnapshot(previousState)
    }
    return success
  }

  private async loadSelectedApplicationDetailsForKey(appKey: string, requestSeq: number): Promise<void> {
    let snapshot = this.findAppSnapshot(appKey)
    if (snapshot === undefined) {
      if (this.state.selectedAppKey === appKey && this.permissionProfileRequestSeq === requestSeq) {
        this.state.loadingSelectedApp = false
      }
      return
    }
    try {
      let permissionProfile = await PermissionService.loadPermissionProfile(snapshot)
      if (this.state.selectedAppKey === appKey && this.permissionProfileRequestSeq === requestSeq) {
        let finalSnapshots = this.state.appSnapshots.map((s: PermissionAppSnapshot): PermissionAppSnapshot => {
          if (s.appKey !== permissionProfile.appKey) return s
          return {
            appKey: s.appKey, accountId: s.accountId, bundleName: s.bundleName,
            appId: s.appId, appIdentifier: s.appIdentifier, label: s.label,
            uid: s.uid, appIndex: s.appIndex,
            uninstallProtected: s.uninstallProtected, runningBlocked: s.runningBlocked, networkBlocked: s.networkBlocked,
            threeDGroups: permissionProfile.threeDGroups,
            threeDPolicies: this.buildThreeDPolicySnapshotsFromGroups(s, permissionProfile.threeDGroups),
            threeDLoadState: 'loaded', threeDMessage: permissionProfile.message
          } as PermissionAppSnapshot
        })
        this.commitPermissionState({
          appSnapshots: finalSnapshots
        })
      }
    } finally {
      if (this.state.selectedAppKey === appKey && this.permissionProfileRequestSeq === requestSeq) {
        this.state.loadingSelectedApp = false
      }
    }
  }

  async setSelectedUninstallProtected(enabled: boolean): Promise<PermissionActionResult> {
    return this.runSelectedAppPolicyAction(
      `uninstall:${this.state.selectedAppKey}`,
      async (snapshot: PermissionAppSnapshot): Promise<PermissionActionResult> =>
        await PermissionService.setUninstallProtected(snapshot, enabled),
      (snapshot: PermissionAppSnapshot): void => {
        this.patchAppSnapshot(snapshot.appKey, { uninstallProtected: enabled })
      }
    )
  }

  async setSelectedRunningPolicy(policy: PermissionPolicyState): Promise<PermissionActionResult> {
    return this.runSelectedAppPolicyAction(
      `running:${this.state.selectedAppKey}`,
      async (snapshot: PermissionAppSnapshot): Promise<PermissionActionResult> =>
        await PermissionService.setRunningBlocked(snapshot, policy === 'denied'),
      (snapshot: PermissionAppSnapshot): void => {
        this.patchAppSnapshot(snapshot.appKey, { runningBlocked: policy === 'denied' })
      }
    )
  }

  async setSelectedNetworkPolicy(policy: PermissionPolicyState): Promise<PermissionActionResult> {
    return this.runSelectedAppPolicyAction(
      `network:${this.state.selectedAppKey}`,
      async (snapshot: PermissionAppSnapshot): Promise<PermissionActionResult> =>
        await PermissionService.setNetworkBlocked(snapshot, policy === 'denied'),
      (snapshot: PermissionAppSnapshot): void => {
        this.patchAppSnapshot(snapshot.appKey, { networkBlocked: policy === 'denied' })
      }
    )
  }

  async setSelectedThreeDPermissionState(groupKey: string, state: ThreeDManagedState): Promise<PermissionActionResult> {
    let snapshot = this.getSelectedAppSnapshot()
    if (snapshot === undefined) {
      return { success: false, message: MessageText.RETRY_LATER } as PermissionActionResult
    }
    if (this.state.processingActionKey.length > 0) {
      return { success: false, message: MessageText.RETRY_LATER } as PermissionActionResult
    }
    let actionKey = this.getThreeDRecordKey(snapshot.appKey, groupKey)
    this.setProcessingAction(actionKey)
    try {
      await this.waitForCommittedState()
      let item = this.getSelectedThreeDItem(groupKey)
      let result = await PermissionService.setThreeDState(
        snapshot,
        this.buildSelectedPermissionProfile(snapshot),
        groupKey,
        state
      )
      if (result.success && item !== undefined) {
        if (state === 'default') {
          await PermissionPolicyLocalRepository.remove(actionKey)
        } else {
          await this.upsertLocalPolicyRecord({
            recordId: actionKey,
            app: snapshot,
            policyType: item.title,
            policyValue: state,
            statusLabel: this.formatThreeDState(state),
            actionKind: 'three-d',
            policyId: groupKey,
            targetName: snapshot.label,
            targetDetail: `${snapshot.bundleName} / ${item.title}`
          })
        }
        this.patchThreeDState(snapshot.appKey, groupKey, state)
      }
      return result
    } finally {
      this.clearProcessingAction()
    }
  }

  async setDisallowedInstallByKeyword(): Promise<PermissionActionResult> {
    if (this.state.processingActionKey.length > 0) {
      return { success: false, message: MessageText.RETRY_LATER } as PermissionActionResult
    }
    this.setProcessingAction('install-deny')
    try {
      await this.waitForCommittedState()
      let policyId = PermissionService.normalizeInstallBlockPolicyId(this.state.installBlockKeyword)
      let result = await PermissionService.setDisallowedInstallPolicyId(this.state.selectedAccountId, policyId)
      if (result.success) {
        this.state.installBlockKeyword = ''
        let nextPolicies = [{
          accountId: this.state.selectedAccountId,
          policyId: policyId,
          policy: 'denied'
        } as AccountInstallPolicySnapshot].concat(
          this.state.installPolicies.filter((policy: AccountInstallPolicySnapshot): boolean =>
            !(policy.accountId === this.state.selectedAccountId && policy.policyId === policyId)
          )
        )
        this.commitPermissionState({ installPolicies: nextPolicies })
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
    if (this.state.processingActionKey.length > 0) {
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
        record,
        this.state.appSnapshots,
        this.state.installPolicies
      )
      if (result.success) {
        if (record.actionKind === 'install-deny' || record.actionKind === 'install-allow') {
          this.patchInstallPolicies(record.policyId)
        } else if (record.actionKind === 'uninstall-protect') {
          this.patchAppSnapshot(record.appKey, { uninstallProtected: false })
        } else if (record.actionKind === 'running') {
          this.patchAppSnapshot(record.appKey, { runningBlocked: false })
        } else if (record.actionKind === 'network') {
          this.patchAppSnapshot(record.appKey, { networkBlocked: false })
        } else if (record.actionKind === 'three-d') {
          await PermissionPolicyLocalRepository.remove(recordKey)
          this.patchThreeDState(record.appKey, record.policyId, 'default')
        }
      }
      return result
    } finally {
      this.clearProcessingAction()
    }
  }

  private applyInitialData(initialData: PermissionInitialData): void {
    this.state.selectedAccountId = initialData.selectedAccountId
    this.state.accounts = initialData.accounts
    let appSnapshots = initialData.appSnapshots
    this.commitPermissionState({
      appSnapshots: appSnapshots,
      installPolicies: initialData.installPolicies,
      selectedAppKey: initialData.selectedAppKey,
      inventoryMessage: initialData.inventoryMessage
    })
  }

  private createAccountSwitchSnapshot(): AccountSwitchSnapshot {
    return {
      selectedAccountId: this.state.selectedAccountId,
      selectedAppKey: this.state.selectedAppKey,
      inventoryMessage: this.state.inventoryMessage,
      appSnapshots: this.state.appSnapshots,
      installPolicies: this.state.installPolicies,
      loadingSelectedApp: this.state.loadingSelectedApp,
      permissionProfileRequestSeq: this.permissionProfileRequestSeq
    } as AccountSwitchSnapshot
  }

  private createTargetSelectionSnapshot(): TargetSelectionSnapshot {
    return {
      selectedAppKey: this.state.selectedAppKey,
      loadingSelectedApp: this.state.loadingSelectedApp,
      permissionProfileRequestSeq: this.permissionProfileRequestSeq
    } as TargetSelectionSnapshot
  }

  private restoreTargetSelectionSnapshot(snapshot: TargetSelectionSnapshot): void {
    this.state.selectedAppKey = snapshot.selectedAppKey
    this.state.loadingSelectedApp = snapshot.loadingSelectedApp
    this.permissionProfileRequestSeq = snapshot.permissionProfileRequestSeq
  }

  private restoreAccountSwitchSnapshot(snapshot: AccountSwitchSnapshot): void {
    this.state.selectedAccountId = snapshot.selectedAccountId
    this.state.loadingSelectedApp = snapshot.loadingSelectedApp
    this.permissionProfileRequestSeq = snapshot.permissionProfileRequestSeq
    this.commitPermissionState({
      appSnapshots: snapshot.appSnapshots,
      installPolicies: snapshot.installPolicies,
      selectedAppKey: snapshot.selectedAppKey,
      inventoryMessage: snapshot.inventoryMessage
    })
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
    let appSnapshots = inventory.appSnapshots.length > 0
      ? this.mergePolicySnapshots(inventory.appSnapshots)
      : []
    this.commitPermissionState({
      appSnapshots: appSnapshots,
      installPolicies: inventory.installPolicies,
      inventoryMessage: inventory.message ?? ''
    })
  }

  private applyApplicationList(inventory: ApplicationInventoryResult): void {
    this.commitPermissionState({
      appSnapshots: this.mergePolicySnapshots(inventory.appSnapshots),
      installPolicies: inventory.installPolicies,
      inventoryMessage: inventory.message ?? ''
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
        appId: snapshot.appId,
        appIdentifier: snapshot.appIdentifier,
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

  private commitPermissionState(update: PermissionStateUpdate): void {
    if (update.appSnapshots !== undefined) {
      this.state.appSnapshots = update.appSnapshots
    }
    if (update.installPolicies !== undefined) {
      this.state.installPolicies = update.installPolicies
    }
    if (update.selectedAppKey !== undefined) {
      this.state.selectedAppKey = update.selectedAppKey
    }
    if (update.inventoryMessage !== undefined) {
      this.state.inventoryMessage = update.inventoryMessage
    }
    this.rebuildDerivedState()
  }

  private rebuildDerivedState(): void {
    this.state.filteredAppKeys = PermissionService.filterAppKeys(this.state.appSnapshots, this.state.searchKeyword)
    if (this.state.filteredAppKeys.length === 0) {
      if (this.hasSelectedApplicationState()) {
        this.clearSelectedApplication()
      }
    } else if (!this.state.filteredAppKeys.includes(this.state.selectedAppKey) && this.state.selectedAppKey.length > 0) {
      this.clearSelectedApplication()
    }
    this.state.policyRecords = PermissionService.buildPolicyRecordsFromState(this.state.appSnapshots, this.state.installPolicies)
    this.state.summary = PermissionService.buildSummaryFromState(this.state.appSnapshots, this.state.policyRecords)
  }

  private findAppSnapshot(appKey: string): PermissionAppSnapshot | undefined {
    return this.state.appSnapshots.find((snapshot: PermissionAppSnapshot): boolean => snapshot.appKey === appKey)
  }

  private getSelectedAppSnapshot(): PermissionAppSnapshot | undefined {
    if (this.state.selectedAppKey.length === 0) {
      return undefined
    }
    return this.findAppSnapshot(this.state.selectedAppKey)
  }

  private getSelectedThreeDItem(groupKey: string): ThreeDPermissionItem | undefined {
    let snapshot = this.findAppSnapshot(this.state.selectedAppKey)
    return snapshot?.threeDGroups.find((item: ThreeDPermissionItem): boolean => item.groupKey === groupKey)
  }

  private buildSelectedPermissionProfile(snapshot: PermissionAppSnapshot): ApplicationPermissionProfile | null {
    return {
      appKey: snapshot.appKey,
      bundleName: snapshot.bundleName,
      requestedPermissions: [],
      mainAbilityName: '',
      sensitivePermissionCount: snapshot.threeDGroups.filter((item: ThreeDPermissionItem): boolean => item.canManage).length,
      message: snapshot.threeDMessage,
      threeDGroups: snapshot.threeDGroups
    } as ApplicationPermissionProfile
  }

  private hasSelectedApplicationState(): boolean {
    return this.state.selectedAppKey.length > 0
  }

  private clearSelectedApplication(): void {
    this.state.selectedAppKey = ''
    this.state.loadingSelectedApp = false
    this.permissionProfileRequestSeq++
  }

  private async waitForCommittedState(): Promise<void> {
    await new Promise<void>((resolve: () => void): void => {
      setTimeout((): void => {
        resolve()
      }, PERMISSION_RENDER_READY_DELAY_MS)
    })
  }

  private async runSelectedAppPolicyAction(
    actionKey: string,
    action: (snapshot: PermissionAppSnapshot) => Promise<PermissionActionResult>,
    onSuccess: (snapshot: PermissionAppSnapshot) => void
  ): Promise<PermissionActionResult> {
    let snapshot = this.getSelectedAppSnapshot()
    if (snapshot === undefined) {
      return { success: false, message: MessageText.RETRY_LATER } as PermissionActionResult
    }
    if (this.state.processingActionKey.length > 0) {
      return { success: false, message: MessageText.RETRY_LATER } as PermissionActionResult
    }
    this.setProcessingAction(actionKey)
    try {
      await this.waitForCommittedState()
      let result = await action(snapshot)
      if (result.success) {
        onSuccess(snapshot)
      }
      return result
    } finally {
      this.clearProcessingAction()
    }
  }

  private setProcessingAction(actionKey: string): void {
    this.state.processingActionKey = actionKey
  }

  private clearProcessingAction(): void {
    this.state.processingActionKey = ''
  }

  private patchAppSnapshot(appKey: string, patch: PermissionAppSnapshotPatch): void {
    let nextSnapshots = this.state.appSnapshots.map((snapshot: PermissionAppSnapshot): PermissionAppSnapshot => {
      if (snapshot.appKey !== appKey) {
        return snapshot
      }
      return {
        appKey: snapshot.appKey,
        accountId: snapshot.accountId,
        bundleName: snapshot.bundleName,
        appId: snapshot.appId,
        appIdentifier: snapshot.appIdentifier,
        label: snapshot.label,
        uid: snapshot.uid,
        appIndex: snapshot.appIndex,
        uninstallProtected: patch.uninstallProtected !== undefined ? patch.uninstallProtected : snapshot.uninstallProtected,
        runningBlocked: patch.runningBlocked !== undefined ? patch.runningBlocked : snapshot.runningBlocked,
        networkBlocked: patch.networkBlocked !== undefined ? patch.networkBlocked : snapshot.networkBlocked,
        threeDGroups: patch.threeDGroups !== undefined ? patch.threeDGroups : snapshot.threeDGroups,
        threeDPolicies: patch.threeDPolicies !== undefined ? patch.threeDPolicies : snapshot.threeDPolicies,
        threeDLoadState: patch.threeDLoadState !== undefined ? patch.threeDLoadState : snapshot.threeDLoadState,
        threeDMessage: patch.threeDMessage !== undefined ? patch.threeDMessage : snapshot.threeDMessage
      } as PermissionAppSnapshot
    })
    this.commitPermissionState({ appSnapshots: nextSnapshots })
  }

  private patchInstallPolicies(removePolicyId: string): void {
    let nextPolicies = this.state.installPolicies.filter(
      (p: AccountInstallPolicySnapshot): boolean => p.policyId !== removePolicyId
    )
    this.commitPermissionState({ installPolicies: nextPolicies })
  }

  private patchThreeDState(appKey: string, groupKey: string, state: ThreeDManagedState): void {
    let snapshot = this.findAppSnapshot(appKey)
    if (snapshot === undefined) {
      return
    }
    let nextGroups = snapshot.threeDGroups.map((item: ThreeDPermissionItem): ThreeDPermissionItem => {
      if (item.groupKey !== groupKey) {
        return item
      }
      return {
        groupKey: item.groupKey,
        title: item.title,
        permissionNames: item.permissionNames,
        declaredPermissions: item.declaredPermissions,
        managedState: state,
        canManage: item.canManage,
        disabledReason: item.disabledReason
      } as ThreeDPermissionItem
    })
    let nextPolicies: PermissionThreeDPolicySnapshot[]
    if (state === 'default') {
      nextPolicies = snapshot.threeDPolicies.filter(
        (p: PermissionThreeDPolicySnapshot): boolean => p.groupKey !== groupKey
      )
    } else {
      let existing = snapshot.threeDPolicies.find(
        (p: PermissionThreeDPolicySnapshot): boolean => p.groupKey === groupKey
      )
      let policyType = existing?.policyType ?? nextGroups.find((i: ThreeDPermissionItem): boolean =>
        i.groupKey === groupKey
      )?.title ?? ''
      let updated: PermissionThreeDPolicySnapshot = {
        recordId: this.getThreeDRecordKey(appKey, groupKey),
        appKey: appKey,
        groupKey: groupKey,
        actionKind: 'three-d',
        policyValue: state,
        policyType: policyType,
        targetName: snapshot.label,
        targetDetail: `${snapshot.bundleName} / ${policyType}`,
        statusLabel: this.formatThreeDState(state),
        scopeLabel: `${PermissionApplicationStrings.POLICY_SCOPE_ACCOUNT_PREFIX} ${snapshot.accountId}`
      } as PermissionThreeDPolicySnapshot
      let found = false
      nextPolicies = snapshot.threeDPolicies.map((p: PermissionThreeDPolicySnapshot): PermissionThreeDPolicySnapshot => {
        if (p.groupKey === groupKey) {
          found = true
          return updated
        }
        return p
      })
      if (!found) {
        nextPolicies.push(updated)
      }
    }
    this.patchAppSnapshot(appKey, { threeDGroups: nextGroups, threeDPolicies: nextPolicies })
  }

  private getThreeDRecordKey(appKey: string, groupKey: string): string {
    return `three-d:${appKey}:${groupKey}`
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

  private async upsertLocalPolicyRecord(params: LocalPolicyRecordParams): Promise<PermissionLocalPolicyRecord> {
    let now = Date.now()
    let record = {
      recordId: params.recordId,
      accountId: params.app.accountId,
      appKey: params.app.appKey,
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

interface PermissionAppSnapshotPatch {
  uninstallProtected?: boolean
  runningBlocked?: boolean
  networkBlocked?: boolean
  threeDGroups?: ThreeDPermissionItem[]
  threeDPolicies?: PermissionThreeDPolicySnapshot[]
  threeDLoadState?: ThreeDLoadState
  threeDMessage?: string
}

interface PermissionStateUpdate {
  appSnapshots?: PermissionAppSnapshot[]
  installPolicies?: AccountInstallPolicySnapshot[]
  selectedAppKey?: string
  inventoryMessage?: string
}

interface LocalPolicyRecordParams {
  recordId: string
  app: PermissionAppSnapshot
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
  appSnapshots: PermissionAppSnapshot[]
  installPolicies: AccountInstallPolicySnapshot[]
  loadingSelectedApp: boolean
  permissionProfileRequestSeq: number
}

interface TargetSelectionSnapshot {
  selectedAppKey: string
  loadingSelectedApp: boolean
  permissionProfileRequestSeq: number
}
