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

  async refreshApplicationList(): Promise<void> {
    if (this.state.loading) {
      return
    }
    this.state.loading = true
    this.state.errorMessage = ''
    try {
      let inventory = await PermissionService.loadApplications(this.state.selectedAccountId)
      this.applyApplicationList(inventory)
    } catch (err) {
      LogUtils.warn(TAG, `refreshApplicationList failed: ${JSON.stringify(err)}`)
      this.state.errorMessage = MessageText.RETRY_LATER
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
    let exists = this.state.filteredApplications.some((app: ManagedApplicationInfo): boolean => app.key === appKey)
    this.state.selectedAppKey = exists ? appKey : ''
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
    try {
      await this.loadSelectedApplicationDetailsForKey(selectedAppKey, requestSeq)
    } catch (err) {
      LogUtils.warn(TAG, `load selected application details failed: ${JSON.stringify(err)}`)
    }
  }

  async switchAccount(accountId: number): Promise<void> {
    if (this.state.selectedAccountId === accountId && this.state.initialized) {
      return
    }
    this.state.selectedAccountId = accountId
    this.state.selectedAppKey = ''
    this.state.selectedPermissionProfile = null
    this.state.policyRecords = []
    this.state.selectedAppRefreshing = false
    this.state.policyLoading = false
    this.permissionProfileRequestSeq++
    await this.refreshApplications()
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
      }
      return
    }
    try {
      if (this.state.selectedAppKey === appKey && this.permissionProfileRequestSeq === requestSeq) {
        await this.loadSelectedPermissionProfileForKey(appKey, requestSeq)
      }
      if (this.state.selectedAppKey === appKey && this.permissionProfileRequestSeq === requestSeq) {
        await this.refreshAccountPolicyState()
      }
    } finally {
      if (this.state.selectedAppKey === appKey && this.permissionProfileRequestSeq === requestSeq) {
        this.state.selectedAppRefreshing = false
      }
    }
  }

  async setSelectedUninstallProtected(enabled: boolean): Promise<PermissionActionResult> {
    return this.runSelectedAppAction(
      `uninstall:${this.state.selectedAppKey}`,
      async (app: ManagedApplicationInfo): Promise<PermissionActionResult> =>
        await PermissionService.setUninstallProtected(app, enabled),
      (app: ManagedApplicationInfo): void => {
        app.uninstallProtected = enabled
      },
      async (app: ManagedApplicationInfo): Promise<void> => {
        if (enabled) {
          await this.upsertLocalAppPolicy(app, PermissionApplicationStrings.POLICY_TYPE_UNINSTALL,
            PermissionApplicationStrings.ENABLED, 'uninstall-protect')
        } else {
          await PermissionPolicyLocalRepository.removeByAppPolicy(app.key, 'uninstall-protect')
        }
      },
      'uninstall-protect'
    )
  }

  async setSelectedRunningPolicy(policy: PermissionPolicyState): Promise<PermissionActionResult> {
    return this.runSelectedAppAction(
      `running:${this.state.selectedAppKey}`,
      async (app: ManagedApplicationInfo): Promise<PermissionActionResult> =>
        await PermissionService.setRunningPolicy(app, policy),
      (app: ManagedApplicationInfo): void => {
        app.runningPolicy = policy
      },
      async (app: ManagedApplicationInfo): Promise<void> => {
        if (policy === 'default') {
          await PermissionPolicyLocalRepository.removeByAppPolicy(app.key, 'running')
        } else {
          await this.upsertLocalAppPolicy(app, PermissionApplicationStrings.POLICY_TYPE_RUNNING,
            PermissionService.formatPolicyForDisplay(policy), 'running')
        }
      },
      'running'
    )
  }

  async setSelectedNetworkPolicy(policy: PermissionPolicyState): Promise<PermissionActionResult> {
    return this.runSelectedAppAction(
      `network:${this.state.selectedAppKey}`,
      async (app: ManagedApplicationInfo): Promise<PermissionActionResult> =>
        await PermissionService.setNetworkPolicy(app, policy),
      (app: ManagedApplicationInfo): void => {
        app.networkPolicy = policy
      },
      async (app: ManagedApplicationInfo): Promise<void> => {
        if (policy === 'default') {
          await PermissionPolicyLocalRepository.removeByAppPolicy(app.key, 'network')
        } else {
          await this.upsertLocalAppPolicy(app, PermissionApplicationStrings.POLICY_TYPE_NETWORK,
            PermissionService.formatPolicyForDisplay(policy), 'network')
        }
      },
      'network'
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
        } else {
          await this.upsertLocalPolicyRecord({
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
        }
      }
      await this.loadSelectedPermissionProfileForKey(selectedApp.key, this.permissionProfileRequestSeq)
      await this.refreshAccountPolicyState()
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
      let packageName = PermissionService.normalizeInstallBlockPackageName(this.state.installBlockKeyword)
      let result = await PermissionService.setDisallowedInstallPolicyId(this.state.selectedAccountId, packageName)
      if (result.success) {
        this.updateInstalledApplicationInstallPolicy(packageName)
        await this.upsertInstallDenyRecord(packageName)
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
      let result = await PermissionService.deletePolicyRecord(
        this.state.selectedAccountId,
        record,
        this.state.applications
      )
      if (result.success) {
        await PermissionPolicyLocalRepository.remove(recordKey)
        await this.refreshAccountPolicyState()
        this.syncDeletedPolicyRecord(record)
      }
      return result
    } finally {
      this.clearProcessingAction()
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
      if (this.state.selectedAppKey.length > 0 || this.state.selectedPermissionProfile !== null) {
        this.state.selectedAppKey = ''
        this.state.selectedPermissionProfile = null
        this.state.selectedAppRefreshing = false
        this.state.policyLoading = false
        this.permissionProfileRequestSeq++
      }
      return
    }
    let selectedExists = this.state.filteredApplications.some((app: ManagedApplicationInfo): boolean =>
      app.key === this.state.selectedAppKey
    )
    if (!selectedExists && this.state.selectedAppKey.length > 0) {
      this.state.selectedAppKey = ''
      this.state.selectedPermissionProfile = null
      this.state.selectedAppRefreshing = false
      this.state.policyLoading = false
      this.permissionProfileRequestSeq++
    }
  }

  private getSelectedApplication(): ManagedApplicationInfo | undefined {
    return this.getApplicationByKey(this.state.selectedAppKey)
  }

  private getApplicationByKey(appKey: string): ManagedApplicationInfo | undefined {
    return this.state.applications.find((app: ManagedApplicationInfo): boolean => app.key === appKey)
  }

  private async refreshAccountPolicyState(): Promise<void> {
    this.state.policyLoading = true
    try {
      let snapshot = await PermissionService.loadAccountPolicySnapshot(this.state.selectedAccountId, this.state.applications)
      this.applyAccountPolicySnapshot(snapshot)
    } finally {
      this.state.policyLoading = false
    }
  }

  private async runSelectedAppAction(
    actionKey: string,
    action: (app: ManagedApplicationInfo) => Promise<PermissionActionResult>,
    applySuccess: (app: ManagedApplicationInfo) => void,
    persistSuccess?: (app: ManagedApplicationInfo) => Promise<void>,
    policyActionKind: string = ''
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
      let result = await action(selectedApp)
      if (result.success) {
        if (persistSuccess !== undefined) {
          await persistSuccess(selectedApp)
        }
        this.updateApplicationByKey(selectedApp.key, applySuccess)
        await this.refreshAccountPolicyState()
        this.syncSuccessfulAppPolicy(selectedApp.key, policyActionKind, applySuccess)
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

  private syncSuccessfulAppPolicy(
    appKey: string,
    actionKind: string,
    applySuccess: (app: ManagedApplicationInfo) => void
  ): void {
    let syncedApp: ManagedApplicationInfo | undefined = undefined
    this.state.applications = this.state.applications.map((app: ManagedApplicationInfo): ManagedApplicationInfo => {
      if (app.key === appKey) {
        applySuccess(app)
        syncedApp = app
      }
      return app
    })
    if (syncedApp !== undefined && actionKind.length > 0) {
      this.syncAppPolicyRecord(syncedApp, actionKind)
    }
    this.refreshSummaryAndFilters()
  }

  private syncDeletedPolicyRecord(record: PermissionPolicyRecord): void {
    this.state.policyRecords = this.state.policyRecords.filter((item: PermissionPolicyRecord): boolean =>
      item.key !== record.key
    )
    if (record.actionKind === 'install-deny' || record.actionKind === 'install-allow') {
      this.syncInstallPolicyRecordDeletion(record)
      this.refreshSummaryAndFilters()
      return
    }
    if (record.appKey.length === 0) {
      this.refreshSummaryAndFilters()
      return
    }
    this.state.applications = this.state.applications.map((app: ManagedApplicationInfo): ManagedApplicationInfo => {
      if (app.key !== record.appKey) {
        return app
      }
      if (record.actionKind === 'uninstall-protect') {
        app.uninstallProtected = false
      } else if (record.actionKind === 'running') {
        app.runningPolicy = 'default'
      } else if (record.actionKind === 'network') {
        app.networkPolicy = 'default'
      }
      return app
    })
    this.refreshSummaryAndFilters()
  }

  private syncInstallPolicyRecordDeletion(record: PermissionPolicyRecord): void {
    this.state.applications = this.state.applications.map((app: ManagedApplicationInfo): ManagedApplicationInfo => {
      if (app.bundleName === record.policyId || app.appIdentifier === record.policyId) {
        app.installPolicy = 'default'
      }
      return app
    })
  }

  private syncAppPolicyRecord(app: ManagedApplicationInfo, actionKind: string): void {
    let recordKey = `${actionKind}:${app.key}`
    this.state.policyRecords = this.state.policyRecords.filter((record: PermissionPolicyRecord): boolean =>
      record.key !== recordKey
    )
    let record = this.createCurrentAppPolicyRecord(app, actionKind)
    if (record !== undefined) {
      this.state.policyRecords.push(record)
    }
  }

  private createCurrentAppPolicyRecord(
    app: ManagedApplicationInfo,
    actionKind: string
  ): PermissionPolicyRecord | undefined {
    if (actionKind === 'uninstall-protect' && app.uninstallProtected) {
      return this.createAppPolicyRecord(app, PermissionApplicationStrings.POLICY_TYPE_UNINSTALL,
        PermissionApplicationStrings.ENABLED, actionKind)
    }
    if (actionKind === 'running' && app.runningPolicy !== 'default') {
      return this.createAppPolicyRecord(app, PermissionApplicationStrings.POLICY_TYPE_RUNNING,
        PermissionService.formatPolicyForDisplay(app.runningPolicy), actionKind)
    }
    if (actionKind === 'network' && app.networkPolicy !== 'default') {
      return this.createAppPolicyRecord(app, PermissionApplicationStrings.POLICY_TYPE_NETWORK,
        PermissionService.formatPolicyForDisplay(app.networkPolicy), actionKind)
    }
    return undefined
  }

  private createAppPolicyRecord(
    app: ManagedApplicationInfo,
    policyType: string,
    statusLabel: string,
    actionKind: string
  ): PermissionPolicyRecord {
    return {
      key: `${actionKind}:${app.key}`,
      policyType: policyType,
      targetName: app.label,
      targetDetail: app.bundleName,
      statusLabel: statusLabel,
      scopeLabel: `${PermissionApplicationStrings.POLICY_SCOPE_ACCOUNT_PREFIX} ${app.accountId}`,
      actionKind: actionKind,
      appKey: app.key,
      policyId: ''
    } as PermissionPolicyRecord
  }

  private refreshSummaryAndFilters(): void {
    let summary = PermissionService.buildSummary(this.state.applications)
    summary.managedCount = this.state.policyRecords.length
    this.state.summary = summary
    this.updateFilteredApplications()
  }

  private async upsertInstallDenyRecord(packageName: string): Promise<void> {
    let now = Date.now()
    let installedApp = this.state.applications.find((app: ManagedApplicationInfo): boolean =>
      app.bundleName === packageName
    )
    let record: PermissionLocalPolicyRecord = {
      recordId: `install-deny:${this.state.selectedAccountId}:${packageName}`,
      accountId: this.state.selectedAccountId,
      appKey: installedApp?.key ?? '',
      bundleName: packageName,
      appIdentifier: installedApp?.appIdentifier ?? packageName,
      appIndex: installedApp?.appIndex ?? 0,
      policyType: PermissionApplicationStrings.POLICY_TYPE_INSTALL_DENY,
      policyValue: 'denied',
      targetName: installedApp?.label ?? PermissionApplicationStrings.POLICY_TARGET_NOT_INSTALLED,
      targetDetail: packageName,
      statusLabel: PermissionApplicationStrings.POLICY_DENIED,
      scopeLabel: `${PermissionApplicationStrings.POLICY_SCOPE_ACCOUNT_PREFIX} ${this.state.selectedAccountId}`,
      actionKind: 'install-deny',
      policyId: packageName,
      status: 'active',
      createdAt: now,
      updatedAt: now,
      lastError: ''
    } as PermissionLocalPolicyRecord
    await PermissionPolicyLocalRepository.upsertActive(record)
  }

  private async upsertLocalAppPolicy(
    app: ManagedApplicationInfo,
    policyType: string,
    statusLabel: string,
    actionKind: string
  ): Promise<void> {
    await this.upsertLocalPolicyRecord({
      recordId: `${actionKind}:${app.key}`,
      app: app,
      policyType: policyType,
      policyValue: statusLabel,
      statusLabel: statusLabel,
      actionKind: actionKind,
      policyId: '',
      targetName: app.label,
      targetDetail: app.bundleName
    })
  }

  private async upsertLocalPolicyRecord(params: LocalPolicyRecordParams): Promise<void> {
    let now = Date.now()
    await PermissionPolicyLocalRepository.upsertActive({
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
    } as PermissionLocalPolicyRecord)
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
