import {
  AccountInstallPolicySnapshot,
  ApplicationInventoryResult,
  PermissionActionResult,
  PermissionAppSnapshot,
  PermissionInitialData,
  PermissionPageState,
  PermissionPolicyRecord,
  PermissionPolicyState,
  ThreeDPermissionItem,
  ThreeDManagedState
} from '../../models/PermissionModels'
import { PermissionService } from '../../services/permission-manage/PermissionService'
import { MessageText } from '../../constants/StringCatalog'
import { PermissionApplicationStrings } from '../../constants/modules/PermissionStrings'
import { PermissionPolicyLocalRepository } from '../../services/permission-manage/PermissionPolicyLocalRepository'
import { LogUtils } from '../../utils/LogUtils'
import { PermissionAccountRefreshUseCase } from './PermissionAccountRefreshUseCase'
import {
  PermissionPolicyActionUseCase,
  PreparedPolicyRecordContext,
  PreparedSelectedAppContext
} from './PermissionPolicyActionUseCase'
import { PermissionPolicyRecordMapper } from './PermissionPolicyRecordMapper'
import {
  PermissionAppSnapshotPatch,
  PermissionStateReducer,
  PermissionStateUpdate
} from './PermissionStateReducer'

const TAG = 'PermissionViewModel'
const PERMISSION_RENDER_READY_DELAY_MS = 32

@ObservedV2
export class PermissionViewModel {
  @Trace state: PermissionPageState = new PermissionPageState()
  private permissionProfileRequestSeq: number = 0
  private dataRefreshPromise: Promise<boolean> | null = null
  private dataRefreshIncludesAccounts: boolean = false
  private accountChangeRefreshPromise: Promise<boolean> | null = null
  private accountChangeRefreshPending: boolean = false

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

  async refreshForAccountChange(): Promise<boolean> {
    if (!this.state.initialized) {
      await this.loadInitialState()
      return this.state.initialized
    }
    this.accountChangeRefreshPending = true
    if (this.accountChangeRefreshPromise !== null) {
      return await this.accountChangeRefreshPromise
    }
    let refreshPromise = this.runAccountChangeRefreshLoop()
    this.accountChangeRefreshPromise = refreshPromise
    try {
      return await refreshPromise
    } finally {
      if (this.accountChangeRefreshPromise === refreshPromise) {
        this.accountChangeRefreshPromise = null
      }
    }
  }

  async refreshApplications(): Promise<boolean> {
    return await this.runCurrentAccountRefresh(async (): Promise<boolean> =>
      await this.executeApplicationRefresh(true)
    )
  }

  async refreshApplicationList(): Promise<boolean> {
    return await this.runCurrentAccountRefresh(async (): Promise<boolean> =>
      await this.executeApplicationRefresh(false)
    )
  }

  private async runCurrentAccountRefresh(task: () => Promise<boolean>): Promise<boolean> {
    if (this.dataRefreshPromise !== null) {
      return await this.dataRefreshPromise
    }
    return await this.startDataRefresh(false, task)
  }

  private async startDataRefresh(
    includesAccounts: boolean,
    task: () => Promise<boolean>
  ): Promise<boolean> {
    this.dataRefreshIncludesAccounts = includesAccounts
    let refreshPromise = task()
    this.dataRefreshPromise = refreshPromise
    try {
      return await refreshPromise
    } finally {
      if (this.dataRefreshPromise === refreshPromise) {
        this.dataRefreshPromise = null
        this.dataRefreshIncludesAccounts = false
      }
    }
  }

  private async runAccountChangeRefreshLoop(): Promise<boolean> {
    while (this.accountChangeRefreshPending) {
      await this.waitForActiveDataRefresh()
      this.accountChangeRefreshPending = false
      let success = await this.startDataRefresh(true, async (): Promise<boolean> =>
        await this.executeAccountsAndApplicationRefresh()
      )
      if (!success) {
        return false
      }
    }
    return true
  }

  private async waitForActiveDataRefresh(): Promise<void> {
    while (this.dataRefreshPromise !== null) {
      await this.dataRefreshPromise
    }
  }

