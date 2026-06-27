import { describe, expect, it } from '@ohos/hypium'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import {
  AccountInstallPolicySnapshot,
  ApplicationInventoryResult,
  ApplicationPermissionProfile,
  PermissionAppSnapshot,
  PermissionActionResult,
  PermissionAccountListResult,
  PermissionInitialData,
  PermissionLocalPolicyRecord,
  PermissionManagedAccount,
  PermissionPolicyRecord,
  PermissionThreeDPolicySnapshot,
  ThreeDPermissionItem
} from '../../main/ets/models/PermissionModels'
import {
  ApplicationInventoryRawRecord,
  ApplicationInventoryRepository
} from '../../main/ets/services/permission-manage/ApplicationInventoryRepository'
import { ApplicationControlRepository } from '../../main/ets/services/permission-manage/ApplicationControlRepository'
import { PermissionService } from '../../main/ets/services/permission-manage/PermissionService'
import { PermissionViewModel } from '../../main/ets/viewmodels/permission-manage/PermissionViewModel'
import { ApplicationNetworkPolicyRepository } from '../../main/ets/services/permission-manage/ApplicationNetworkPolicyRepository'
import { PermissionPolicyLocalRepository } from '../../main/ets/services/permission-manage/PermissionPolicyLocalRepository'
import {
  PermissionAccountPolicySnapshotTaskData,
  PermissionAccountPolicyTaskRunner
} from '../../main/ets/services/permission-manage/PermissionAccountPolicyTasks'

function buildPermissionAccount(accountId: number, isForeground: boolean = false): PermissionManagedAccount {
  return {
    accountId: accountId,
    displayName: `用户 ${accountId}`,
    isForeground: isForeground,
    isAvailable: true
  } as PermissionManagedAccount
}

function buildManagedApplication(accountId: number, bundleName: string, label: string): PermissionAppSnapshot {
  return ApplicationInventoryRepository.normalizeApplications(accountId, [
    {
      bundleName: bundleName,
      label: label,
      appId: `${bundleName}_app_id`,
      appIdentifier: `${bundleName}_app_identifier`,
      systemApp: false
    } as ApplicationInventoryRawRecord
  ], 'com.huawei.securitytool')[0]
}

function buildAppSnapshot(
  app: PermissionAppSnapshot,
  runningBlocked: boolean = false,
  networkBlocked: boolean = false,
  uninstallProtected: boolean = false
): PermissionAppSnapshot {
  return {
    appKey: app.appKey,
    accountId: app.accountId,
    bundleName: app.bundleName,
    appId: app.appId,
    appIdentifier: app.appIdentifier,
    label: app.label,
    uid: app.uid,
    appIndex: app.appIndex,
    uninstallProtected: uninstallProtected,
    runningBlocked: runningBlocked,
    networkBlocked: networkBlocked,
    threeDGroups: [],
    threeDPolicies: [],
    threeDLoadState: 'idle',
    threeDMessage: ''
  } as PermissionAppSnapshot
}

function buildEmptyPermissionProfile(app: PermissionAppSnapshot): ApplicationPermissionProfile {
  return {
    appKey: app.appKey,
    bundleName: app.bundleName,
    requestedPermissions: [],
    mainAbilityName: '',
    sensitivePermissionCount: 0,
    message: '',
    threeDGroups: []
  } as ApplicationPermissionProfile
}

