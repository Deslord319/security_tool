import { describe, expect, it } from '@ohos/hypium'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import {
  ApplicationInventoryResult,
  ApplicationPermissionProfile,
  ManagedApplicationInfo,
  PermissionActionResult,
  PermissionAppSnapshot,
  PermissionAccountListResult,
  PermissionLocalPolicyRecord,
  PermissionManagedAccount,
  PermissionPolicyRecord,
  PermissionThreeDPolicySnapshot
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

function buildPermissionAccount(accountId: number, isForeground: boolean = false): PermissionManagedAccount {
  return {
    accountId: accountId,
    displayName: `用户 ${accountId}`,
    isForeground: isForeground,
    isAvailable: true
  } as PermissionManagedAccount
}

function buildManagedApplication(accountId: number, bundleName: string, label: string): ManagedApplicationInfo {
  return ApplicationInventoryRepository.normalizeApplications(accountId, [
    {
      bundleName: bundleName,
      label: label,
      systemApp: false
    } as ApplicationInventoryRawRecord
  ], 'com.huawei.securitytool')[0]
}

function buildAppSnapshot(
  app: ManagedApplicationInfo,
  runningBlocked: boolean = false,
  networkBlocked: boolean = false,
  uninstallProtected: boolean = false
): PermissionAppSnapshot {
  return {
    appKey: app.key,
    accountId: app.accountId,
    bundleName: app.bundleName,
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

function buildEmptyPermissionProfile(app: ManagedApplicationInfo): ApplicationPermissionProfile {
  return {
    appKey: app.key,
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
      expect(viewModel.state.applications.length).assertEqual(0)
      expect(viewModel.state.selectedAppKey).assertEqual('')
    })

    it('should load initial skeleton state without system side effects', 0, async (done: Function) => {
      let viewModel = new PermissionViewModel()
      await viewModel.loadInitialState()

      expect(viewModel.state.initialized).assertTrue()
      expect(viewModel.state.loading).assertFalse()
      expect(viewModel.state.adminActivated).assertFalse()
      expect(viewModel.state.accounts.length >= 0).assertTrue()
      expect(viewModel.state.summary.appCount).assertEqual(0)
      expect(viewModel.state.summary.managedCount).assertEqual(0)
      done()
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
            applications: [buildManagedApplication(accountId, 'com.example.mail', 'Mail')],
            appSnapshots: [],
            installPolicies: [],
            policyRecords: []
          } as ApplicationInventoryResult)
        })

        let success = await viewModel.refreshAccountsAndApplicationList()

        expect(success).assertTrue()
        expect(viewModel.state.accounts.length).assertEqual(2)
        expect(viewModel.state.selectedAccountId).assertEqual(100)
        expect(loadedAccountId).assertEqual(100)
        expect(viewModel.state.applications[0].accountId).assertEqual(100)
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
        viewModel.state.applications = [buildManagedApplication(100, 'com.example.mail', 'Mail')]
        viewModel.state.selectedAppKey = viewModel.state.applications[0].key
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
            applications: [buildManagedApplication(accountId, 'com.example.browser', 'Browser')],
            appSnapshots: [],
            installPolicies: [],
            policyRecords: []
          } as ApplicationInventoryResult)
        })

        let success = await viewModel.refreshAccountsAndApplicationList()

        expect(success).assertTrue()
        expect(viewModel.state.selectedAccountId).assertEqual(101)
        expect(loadedAccountId).assertEqual(101)
        expect(viewModel.state.selectedAppKey).assertEqual('')
        expect(viewModel.state.policyRecords.length).assertEqual(0)
        expect(viewModel.state.applications[0].accountId).assertEqual(101)
      } finally {
        mockKit.clearAll()
        done()
      }
    })

    it('should summarize managed application states', 0, () => {
      let applications: ManagedApplicationInfo[] = [
        {
          key: '100:demo:demo:0',
          accountId: 100,
          bundleName: 'demo',
          appIdentifier: 'demo',
          appIndex: 0,
          uid: 10001,
          label: 'Demo',
          versionName: '1.0.0',
          iconData: '',
          systemApp: false,
          removable: true,
          installSource: '',
          appDistributionType: '',
          installPolicy: 'default',
          uninstallProtected: false,
          runningPolicy: 'default',
          networkPolicy: 'denied'
        } as ManagedApplicationInfo
      ]

      let summary = PermissionService.buildSummary(applications)

      expect(summary.appCount).assertEqual(1)
      expect(summary.managedCount).assertEqual(1)
      expect(summary.networkRestrictedCount).assertEqual(1)
    })

    it('should normalize manageable applications and skip system or self bundle only', 0, () => {
      let rawRecords: ApplicationInventoryRawRecord[] = [
        {
          bundleName: 'com.example.demo',
          label: 'Demo',
          appIdentifier: 'demo-id',
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

      let demo = applications.find((app: ManagedApplicationInfo): boolean => app.bundleName === 'com.example.demo')
      let nonRemovable = applications.find((app: ManagedApplicationInfo): boolean =>
        app.bundleName === 'com.example.nonremovable'
      )
      expect(applications.length).assertEqual(2)
      expect(demo?.key).assertEqual('100:com.example.demo')
      expect(demo?.label).assertEqual('Demo')
      expect(demo?.installPolicy).assertEqual('default')
      expect(nonRemovable?.key).assertEqual('100:com.example.nonremovable')
      expect(nonRemovable?.appIdentifier).assertEqual('')
      expect(applications.some((app: ManagedApplicationInfo): boolean => app.bundleName === 'com.example.system')).assertFalse()
      expect(applications.some((app: ManagedApplicationInfo): boolean => app.bundleName === 'com.ohos.formrenderservice')).assertFalse()
      expect(applications.some((app: ManagedApplicationInfo): boolean => app.bundleName === 'com.example.nonremovable')).assertTrue()
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

      let first = applications.find((app: ManagedApplicationInfo): boolean => app.bundleName === 'com.example.first')
      let second = applications.find((app: ManagedApplicationInfo): boolean => app.bundleName === 'com.example.second')

      expect(applications.length).assertEqual(2)
      expect(first?.key).assertEqual('100:com.example.first')
      expect(second?.key).assertEqual('100:com.example.second')
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
          appIdentifier: 'mail-id',
          systemApp: false
        } as ApplicationInventoryRawRecord,
        {
          bundleName: 'com.example.browser',
          label: 'Browser',
          appIdentifier: 'browser-id',
          systemApp: false
        } as ApplicationInventoryRawRecord
      ], 'com.huawei.securitytool')

      let merged = ApplicationControlRepository.mergeControlStates(100, applications, {
        allowedInstallIds: ['com.example.mail'],
        disallowedInstallIds: ['com.example.browser'],
        disallowedUninstallIds: ['com.example.mail'],
        allowedRunningIds: ['com.example.browser'],
        disallowedRunningIds: ['com.example.mail']
      })

      let mail = merged.find((app: ManagedApplicationInfo): boolean => app.bundleName === 'com.example.mail')
      let browser = merged.find((app: ManagedApplicationInfo): boolean => app.bundleName === 'com.example.browser')

      expect(mail?.installPolicy).assertEqual('allowed')
      expect(mail?.uninstallProtected).assertTrue()
      expect(mail?.runningPolicy).assertEqual('denied')
      expect(browser?.installPolicy).assertEqual('denied')
      expect(browser?.runningPolicy).assertEqual('default')
    })

    it('should use bundle name as running policy id', 0, () => {
      let app = ApplicationInventoryRepository.normalizeApplications(100, [
        {
          bundleName: 'com.example.mail',
          label: 'Mail',
          appIdentifier: 'mail-id',
          systemApp: false
        } as ApplicationInventoryRawRecord
      ], 'com.huawei.securitytool')[0]

      let cleanupIds = ApplicationControlRepository.buildRunningPolicyCleanupIdsForTest(app)

      expect(cleanupIds.length).assertEqual(1)
      expect(cleanupIds.includes('com.example.mail')).assertTrue()
      expect(cleanupIds.includes('mail-id')).assertFalse()
    })

    it('should not match uninstall protection by shared app identifier', 0, () => {
      let applications = ApplicationInventoryRepository.normalizeApplications(100, [
        {
          bundleName: 'com.example.first',
          label: 'First',
          appIdentifier: 'shared-debug-id',
          systemApp: false
        } as ApplicationInventoryRawRecord,
        {
          bundleName: 'com.example.second',
          label: 'Second',
          appIdentifier: 'shared-debug-id',
          systemApp: false
        } as ApplicationInventoryRawRecord
      ], 'com.huawei.securitytool')

      let sharedIdMerged = ApplicationControlRepository.mergeControlStates(100, applications, {
        allowedInstallIds: [],
        disallowedInstallIds: [],
        disallowedUninstallIds: ['shared-debug-id'],
        allowedRunningIds: [],
        disallowedRunningIds: []
      })
      let bundleMerged = ApplicationControlRepository.mergeControlStates(100, applications, {
        allowedInstallIds: [],
        disallowedInstallIds: [],
        disallowedUninstallIds: ['com.example.second'],
        allowedRunningIds: [],
        disallowedRunningIds: []
      })
      let firstBySharedId = sharedIdMerged.find((app: ManagedApplicationInfo): boolean =>
        app.bundleName === 'com.example.first'
      )
      let secondBySharedId = sharedIdMerged.find((app: ManagedApplicationInfo): boolean =>
        app.bundleName === 'com.example.second'
      )
      let secondByBundle = bundleMerged.find((app: ManagedApplicationInfo): boolean =>
        app.bundleName === 'com.example.second'
      )

      expect(firstBySharedId?.uninstallProtected).assertFalse()
      expect(secondBySharedId?.uninstallProtected).assertFalse()
      expect(secondByBundle?.uninstallProtected).assertTrue()
    })

    it('should scope control policies by account and bundle key', 0, () => {
      let account100App = ApplicationInventoryRepository.normalizeApplications(100, [
        {
          bundleName: 'com.example.mail',
          label: 'Mail',
          systemApp: false
        } as ApplicationInventoryRawRecord
      ], 'com.huawei.securitytool')[0]
      let account101App = ApplicationInventoryRepository.normalizeApplications(101, [
        {
          bundleName: 'com.example.mail',
          label: 'Mail',
          systemApp: false
        } as ApplicationInventoryRawRecord
      ], 'com.huawei.securitytool')[0]

      let merged = ApplicationControlRepository.mergeControlStates(100, [account100App, account101App], {
        allowedInstallIds: [],
        disallowedInstallIds: [],
        disallowedUninstallIds: ['com.example.mail'],
        allowedRunningIds: [],
        disallowedRunningIds: ['com.example.mail']
      })
      let account100State = merged.find((app: ManagedApplicationInfo): boolean => app.key === account100App.key)
      let account101State = merged.find((app: ManagedApplicationInfo): boolean => app.key === account101App.key)

      expect(account100State?.uninstallProtected).assertTrue()
      expect(account100State?.runningPolicy).assertEqual('denied')
      expect(account101State?.uninstallProtected).assertFalse()
      expect(account101State?.runningPolicy).assertEqual('default')
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
      let mail = merged.find((app: ManagedApplicationInfo): boolean => app.bundleName === 'com.example.mail')
      let browser = merged.find((app: ManagedApplicationInfo): boolean => app.bundleName === 'com.example.browser')

      expect(mail?.networkPolicy).assertEqual('default')
      expect(browser?.networkPolicy).assertEqual('denied')
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
      let account100State = merged.find((app: ManagedApplicationInfo): boolean => app.key === account100App.key)
      let account101State = merged.find((app: ManagedApplicationInfo): boolean => app.key === account101App.key)

      expect(account100State?.networkPolicy).assertEqual('denied')
      expect(account101State?.networkPolicy).assertEqual('default')
    })

    it('should build application policy records for the selected account only', 0, () => {
      let account100App = {
        key: '100:com.example.mail',
        accountId: 100,
        bundleName: 'com.example.mail',
        appIdentifier: 'mail-id',
        appIndex: 0,
        uid: 10001,
        label: 'Mail',
        versionName: '',
        iconData: '',
        systemApp: false,
        removable: true,
        installSource: '',
        appDistributionType: '',
        mainAbilityName: '',
        installPolicy: 'default',
        uninstallProtected: true,
        runningPolicy: 'default',
        networkPolicy: 'default'
      } as ManagedApplicationInfo
      let account101App = {
        key: '101:com.example.mail',
        accountId: 101,
        bundleName: 'com.example.mail',
        appIdentifier: 'mail-id',
        appIndex: 0,
        uid: 110001,
        label: 'Mail',
        versionName: '',
        iconData: '',
        systemApp: false,
        removable: true,
        installSource: '',
        appDistributionType: '',
        mainAbilityName: '',
        installPolicy: 'default',
        uninstallProtected: true,
        runningPolicy: 'default',
        networkPolicy: 'default'
      } as ManagedApplicationInfo

      let records = PermissionService.buildApplicationPolicyRecordsForAccount(100, [account100App, account101App])

      expect(records.length).assertEqual(1)
      expect(records[0].appKey).assertEqual(account100App.key)
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
        appKey: app.key,
        groupKey: 'downloads',
        actionKind: 'three-d',
        policyValue: 'denied',
        policyType: 'Downloads',
        targetName: 'Mail',
        targetDetail: 'mail / Downloads',
        statusLabel: 'denied',
        scopeLabel: 'account 100'
      } as PermissionThreeDPolicySnapshot]

      let records = PermissionService.buildPolicyRecordsFromSnapshots([snapshot], [])

      expect(records.length).assertEqual(1)
      expect(records[0].key).assertEqual('three-d:100:mail:downloads')
      expect(records[0].appKey).assertEqual(app.key)
    })

    it('should derive no 3D current policy when snapshot table has no matching app', 0, () => {
      let app = buildManagedApplication(100, 'browser', 'Browser')
      let records = PermissionService.buildPolicyRecordsFromSnapshots([buildAppSnapshot(app)], [])

      expect(records.length).assertEqual(0)
    })

    it('should update filtered applications without selecting an app by default', 0, () => {
      let viewModel = new PermissionViewModel()
      viewModel.state.applications = ApplicationInventoryRepository.normalizeApplications(100, [
        { bundleName: 'com.example.mail', label: 'Mail' } as ApplicationInventoryRawRecord,
        { bundleName: 'com.example.browser', label: 'Browser' } as ApplicationInventoryRawRecord
      ], 'com.huawei.securitytool')

      viewModel.setSearchKeyword('browser')

      expect(viewModel.state.filteredApplications.length).assertEqual(1)
      expect(viewModel.state.selectedAppKey).assertEqual('')
    })

    it('should bind selected application by app key instead of label', 0, () => {
      let viewModel = new PermissionViewModel()
      viewModel.state.applications = ApplicationInventoryRepository.normalizeApplications(100, [
        { bundleName: 'com.example.first', label: 'Label' } as ApplicationInventoryRawRecord,
        { bundleName: 'com.example.second', label: 'Label' } as ApplicationInventoryRawRecord
      ], 'com.huawei.securitytool')
      viewModel.setSearchKeyword('')

      let second = viewModel.state.filteredApplications.find((app: ManagedApplicationInfo): boolean =>
        app.bundleName === 'com.example.second'
      )
      viewModel.selectApplication(second?.key ?? '')

      expect(viewModel.state.selectedAppKey).assertEqual(second?.key ?? '')
    })

    it('should refresh selected application state after a successful running policy write', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let app = buildManagedApplication(100, 'com.example.label', 'Label')
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        let setRunningPolicyMock = mockKit.mockFunc(PermissionService, PermissionService.setRunningPolicy)
        let loadAccountPolicySnapshotMock = mockKit.mockFunc(PermissionService, PermissionService.loadAccountPolicySnapshot)
        when(loadApplicationsMock)(ArgumentMatchers.any).afterReturn(Promise.resolve({
          applications: [app],
          appSnapshots: [],
          installPolicies: [],
          policyRecords: []
        } as ApplicationInventoryResult))
        when(setRunningPolicyMock)().afterReturn(Promise.resolve({
          success: true,
          message: 'ok'
        } as PermissionActionResult))
        when(loadAccountPolicySnapshotMock)().afterReturn(Promise.resolve({
          applications: [app],
          appSnapshots: [buildAppSnapshot(app, true)],
          installPolicies: [],
          policyRecords: []
        } as ApplicationInventoryResult))

        viewModel.state.selectedAccountId = 100
        await viewModel.refreshApplicationList()
        viewModel.selectApplication(app.key)
        let result = await viewModel.setSelectedRunningPolicy('denied')

        let selectedApp = viewModel.state.applications.find((item: ManagedApplicationInfo): boolean => item.key === app.key)
        expect(result.success).assertTrue()
        expect(selectedApp?.runningPolicy).assertEqual('denied')
        expect(viewModel.state.policyRecords.length).assertEqual(1)
        expect(viewModel.state.policyRecords[0].appKey).assertEqual(app.key)
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
        viewModel.state.selectedAppKey = app.key
        viewModel.state.applications = [{
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
          installPolicy: 'default',
          uninstallProtected: false,
          runningPolicy: 'denied',
          networkPolicy: 'default'
        } as ManagedApplicationInfo]
        viewModel.state.policyRecords = [PermissionService.buildApplicationPolicyRecords([viewModel.state.applications[0]])[0]]
        let deletePolicyRecordMock = mockKit.mockFunc(PermissionService, PermissionService.deletePolicyRecord)
        let loadAccountPolicySnapshotMock = mockKit.mockFunc(PermissionService, PermissionService.loadAccountPolicySnapshot)
        when(deletePolicyRecordMock)().afterReturn(Promise.resolve({
          success: true,
          message: 'ok'
        } as PermissionActionResult))
        when(loadAccountPolicySnapshotMock)().afterReturn(Promise.resolve({
          applications: [app],
          appSnapshots: [buildAppSnapshot(app, false)],
          installPolicies: [],
          policyRecords: []
        } as ApplicationInventoryResult))

        let result = await viewModel.deletePolicyRecord(viewModel.state.policyRecords[0].key)

        let selectedApp = viewModel.state.applications.find((item: ManagedApplicationInfo): boolean => item.key === app.key)
        expect(result.success).assertTrue()
        expect(selectedApp?.runningPolicy).assertEqual('default')
        expect(viewModel.state.policyRecords.length).assertEqual(0)
      } finally {
        mockKit.clearAll()
        done()
      }
    })
  })
}