  private async executeApplicationRefresh(replaceEmptyInventory: boolean): Promise<boolean> {
    this.state.loading = true
    this.state.errorMessage = ''
    try {
      let previousSelectedSnapshot = this.getSelectedAppSnapshot()
      let inventory = await PermissionService.loadApplications(this.state.selectedAccountId)
      if (replaceEmptyInventory) {
        this.applyInventory(inventory)
      } else {
        this.applyApplicationList(inventory)
      }
      this.reconcileSelectedApplicationAfterRefresh(previousSelectedSnapshot)
      return true
    } catch (err) {
      LogUtils.warn(TAG, `executeApplicationRefresh failed: ${JSON.stringify(err)}`)
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
    while (this.dataRefreshPromise !== null) {
      if (this.dataRefreshIncludesAccounts) {
        return await this.dataRefreshPromise
      }
      await this.dataRefreshPromise
    }
    return await this.startDataRefresh(true, async (): Promise<boolean> =>
      await this.executeAccountsAndApplicationRefresh()
    )
  }

  private async executeAccountsAndApplicationRefresh(): Promise<boolean> {
    this.state.loading = true
    this.state.errorMessage = ''
    try {
      let previousSelectedSnapshot = this.getSelectedAppSnapshot()
      let accountResult = await PermissionService.loadAccounts()
      let selectedAccountId = PermissionAccountRefreshUseCase.resolveRefreshedAccountId(this.state, accountResult)
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
      if (!accountChanged) {
        this.reconcileSelectedApplicationAfterRefresh(previousSelectedSnapshot)
      }
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
            threeDPolicies: PermissionPolicyRecordMapper.buildThreeDPolicySnapshotsFromGroups(s, permissionProfile.threeDGroups),
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
    let actionKey = PermissionPolicyRecordMapper.getThreeDRecordKey(snapshot.appKey, groupKey)
    this.setProcessingAction(actionKey)
    try {
      await this.waitForCommittedState()
      let prepared = await this.prepareSelectedAppContextForAction()
      if (!prepared.success || prepared.snapshot === undefined) {
        return {
          success: false,
          message: prepared.message
        } as PermissionActionResult
      }
      snapshot = prepared.snapshot
      let item = snapshot.threeDGroups.find((group: ThreeDPermissionItem): boolean => group.groupKey === groupKey)
      let result = await PermissionService.setThreeDState(
        snapshot,
        PermissionStateReducer.buildSelectedPermissionProfile(snapshot),
        groupKey,
        state
      )
      if (result.success && item !== undefined) {
        if (state === 'default') {
          await PermissionPolicyLocalRepository.remove(actionKey)
        } else {
          await PermissionPolicyLocalRepository.upsertActive(PermissionPolicyRecordMapper.buildLocalPolicyRecord({
            recordId: actionKey,
            app: snapshot,
            policyType: item.title,
            policyValue: state,
            statusLabel: PermissionPolicyRecordMapper.formatThreeDState(state),
            actionKind: 'three-d',
            policyId: groupKey,
            targetName: snapshot.label,
            targetDetail: `${snapshot.bundleName} / ${item.title}`
          }))
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
      let accountPrepared = await this.prepareAccountContextForAction()
      if (!accountPrepared.success) {
        return accountPrepared
      }
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
      let prepared = await this.preparePolicyRecordForDelete(record)
      if (!prepared.success || prepared.record === undefined) {
        return {
          success: false,
          message: prepared.message
        } as PermissionActionResult
      }
      record = prepared.record
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
    this.bumpPermissionProfileRequestSeqIfNeeded(
      PermissionAccountRefreshUseCase.applyInitialData(this.state, initialData)
    )
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

  private applyInventory(inventory: ApplicationInventoryResult): void {
    this.bumpPermissionProfileRequestSeqIfNeeded(
      PermissionAccountRefreshUseCase.applyInventory(this.state, inventory)
    )
  }

  private applyApplicationList(inventory: ApplicationInventoryResult): void {
    this.bumpPermissionProfileRequestSeqIfNeeded(
      PermissionAccountRefreshUseCase.applyApplicationList(this.state, inventory)
    )
  }

  private reconcileSelectedApplicationAfterRefresh(previousSelectedSnapshot: PermissionAppSnapshot | undefined): void {
    this.bumpPermissionProfileRequestSeqIfNeeded(
      PermissionAccountRefreshUseCase.reconcileSelectedApplicationAfterRefresh(this.state, previousSelectedSnapshot)
    )
  }

  private commitPermissionState(update: PermissionStateUpdate): void {
    this.bumpPermissionProfileRequestSeqIfNeeded(PermissionStateReducer.commit(this.state, update))
  }

  private rebuildDerivedState(): void {
    this.bumpPermissionProfileRequestSeqIfNeeded(PermissionStateReducer.rebuildDerivedState(this.state))
  }

  private findAppSnapshot(appKey: string): PermissionAppSnapshot | undefined {
    return PermissionStateReducer.findAppSnapshot(this.state, appKey)
  }

  private getSelectedAppSnapshot(): PermissionAppSnapshot | undefined {
    return PermissionStateReducer.getSelectedAppSnapshot(this.state)
  }

  private clearSelectedApplication(): void {
    PermissionStateReducer.clearSelectedApplicationState(this.state)
    this.permissionProfileRequestSeq++
  }

  private bumpPermissionProfileRequestSeqIfNeeded(selectedCleared: boolean): void {
    if (selectedCleared) {
      this.permissionProfileRequestSeq++
    }
  }

  private async waitForCommittedState(): Promise<void> {
    await new Promise<void>((resolve: () => void): void => {
      setTimeout((): void => {
        resolve()
      }, PERMISSION_RENDER_READY_DELAY_MS)
    })
  }

  private async prepareAccountContextForAction(): Promise<PermissionActionResult> {
    return await PermissionPolicyActionUseCase.prepareAccountContextForAction(
      this.state,
      (): void => this.clearSelectedApplication(),
      (inventory: ApplicationInventoryResult): void => this.applyApplicationList(inventory),
      (update: PermissionStateUpdate): void => this.commitPermissionState(update)
    )
  }

  private async prepareSelectedAppContextForAction(): Promise<PreparedSelectedAppContext> {
    return await PermissionPolicyActionUseCase.prepareSelectedAppContextForAction(
      this.state,
      (): void => this.clearSelectedApplication(),
      (inventory: ApplicationInventoryResult): void => this.applyApplicationList(inventory),
      (update: PermissionStateUpdate): void => this.commitPermissionState(update)
    )
  }

  private async preparePolicyRecordForDelete(record: PermissionPolicyRecord): Promise<PreparedPolicyRecordContext> {
    return await PermissionPolicyActionUseCase.preparePolicyRecordForDelete(
      this.state,
      record,
      (): void => this.clearSelectedApplication(),
      (inventory: ApplicationInventoryResult): void => this.applyApplicationList(inventory),
      (update: PermissionStateUpdate): void => this.commitPermissionState(update)
    )
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
      let prepared = await this.prepareSelectedAppContextForAction()
      if (!prepared.success || prepared.snapshot === undefined) {
        return {
          success: false,
          message: prepared.message
        } as PermissionActionResult
      }
      snapshot = prepared.snapshot
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
    this.bumpPermissionProfileRequestSeqIfNeeded(
      PermissionStateReducer.patchAppSnapshot(this.state, appKey, patch)
    )
  }

  private patchInstallPolicies(removePolicyId: string): void {
    this.bumpPermissionProfileRequestSeqIfNeeded(
      PermissionStateReducer.patchInstallPolicies(this.state, removePolicyId)
    )
  }

  private patchThreeDState(appKey: string, groupKey: string, state: ThreeDManagedState): void {
    this.bumpPermissionProfileRequestSeqIfNeeded(
      PermissionStateReducer.patchThreeDState(this.state, appKey, groupKey, state)
    )
  }
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