export default function permissionViewModelTest() {
  describe('PermissionViewModel', () => {
    it('should keep default read-only skeleton state before initialization', 0, () => {
      let viewModel = new PermissionViewModel()

      expect(viewModel.state.initialized).assertFalse()
      expect(viewModel.state.loading).assertFalse()
      expect(viewModel.state.summary.appCount).assertEqual(0)
      expect(viewModel.state.appSnapshots.length).assertEqual(0)
      expect(viewModel.state.selectedAppKey).assertEqual('')
    })

    it('should load initial skeleton state without system side effects', 0, async (done: Function) => {
      let viewModel = new PermissionViewModel()
      await viewModel.loadInitialState()

      expect(viewModel.state.initialized).assertTrue()
      expect(viewModel.state.loading).assertFalse()
      expect(viewModel.state.accounts.length >= 0).assertTrue()
      expect(viewModel.state.summary.appCount).assertEqual(0)
      expect(viewModel.state.summary.managedCount).assertEqual(0)
      done()
    })

    it('should not overwrite policy state when initial state is requested after initialization', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let app = buildManagedApplication(100, 'com.example.label', 'Label')
        let loadInitialStateMock = mockKit.mockFunc(PermissionService, PermissionService.loadInitialState)
        when(loadInitialStateMock)().afterReturn(Promise.resolve({
          selectedAccountId: 100,
          selectedAppKey: '',
          inventoryMessage: '',
          accounts: [buildPermissionAccount(100, true)],
          appSnapshots: [buildAppSnapshot(app)],
          installPolicies: []
        } as PermissionInitialData))
        viewModel.state.initialized = true
        viewModel.state.selectedAccountId = 100
        viewModel.state.selectedAppKey = app.appKey
        viewModel.state.accounts = [buildPermissionAccount(100, true)]
        viewModel.state.appSnapshots = [buildAppSnapshot(app, true, true, true)]
        viewModel.state.policyRecords = PermissionService.buildPolicyRecordsFromState(viewModel.state.appSnapshots, [])

        await viewModel.loadInitialState()

        let selectedApp = viewModel.state.appSnapshots.find((item: PermissionAppSnapshot): boolean => item.appKey === app.appKey)
        expect(viewModel.state.selectedAppKey).assertEqual(app.appKey)
        expect(selectedApp?.uninstallProtected).assertTrue()
        expect(selectedApp?.runningBlocked).assertTrue()
        expect(selectedApp?.networkBlocked).assertTrue()
        expect(viewModel.state.policyRecords.length).assertEqual(3)
      } finally {
        mockKit.clearAll()
        done()
      }
    })

    it('should refresh account options before refreshing application list', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        viewModel.state.initialized = true
        viewModel.state.selectedAccountId = 100
        viewModel.state.accounts = [buildPermissionAccount(100, true)]
        let loadedAccountId = -1
        let loadAccountsMock = mockKit.mockFunc(PermissionService, PermissionService.loadAccounts)
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        when(loadAccountsMock)().afterReturn(Promise.resolve({
          accounts: [buildPermissionAccount(100), buildPermissionAccount(101, true)],
          selectedAccountId: 101
        } as PermissionAccountListResult))
        when(loadApplicationsMock)(ArgumentMatchers.any).afterAction((accountId: number): Promise<ApplicationInventoryResult> => {
          loadedAccountId = accountId
          return Promise.resolve({
            appSnapshots: [buildManagedApplication(accountId, 'com.example.mail', 'Mail')],
            installPolicies: []
          } as ApplicationInventoryResult)
        })

        let success = await viewModel.refreshAccountsAndApplicationList()

        expect(success).assertTrue()
        expect(viewModel.state.accounts.length).assertEqual(2)
        expect(viewModel.state.selectedAccountId).assertEqual(100)
        expect(loadedAccountId).assertEqual(100)
        expect(viewModel.state.appSnapshots[0].accountId).assertEqual(100)
      } finally {
        mockKit.clearAll()
        done()
      }
    })

    it('should fallback to refreshed selected account when current account is gone', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        viewModel.state.initialized = true
        viewModel.state.selectedAccountId = 100
        viewModel.state.accounts = [buildPermissionAccount(100, true)]
        let applications = [buildManagedApplication(100, 'com.example.mail', 'Mail')]
        viewModel.state.appSnapshots = applications
        viewModel.state.selectedAppKey = applications[0].appKey
        viewModel.state.policyRecords = [{
          key: 'running:100:com.example.mail',
          policyType: '运行控制',
          targetName: 'Mail',
          targetDetail: 'com.example.mail',
          statusLabel: '禁止',
          scopeLabel: '用户 100',
          actionKind: 'running',
          appKey: viewModel.state.selectedAppKey,
          policyId: 'com.example.mail'
        } as PermissionPolicyRecord]
        let loadedAccountId = -1
        let loadAccountsMock = mockKit.mockFunc(PermissionService, PermissionService.loadAccounts)
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        when(loadAccountsMock)().afterReturn(Promise.resolve({
          accounts: [buildPermissionAccount(101, true)],
          selectedAccountId: 101
        } as PermissionAccountListResult))
        when(loadApplicationsMock)(ArgumentMatchers.any).afterAction((accountId: number): Promise<ApplicationInventoryResult> => {
          loadedAccountId = accountId
          return Promise.resolve({
            appSnapshots: [buildManagedApplication(accountId, 'com.example.browser', 'Browser')],
            installPolicies: []
          } as ApplicationInventoryResult)
        })

        let success = await viewModel.refreshAccountsAndApplicationList()

        expect(success).assertTrue()
        expect(viewModel.state.selectedAccountId).assertEqual(101)
        expect(loadedAccountId).assertEqual(101)
        expect(viewModel.state.selectedAppKey).assertEqual('')
        expect(viewModel.state.policyRecords.length).assertEqual(0)
        expect(viewModel.state.appSnapshots[0].accountId).assertEqual(101)
      } finally {
        mockKit.clearAll()
        done()
      }
    })

    it('should summarize managed application states', 0, () => {
      let applications: PermissionAppSnapshot[] = [
        {
          appKey: '100:demo:demo:0',
          accountId: 100,
          bundleName: 'demo',
          appId: 'demo-app-id',
          appIdentifier: 'demo-app-identifier',
          appIndex: 0,
          uid: 10001,
          label: 'Demo',
          uninstallProtected: false,
          runningBlocked: false,
          networkBlocked: true,
          threeDGroups: [],
          threeDPolicies: [],
          threeDLoadState: 'idle',
          threeDMessage: ''
        } as PermissionAppSnapshot
      ]

      let snapshots = applications
      let records = PermissionService.buildPolicyRecordsFromState(snapshots, [])
      let summary = PermissionService.buildSummaryFromState(snapshots, records)

      expect(summary.appCount).assertEqual(1)
      expect(summary.managedCount).assertEqual(1)
      expect(summary.networkRestrictedCount).assertEqual(1)
    })

    it('should normalize manageable applications and skip system or self bundle only', 0, () => {
      let rawRecords: ApplicationInventoryRawRecord[] = [
        {
          bundleName: 'com.example.demo',
          label: 'Demo',
          appId: 'demo-app-id',
          appIdentifier: 'demo-app-identifier',
          appIndex: 1,
          uid: 10001,
          versionName: '1.0.0',
          systemApp: false
        } as ApplicationInventoryRawRecord,
        {
          bundleName: 'com.example.system',
          label: 'System',
          systemApp: true
        } as ApplicationInventoryRawRecord,
        {
          bundleName: 'com.ohos.formrenderservice',
          label: 'FormRenderService',
          systemApp: false
        } as ApplicationInventoryRawRecord,
        {
          bundleName: 'com.example.nonremovable',
          label: 'NonRemovable',
          systemApp: false,
          removable: false
        } as ApplicationInventoryRawRecord,
        {
          bundleName: 'com.huawei.securitytool',
          label: 'Self',
          systemApp: false
        } as ApplicationInventoryRawRecord
      ]

      let applications = ApplicationInventoryRepository.normalizeApplications(100, rawRecords, 'com.huawei.securitytool')

      let demo = applications.find((app: PermissionAppSnapshot): boolean => app.bundleName === 'com.example.demo')
      let nonRemovable = applications.find((app: PermissionAppSnapshot): boolean =>
        app.bundleName === 'com.example.nonremovable'
      )
      expect(applications.length).assertEqual(2)
      expect(demo?.appKey).assertEqual('100:com.example.demo')
      expect(demo?.label).assertEqual('Demo')
      expect(demo?.appIdentifier).assertEqual('demo-app-identifier')
      expect(nonRemovable?.appKey).assertEqual('100:com.example.nonremovable')
      expect(applications.some((app: PermissionAppSnapshot): boolean => app.bundleName === 'com.example.system')).assertFalse()
      expect(applications.some((app: PermissionAppSnapshot): boolean => app.bundleName === 'com.ohos.formrenderservice')).assertFalse()
      expect(applications.some((app: PermissionAppSnapshot): boolean => app.bundleName === 'com.example.nonremovable')).assertTrue()
    })

    it('should keep duplicate labels mapped by bundle identity', 0, () => {
      let applications = ApplicationInventoryRepository.normalizeApplications(100, [
        {
          bundleName: 'com.example.first',
          label: 'Label',
          systemApp: false
        } as ApplicationInventoryRawRecord,
        {
          bundleName: 'com.example.second',
          label: 'Label',
          systemApp: false
        } as ApplicationInventoryRawRecord
      ], 'com.huawei.securitytool')

      let first = applications.find((app: PermissionAppSnapshot): boolean => app.bundleName === 'com.example.first')
      let second = applications.find((app: PermissionAppSnapshot): boolean => app.bundleName === 'com.example.second')

      expect(applications.length).assertEqual(2)
      expect(first?.appKey).assertEqual('100:com.example.first')
      expect(second?.appKey).assertEqual('100:com.example.second')
      expect(first?.label).assertEqual(second?.label)
    })

    it('should filter applications by label or bundle name', 0, () => {
      let applications = ApplicationInventoryRepository.normalizeApplications(100, [
        { bundleName: 'com.example.mail', label: 'Mail' } as ApplicationInventoryRawRecord,
        { bundleName: 'com.example.browser', label: 'Browser' } as ApplicationInventoryRawRecord
      ], 'com.huawei.securitytool')

      expect(ApplicationInventoryRepository.filterApplications(applications, 'mail').length).assertEqual(1)
      expect(ApplicationInventoryRepository.filterApplications(applications, 'browser').length).assertEqual(1)
      expect(ApplicationInventoryRepository.filterApplications(applications, 'missing').length).assertEqual(0)
    })

    it('should merge read-only control states into application list', 0, () => {
      let applications = ApplicationInventoryRepository.normalizeApplications(100, [
        {
          bundleName: 'com.example.mail',
          label: 'Mail',
          appId: 'mail-app-id',
          systemApp: false
        } as ApplicationInventoryRawRecord,
        {
          bundleName: 'com.example.browser',
          label: 'Browser',
          appId: 'browser-app-id',
          systemApp: false
        } as ApplicationInventoryRawRecord
      ], 'com.huawei.securitytool')

      let merged = ApplicationControlRepository.mergeControlStates(100, applications, {
        allowedInstallIds: ['com.example.mail'],
        disallowedInstallIds: ['com.example.browser'],
        disallowedUninstallIds: ['mail-app-id'],
        allowedRunningIds: ['com.example.browser'],
        disallowedRunningIds: ['mail-app-id']
      })

      let mail = merged.find((app: PermissionAppSnapshot): boolean => app.bundleName === 'com.example.mail')
      let browser = merged.find((app: PermissionAppSnapshot): boolean => app.bundleName === 'com.example.browser')

      expect(mail?.uninstallProtected).assertTrue()
      expect(mail?.runningBlocked).assertTrue()
      expect(browser?.runningBlocked).assertFalse()
    })

    it('should use only app id as running policy id', 0, () => {
      let app = ApplicationInventoryRepository.normalizeApplications(100, [
        {
          bundleName: 'com.example.mail',
          label: 'Mail',
          appId: 'mail-app-id',
          systemApp: false
        } as ApplicationInventoryRawRecord
      ], 'com.huawei.securitytool')[0]

      let cleanupIds = ApplicationControlRepository.buildRunningPolicyCleanupIdsForTest(app)

      expect(cleanupIds.length).assertEqual(1)
      expect(cleanupIds.includes('mail-app-id')).assertTrue()
      expect(cleanupIds.includes('com.example.mail')).assertFalse()
    })

    it('should not match uninstall protection by bundle name', 0, () => {
      let applications = ApplicationInventoryRepository.normalizeApplications(100, [
        {
          bundleName: 'com.example.first',
          label: 'First',
          appId: 'first-app-id',
          systemApp: false
        } as ApplicationInventoryRawRecord,
        {
          bundleName: 'com.example.second',
          label: 'Second',
          appId: 'second-app-id',
          systemApp: false
        } as ApplicationInventoryRawRecord
      ], 'com.huawei.securitytool')

      let bundleNameMerged = ApplicationControlRepository.mergeControlStates(100, applications, {
        allowedInstallIds: [],
        disallowedInstallIds: [],
        disallowedUninstallIds: ['com.example.second'],
        allowedRunningIds: [],
        disallowedRunningIds: []
      })
      let appIdMerged = ApplicationControlRepository.mergeControlStates(100, applications, {
        allowedInstallIds: [],
        disallowedInstallIds: [],
        disallowedUninstallIds: ['second-app-id'],
        allowedRunningIds: [],
        disallowedRunningIds: []
      })
      let firstByBundleName = bundleNameMerged.find((app: PermissionAppSnapshot): boolean =>
        app.bundleName === 'com.example.first'
      )
      let secondByBundleName = bundleNameMerged.find((app: PermissionAppSnapshot): boolean =>
        app.bundleName === 'com.example.second'
      )
      let secondByAppId = appIdMerged.find((app: PermissionAppSnapshot): boolean =>
        app.bundleName === 'com.example.second'
      )

      expect(firstByBundleName?.uninstallProtected).assertFalse()
      expect(secondByBundleName?.uninstallProtected).assertFalse()
      expect(secondByAppId?.uninstallProtected).assertTrue()
    })

    it('should scope control policies by account and bundle key', 0, () => {
      let account100App = ApplicationInventoryRepository.normalizeApplications(100, [
        {
          bundleName: 'com.example.mail',
          label: 'Mail',
          appId: 'account-100-mail-app-id',
          systemApp: false
        } as ApplicationInventoryRawRecord
      ], 'com.huawei.securitytool')[0]
      let account101App = ApplicationInventoryRepository.normalizeApplications(101, [
        {
          bundleName: 'com.example.mail',
          label: 'Mail',
          appId: 'account-101-mail-app-id',
          systemApp: false
        } as ApplicationInventoryRawRecord
      ], 'com.huawei.securitytool')[0]

      let merged = ApplicationControlRepository.mergeControlStates(100, [account100App, account101App], {
        allowedInstallIds: [],
        disallowedInstallIds: [],
        disallowedUninstallIds: ['account-100-mail-app-id'],
        allowedRunningIds: [],
        disallowedRunningIds: ['account-100-mail-app-id']
      })
      let account100State = merged.find((app: PermissionAppSnapshot): boolean => app.appKey === account100App.appKey)
      let account101State = merged.find((app: PermissionAppSnapshot): boolean => app.appKey === account101App.appKey)

      expect(account100State?.uninstallProtected).assertTrue()
      expect(account100State?.runningBlocked).assertTrue()
      expect(account101State?.uninstallProtected).assertFalse()
      expect(account101State?.runningBlocked).assertFalse()
    })

    it('should merge network restriction state by application uid', 0, () => {
      let applications = ApplicationInventoryRepository.normalizeApplications(100, [
        {
          bundleName: 'com.example.mail',
          label: 'Mail',
          uid: 10001,
          systemApp: false
        } as ApplicationInventoryRawRecord,
        {
          bundleName: 'com.example.browser',
          label: 'Browser',
          uid: 10002,
          systemApp: false
        } as ApplicationInventoryRawRecord
      ], 'com.huawei.securitytool')

      let merged = ApplicationNetworkPolicyRepository.mergeNetworkStates(100, applications, ['10002'])
      let mail = merged.find((app: PermissionAppSnapshot): boolean => app.bundleName === 'com.example.mail')
      let browser = merged.find((app: PermissionAppSnapshot): boolean => app.bundleName === 'com.example.browser')

      expect(mail?.networkBlocked).assertFalse()
      expect(browser?.networkBlocked).assertTrue()
    })

    it('should scope network restriction state by account and bundle key', 0, () => {
      let account100App = ApplicationInventoryRepository.normalizeApplications(100, [
        {
          bundleName: 'com.example.browser',
          label: 'Browser',
          uid: 10002,
          systemApp: false
        } as ApplicationInventoryRawRecord
      ], 'com.huawei.securitytool')[0]
      let account101App = ApplicationInventoryRepository.normalizeApplications(101, [
        {
          bundleName: 'com.example.browser',
          label: 'Browser',
          uid: 10002,
          systemApp: false
        } as ApplicationInventoryRawRecord
      ], 'com.huawei.securitytool')[0]

      let merged = ApplicationNetworkPolicyRepository.mergeNetworkStates(
        100,
        [account100App, account101App],
        ['10002']
      )
      let account100State = merged.find((app: PermissionAppSnapshot): boolean => app.appKey === account100App.appKey)
      let account101State = merged.find((app: PermissionAppSnapshot): boolean => app.appKey === account101App.appKey)

      expect(account100State?.networkBlocked).assertTrue()
      expect(account101State?.networkBlocked).assertFalse()
    })

    it('should build application policy records for the selected account only', 0, () => {
      let account100App = {
        appKey: '100:com.example.mail',
        accountId: 100,
        bundleName: 'com.example.mail',
        appId: 'account-100-mail-app-id',
        appIdentifier: 'account-100-mail-app-identifier',
        appIndex: 0,
        uid: 10001,
        label: 'Mail',
        uninstallProtected: true,
        runningBlocked: false,
        networkBlocked: false,
        threeDGroups: [],
        threeDPolicies: [],
        threeDLoadState: 'idle',
        threeDMessage: ''
      } as PermissionAppSnapshot
      let account101App = {
        appKey: '101:com.example.mail',
        accountId: 101,
        bundleName: 'com.example.mail',
        appId: 'account-101-mail-app-id',
        appIdentifier: 'account-101-mail-app-identifier',
        appIndex: 0,
        uid: 110001,
        label: 'Mail',
        uninstallProtected: true,
        runningBlocked: false,
        networkBlocked: false,
        threeDGroups: [],
        threeDPolicies: [],
        threeDLoadState: 'idle',
        threeDMessage: ''
      } as PermissionAppSnapshot

      let snapshots = [account100App, account101App]
        .filter((s: PermissionAppSnapshot): boolean => s.accountId === 100)
      let records = PermissionService.buildPolicyRecordsFromState(snapshots, [])

      expect(records.length).assertEqual(1)
      expect(records[0].appKey).assertEqual(account100App.appKey)
    })

    it('should accept full package name as install block target', 0, () => {
      let packageName = PermissionService.normalizeInstallBlockPackageName(' com.example.future ')

      expect(packageName).assertEqual('com.example.future')
    })

    it('should reject non-package install block target', 0, () => {
      let failed = false
      try {
        PermissionService.normalizeInstallBlockPackageName('Mail')
      } catch (err) {
        failed = true
      }

      expect(failed).assertTrue()
    })

    it('should keep local policy records scoped by account and removable by record id', 0, async (done: Function) => {
      PermissionPolicyLocalRepository.resetForTest()
      await PermissionPolicyLocalRepository.upsertActive({
        recordId: 'three-d:100:mail:downloads',
        accountId: 100,
        appKey: '100:mail',
        bundleName: 'mail',
        appIdentifier: 'mail',
        appIndex: 0,
        policyType: 'Downloads',
        policyValue: 'denied',
        targetName: 'Mail',
        targetDetail: 'mail / Downloads',
        statusLabel: 'denied',
        scopeLabel: 'account 100',
        actionKind: 'three-d',
        policyId: 'downloads',
        status: 'active',
        createdAt: 1,
        updatedAt: 1,
        lastError: ''
      } as PermissionLocalPolicyRecord)
      await PermissionPolicyLocalRepository.upsertActive({
        recordId: 'three-d:101:mail:downloads',
        accountId: 101,
        appKey: '101:mail',
        bundleName: 'mail',
        appIdentifier: 'mail',
        appIndex: 0,
        policyType: 'Downloads',
        policyValue: 'denied',
        targetName: 'Mail',
        targetDetail: 'mail / Downloads',
        statusLabel: 'denied',
        scopeLabel: 'account 101',
        actionKind: 'three-d',
        policyId: 'downloads',
        status: 'active',
        createdAt: 1,
        updatedAt: 1,
        lastError: ''
      } as PermissionLocalPolicyRecord)

      expect(PermissionPolicyLocalRepository.listActiveByAccount(100).length).assertEqual(1)
      await PermissionPolicyLocalRepository.remove('three-d:100:mail:downloads')
      expect(PermissionPolicyLocalRepository.listActiveByAccount(100).length).assertEqual(0)
      expect(PermissionPolicyLocalRepository.listActiveByAccount(101).length).assertEqual(1)
      PermissionPolicyLocalRepository.resetForTest()
      done()
    })

    it('should derive 3D current policy records from application snapshots', 0, () => {
      let app = buildManagedApplication(100, 'mail', 'Mail')
      let snapshot = buildAppSnapshot(app)
      snapshot.threeDPolicies = [{
        recordId: 'three-d:100:mail:downloads',
        appKey: app.appKey,
        groupKey: 'downloads',
        actionKind: 'three-d',
        policyValue: 'denied',
        policyType: 'Downloads',
        targetName: 'Mail',
        targetDetail: 'mail / Downloads',
        statusLabel: 'denied',
        scopeLabel: 'account 100'
      } as PermissionThreeDPolicySnapshot]

      let records = PermissionService.buildPolicyRecordsFromState([snapshot], [])

      expect(records.length).assertEqual(1)
      expect(records[0].key).assertEqual('three-d:100:mail:downloads')
      expect(records[0].appKey).assertEqual(app.appKey)
    })

    it('should derive no 3D current policy when snapshot table has no matching app', 0, () => {
      let app = buildManagedApplication(100, 'browser', 'Browser')
      let records = PermissionService.buildPolicyRecordsFromState([buildAppSnapshot(app)], [])

      expect(records.length).assertEqual(0)
    })

    it('should update filtered applications without selecting an app by default', 0, () => {
      let viewModel = new PermissionViewModel()
      let applications = ApplicationInventoryRepository.normalizeApplications(100, [
        { bundleName: 'com.example.mail', label: 'Mail' } as ApplicationInventoryRawRecord,
        { bundleName: 'com.example.browser', label: 'Browser' } as ApplicationInventoryRawRecord
      ], 'com.huawei.securitytool')
      viewModel.state.appSnapshots = applications

      viewModel.setSearchKeyword('browser')

      expect(viewModel.state.filteredAppKeys.length).assertEqual(1)
      expect(viewModel.state.selectedAppKey).assertEqual('')
    })

    it('should bind selected application by app key instead of label', 0, () => {
      let viewModel = new PermissionViewModel()
      let applications = ApplicationInventoryRepository.normalizeApplications(100, [
        { bundleName: 'com.example.first', label: 'Label' } as ApplicationInventoryRawRecord,
        { bundleName: 'com.example.second', label: 'Label' } as ApplicationInventoryRawRecord
      ], 'com.huawei.securitytool')
      viewModel.state.appSnapshots = applications
      viewModel.setSearchKeyword('')

      let secondKey = viewModel.state.appSnapshots.find((s: PermissionAppSnapshot): boolean =>
        s.bundleName === 'com.example.second'
      )?.appKey ?? ''
      viewModel.selectApplication(secondKey)

      expect(viewModel.state.selectedAppKey).assertEqual(secondKey)
    })

    it('should refresh selected application state after a successful running policy write', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let app = buildManagedApplication(100, 'com.example.label', 'Label')
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        let setRunningPolicyMock = mockKit.mockFunc(PermissionService, PermissionService.setRunningBlocked)
        let loadAccountPolicySnapshotMock = mockKit.mockFunc(PermissionService, PermissionService.loadAccountPolicySnapshot)
        when(loadApplicationsMock)(ArgumentMatchers.any).afterReturn(Promise.resolve({
          appSnapshots: [buildAppSnapshot(app)],
          installPolicies: []
        } as ApplicationInventoryResult))
        when(setRunningPolicyMock)().afterReturn(Promise.resolve({
          success: true,
          message: 'ok'
        } as PermissionActionResult))
        when(loadAccountPolicySnapshotMock)().afterReturn(Promise.resolve({
          appSnapshots: [buildAppSnapshot(app, true)],
          installPolicies: []
        } as ApplicationInventoryResult))

        viewModel.state.selectedAccountId = 100
        await viewModel.refreshApplicationList()
        viewModel.selectApplication(app.appKey)
        let result = await viewModel.setSelectedRunningPolicy('denied')

        let selectedApp = viewModel.state.appSnapshots.find((item: PermissionAppSnapshot): boolean => item.appKey === app.appKey)
        expect(result.success).assertTrue()
        expect(selectedApp?.runningBlocked).assertTrue()
        expect(viewModel.state.policyRecords.length).assertEqual(1)
        expect(viewModel.state.policyRecords[0].appKey).assertEqual(app.appKey)
      } finally {
        mockKit.clearAll()
        done()
      }
    })

    it('should refresh selected application state after successful uninstall and network policy writes', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let app = buildManagedApplication(100, 'com.example.label', 'Label')
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        let setUninstallPolicyMock = mockKit.mockFunc(PermissionService, PermissionService.setUninstallProtected)
        let setNetworkPolicyMock = mockKit.mockFunc(PermissionService, PermissionService.setNetworkBlocked)
        when(loadApplicationsMock)(ArgumentMatchers.any).afterReturn(Promise.resolve({
          appSnapshots: [buildAppSnapshot(app)],
          installPolicies: []
        } as ApplicationInventoryResult))
        when(setUninstallPolicyMock)().afterReturn(Promise.resolve({
          success: true,
          message: 'ok'
        } as PermissionActionResult))
        when(setNetworkPolicyMock)().afterReturn(Promise.resolve({
          success: true,
          message: 'ok'
        } as PermissionActionResult))

        viewModel.state.selectedAccountId = 100
        await viewModel.refreshApplicationList()
        viewModel.selectApplication(app.appKey)
        let uninstallResult = await viewModel.setSelectedUninstallProtected(true)
        let networkResult = await viewModel.setSelectedNetworkPolicy('denied')

        let selectedApp = viewModel.state.appSnapshots.find((item: PermissionAppSnapshot): boolean => item.appKey === app.appKey)
        let uninstallRecords = viewModel.state.policyRecords.filter((record: PermissionPolicyRecord): boolean =>
          record.actionKind === 'uninstall-protect'
        )
        let networkRecords = viewModel.state.policyRecords.filter((record: PermissionPolicyRecord): boolean =>
          record.actionKind === 'network'
        )
        expect(uninstallResult.success).assertTrue()
        expect(networkResult.success).assertTrue()
        expect(selectedApp?.uninstallProtected).assertTrue()
        expect(selectedApp?.networkBlocked).assertTrue()
        expect(uninstallRecords.length).assertEqual(1)
        expect(networkRecords.length).assertEqual(1)
      } finally {
        mockKit.clearAll()
        done()
      }
    })

    it('should keep policy state while refreshing application list', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let app = buildManagedApplication(100, 'com.example.label', 'Label')
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        when(loadApplicationsMock)(ArgumentMatchers.any).afterReturn(Promise.resolve({
          appSnapshots: [buildAppSnapshot(app)],
          installPolicies: []
        } as ApplicationInventoryResult))

        viewModel.state.selectedAccountId = 100
        viewModel.state.selectedAppKey = app.appKey
        viewModel.state.appSnapshots = [buildAppSnapshot(app, true, true, true)]
        viewModel.state.installPolicies = [{
          accountId: 100,
          policyId: 'com.example.future',
          policy: 'denied'
        } as AccountInstallPolicySnapshot]

        let success = await viewModel.refreshApplicationList()

        let selectedApp = viewModel.state.appSnapshots.find((item: PermissionAppSnapshot): boolean => item.appKey === app.appKey)
        expect(success).assertTrue()
        expect(selectedApp?.uninstallProtected).assertTrue()
        expect(selectedApp?.runningBlocked).assertTrue()
        expect(selectedApp?.networkBlocked).assertTrue()
        expect(viewModel.state.policyRecords.length).assertEqual(4)
      } finally {
        mockKit.clearAll()
        done()
      }
    })

    it('should de-duplicate install deny policy by account and package', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let setInstallPolicyMock = mockKit.mockFunc(PermissionService, PermissionService.setDisallowedInstallPolicyId)
        when(setInstallPolicyMock)(ArgumentMatchers.any).afterReturn(Promise.resolve({
          success: true,
          message: 'ok'
        } as PermissionActionResult))

        viewModel.state.selectedAccountId = 100
        viewModel.state.installBlockKeyword = 'com.example.future'
        viewModel.state.installPolicies = [
          {
            accountId: 100,
            policyId: 'com.example.future',
            policy: 'denied'
          } as AccountInstallPolicySnapshot,
          {
            accountId: 100,
            policyId: 'com.example.other',
            policy: 'denied'
          } as AccountInstallPolicySnapshot,
          {
            accountId: 101,
            policyId: 'com.example.future',
            policy: 'denied'
          } as AccountInstallPolicySnapshot
        ]

        let result = await viewModel.setDisallowedInstallByKeyword()
        let currentAccountMatches = viewModel.state.installPolicies.filter((policy: AccountInstallPolicySnapshot): boolean =>
          policy.accountId === 100 && policy.policyId === 'com.example.future'
        )

        expect(result.success).assertTrue()
        expect(currentAccountMatches.length).assertEqual(1)
        expect(viewModel.state.installPolicies.length).assertEqual(3)
        expect(viewModel.state.installBlockKeyword).assertEqual('')
      } finally {
        mockKit.clearAll()
        done()
      }
    })

    it('should restore selected application state after current policy deletion', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let app = buildManagedApplication(100, 'com.example.label', 'Label')
        viewModel.state.selectedAccountId = 100
        viewModel.state.selectedAppKey = app.appKey
        let applications: PermissionAppSnapshot[] = [{
          appKey: app.appKey,
          accountId: app.accountId,
          bundleName: app.bundleName,
          appId: app.appId,
          appIdentifier: app.appIdentifier,
          appIndex: app.appIndex,
          uid: app.uid,
          label: app.label,
          uninstallProtected: false,
          runningBlocked: true,
          networkBlocked: false,
          threeDGroups: [],
          threeDPolicies: [],
          threeDLoadState: 'idle',
          threeDMessage: ''
        } as PermissionAppSnapshot]
        viewModel.state.appSnapshots = applications
        viewModel.state.policyRecords = [PermissionService.buildPolicyRecordsFromState(
          applications, []
        )[0]]
        let deletePolicyRecordMock = mockKit.mockFunc(PermissionService, PermissionService.deletePolicyRecord)
        let loadAccountPolicySnapshotMock = mockKit.mockFunc(PermissionService, PermissionService.loadAccountPolicySnapshot)
        when(deletePolicyRecordMock)().afterReturn(Promise.resolve({
          success: true,
          message: 'ok'
        } as PermissionActionResult))
        when(loadAccountPolicySnapshotMock)().afterReturn(Promise.resolve({
          appSnapshots: [buildAppSnapshot(app, false)],
          installPolicies: []
        } as ApplicationInventoryResult))

        let result = await viewModel.deletePolicyRecord(viewModel.state.policyRecords[0].key)

        let selectedApp = viewModel.state.appSnapshots.find((item: PermissionAppSnapshot): boolean => item.appKey === app.appKey)
        expect(result.success).assertTrue()
        expect(selectedApp?.runningBlocked).assertFalse()
        expect(viewModel.state.policyRecords.length).assertEqual(0)
      } finally {
        mockKit.clearAll()
        done()
      }
    })

    it('should restore uninstall protection after current policy deletion', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let app = buildManagedApplication(100, 'com.example.label', 'Label')
        viewModel.state.selectedAccountId = 100
        viewModel.state.selectedAppKey = app.appKey
        let applications: PermissionAppSnapshot[] = [buildAppSnapshot(app, false, false, true)]
        viewModel.state.appSnapshots = applications
        viewModel.state.policyRecords = PermissionService.buildPolicyRecordsFromState(applications, [])
        let deletePolicyRecordMock = mockKit.mockFunc(PermissionService, PermissionService.deletePolicyRecord)
        when(deletePolicyRecordMock)().afterReturn(Promise.resolve({
          success: true,
          message: 'ok'
        } as PermissionActionResult))

        let uninstallRecord = viewModel.state.policyRecords.find((record: PermissionPolicyRecord): boolean =>
          record.actionKind === 'uninstall-protect'
        )
        let result = await viewModel.deletePolicyRecord(uninstallRecord!.key)

        let selectedApp = viewModel.state.appSnapshots.find((item: PermissionAppSnapshot): boolean => item.appKey === app.appKey)
        expect(result.success).assertTrue()
        expect(selectedApp?.uninstallProtected).assertFalse()
        expect(viewModel.state.policyRecords.filter((record: PermissionPolicyRecord): boolean =>
          record.actionKind === 'uninstall-protect'
        ).length).assertEqual(0)
      } finally {
        mockKit.clearAll()
        done()
      }
    })

    it('should restore running policy to default after allowing', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let app = buildManagedApplication(100, 'com.example.label', 'Label')
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        let setRunningPolicyMock = mockKit.mockFunc(PermissionService, PermissionService.setRunningBlocked)
        when(loadApplicationsMock)(ArgumentMatchers.any).afterReturn(Promise.resolve({
          appSnapshots: [buildAppSnapshot(app, true)],
          installPolicies: []
        } as ApplicationInventoryResult))
        when(setRunningPolicyMock)().afterReturn(Promise.resolve({
          success: true,
          message: 'ok'
        } as PermissionActionResult))

        viewModel.state.selectedAccountId = 100
        await viewModel.refreshApplicationList()
        viewModel.selectApplication(app.appKey)
        let result = await viewModel.setSelectedRunningPolicy('default')

        let selectedApp = viewModel.state.appSnapshots.find((item: PermissionAppSnapshot): boolean => item.appKey === app.appKey)
        expect(result.success).assertTrue()
        expect(selectedApp?.runningBlocked).assertFalse()
        expect(viewModel.state.policyRecords.filter((r: PermissionPolicyRecord): boolean => r.actionKind === 'running').length).assertEqual(0)
      } finally {
        mockKit.clearAll()
        done()
      }
    })

    it('should restore network policy to default after allowing', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let app = buildManagedApplication(100, 'com.example.label', 'Label')
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        let setNetworkPolicyMock = mockKit.mockFunc(PermissionService, PermissionService.setNetworkBlocked)
        when(loadApplicationsMock)(ArgumentMatchers.any).afterReturn(Promise.resolve({
          appSnapshots: [buildAppSnapshot(app, false, true)],
          installPolicies: []
        } as ApplicationInventoryResult))
        when(setNetworkPolicyMock)().afterReturn(Promise.resolve({
          success: true,
          message: 'ok'
        } as PermissionActionResult))

        viewModel.state.selectedAccountId = 100
        await viewModel.refreshApplicationList()
        viewModel.selectApplication(app.appKey)
        let result = await viewModel.setSelectedNetworkPolicy('default')

        let selectedApp = viewModel.state.appSnapshots.find((item: PermissionAppSnapshot): boolean => item.appKey === app.appKey)
        expect(result.success).assertTrue()
        expect(selectedApp?.networkBlocked).assertFalse()
        expect(viewModel.state.policyRecords.filter((r: PermissionPolicyRecord): boolean => r.actionKind === 'network').length).assertEqual(0)
      } finally {
        mockKit.clearAll()
        done()
      }
    })

    it('should delete network policy record and restore default', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let app = buildManagedApplication(100, 'com.example.label', 'Label')
        viewModel.state.selectedAccountId = 100
        viewModel.state.selectedAppKey = app.appKey
        let applications: PermissionAppSnapshot[] = [buildAppSnapshot(app, false, true)]
        viewModel.state.appSnapshots = applications
        viewModel.state.policyRecords = PermissionService.buildPolicyRecordsFromState(applications, [])
        let deletePolicyRecordMock = mockKit.mockFunc(PermissionService, PermissionService.deletePolicyRecord)
        when(deletePolicyRecordMock)().afterReturn(Promise.resolve({
          success: true,
          message: 'ok'
        } as PermissionActionResult))

        let networkRecord = viewModel.state.policyRecords.find((r: PermissionPolicyRecord): boolean => r.actionKind === 'network')
        let result = await viewModel.deletePolicyRecord(networkRecord!.key)

        let selectedApp = viewModel.state.appSnapshots.find((item: PermissionAppSnapshot): boolean => item.appKey === app.appKey)
        expect(result.success).assertTrue()
        expect(selectedApp?.networkBlocked).assertFalse()
        expect(viewModel.state.policyRecords.filter((r: PermissionPolicyRecord): boolean => r.actionKind === 'network').length).assertEqual(0)
      } finally {
        mockKit.clearAll()
        done()
      }
    })

    it('should add 3D policy record when setting non-default state', 0, async (done: Function) => {
      let mockKit = new MockKit()
      PermissionPolicyLocalRepository.resetForTest()
      try {
        let viewModel = new PermissionViewModel()
        let app = buildManagedApplication(100, 'com.example.label', 'Label')
        let threeDGroups: ThreeDPermissionItem[] = [{
          groupKey: 'downloads',
          title: 'Downloads',
          permissionNames: ['ohos.permission.READ_MEDIA'],
          declaredPermissions: ['ohos.permission.READ_MEDIA'],
          managedState: 'default',
          canManage: true,
          disabledReason: ''
        } as ThreeDPermissionItem]
        let snapshot = buildAppSnapshot(app)
        snapshot.threeDGroups = threeDGroups
        viewModel.state.selectedAccountId = 100
        viewModel.state.selectedAppKey = app.appKey
        viewModel.state.appSnapshots = [snapshot]
        viewModel.state.policyRecords = PermissionService.buildPolicyRecordsFromState([snapshot], [])
        let setThreeDStateMock = mockKit.mockFunc(PermissionService, PermissionService.setThreeDState)
        when(setThreeDStateMock)().afterReturn(Promise.resolve({
          success: true,
          message: 'ok'
        } as PermissionActionResult))

        let result = await viewModel.setSelectedThreeDPermissionState('downloads', 'denied')

        let selectedApp = viewModel.state.appSnapshots.find((item: PermissionAppSnapshot): boolean => item.appKey === app.appKey)
        let downloadsGroup = selectedApp?.threeDGroups.find((g: ThreeDPermissionItem): boolean => g.groupKey === 'downloads')
        expect(result.success).assertTrue()
        expect(downloadsGroup?.managedState).assertEqual('denied')
        expect(viewModel.state.policyRecords.filter((r: PermissionPolicyRecord): boolean => r.actionKind === 'three-d').length).assertEqual(1)
        expect(viewModel.state.policyRecords[0].targetDetail).assertEqual(`${app.bundleName} / Downloads`)
      } finally {
        mockKit.clearAll()
        PermissionPolicyLocalRepository.resetForTest()
        done()
      }
    })

    it('should remove 3D policy record when restoring default', 0, async (done: Function) => {
      let mockKit = new MockKit()
      PermissionPolicyLocalRepository.resetForTest()
      try {
        let viewModel = new PermissionViewModel()
        let app = buildManagedApplication(100, 'com.example.label', 'Label')
        let threeDGroups: ThreeDPermissionItem[] = [{
          groupKey: 'downloads',
          title: 'Downloads',
          permissionNames: ['ohos.permission.READ_MEDIA'],
          declaredPermissions: ['ohos.permission.READ_MEDIA'],
          managedState: 'denied',
          canManage: true,
          disabledReason: ''
        } as ThreeDPermissionItem]
        let snapshot = buildAppSnapshot(app)
        snapshot.threeDGroups = threeDGroups
        snapshot.threeDPolicies = [{
          recordId: `three-d:${app.appKey}:downloads`,
          appKey: app.appKey,
          groupKey: 'downloads',
          actionKind: 'three-d',
          policyValue: 'denied',
          policyType: 'Downloads',
          targetName: app.label,
          targetDetail: `${app.bundleName} / Downloads`,
          statusLabel: 'denied',
          scopeLabel: 'account 100'
        } as PermissionThreeDPolicySnapshot]
        viewModel.state.selectedAccountId = 100
        viewModel.state.selectedAppKey = app.appKey
        viewModel.state.appSnapshots = [snapshot]
        viewModel.state.policyRecords = PermissionService.buildPolicyRecordsFromState([snapshot], [])
        let setThreeDStateMock = mockKit.mockFunc(PermissionService, PermissionService.setThreeDState)
        when(setThreeDStateMock)().afterReturn(Promise.resolve({
          success: true,
          message: 'ok'
        } as PermissionActionResult))

        let result = await viewModel.setSelectedThreeDPermissionState('downloads', 'default')

        let selectedApp = viewModel.state.appSnapshots.find((item: PermissionAppSnapshot): boolean => item.appKey === app.appKey)
        let downloadsGroup = selectedApp?.threeDGroups.find((g: ThreeDPermissionItem): boolean => g.groupKey === 'downloads')
        expect(result.success).assertTrue()
        expect(downloadsGroup?.managedState).assertEqual('default')
        expect(viewModel.state.policyRecords.filter((r: PermissionPolicyRecord): boolean => r.actionKind === 'three-d').length).assertEqual(0)
      } finally {
        mockKit.clearAll()
        PermissionPolicyLocalRepository.resetForTest()
        done()
      }
    })

    it('should not merge stale local 3D records for missing appKey', 0, async (done: Function) => {
      let mockKit = new MockKit()
      PermissionPolicyLocalRepository.resetForTest()
      try {
        let app = buildManagedApplication(100, 'com.example.mail', 'Mail')
        let snapshot = buildAppSnapshot(app)
        await PermissionPolicyLocalRepository.upsertActive({
          recordId: 'three-d:100:com.example.missing:downloads',
          accountId: 100,
          appKey: '100:com.example.missing',
          bundleName: 'com.example.missing',
          appIdentifier: '',
          appIndex: 0,
          policyType: 'Downloads',
          policyValue: 'denied',
          targetName: 'Missing',
          targetDetail: 'com.example.missing / Downloads',
          statusLabel: 'denied',
          scopeLabel: 'account 100',
          actionKind: 'three-d',
          policyId: 'downloads',
          status: 'active',
          createdAt: 1,
          updatedAt: 1,
          lastError: ''
        } as PermissionLocalPolicyRecord)

        let loadSnapshotMock = mockKit.mockFunc(PermissionAccountPolicyTaskRunner, PermissionAccountPolicyTaskRunner.loadSnapshot)
        when(loadSnapshotMock)().afterReturn(Promise.resolve({
          controlLists: ApplicationControlRepository.createEmptyControlLists(),
          restrictedAppUids: []
        } as PermissionAccountPolicySnapshotTaskData))

        let result = await PermissionService.loadAccountPolicySnapshot(100, [snapshot])
        let records = PermissionService.buildPolicyRecordsFromState(result.appSnapshots, result.installPolicies)

        expect(records.filter((r: PermissionPolicyRecord): boolean => r.actionKind === 'three-d').length).assertEqual(0)
        expect(records.some((r: PermissionPolicyRecord): boolean => r.appKey === '100:com.example.missing')).assertFalse()
      } finally {
        mockKit.clearAll()
        PermissionPolicyLocalRepository.resetForTest()
        done()
      }
    })

    it('should keep state unchanged when policy action fails', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let app = buildManagedApplication(100, 'com.example.label', 'Label')
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        let setRunningPolicyMock = mockKit.mockFunc(PermissionService, PermissionService.setRunningBlocked)
        when(loadApplicationsMock)(ArgumentMatchers.any).afterReturn(Promise.resolve({
          appSnapshots: [buildAppSnapshot(app, false)],
          installPolicies: []
        } as ApplicationInventoryResult))
        when(setRunningPolicyMock)().afterReturn(Promise.resolve({
          success: false,
          message: 'failed'
        } as PermissionActionResult))

        viewModel.state.selectedAccountId = 100
        await viewModel.refreshApplicationList()
        viewModel.selectApplication(app.appKey)
        let managedCountBefore = viewModel.state.summary.managedCount
        let recordsBefore = viewModel.state.policyRecords.length
        let result = await viewModel.setSelectedRunningPolicy('denied')

        let selectedApp = viewModel.state.appSnapshots.find((item: PermissionAppSnapshot): boolean => item.appKey === app.appKey)
        expect(result.success).assertFalse()
        expect(selectedApp?.runningBlocked).assertFalse()
        expect(viewModel.state.policyRecords.length).assertEqual(recordsBefore)
        expect(viewModel.state.summary.managedCount).assertEqual(managedCountBefore)
      } finally {
        mockKit.clearAll()
        done()
      }
    })
  })
}
