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
import { PermissionApplicationStrings } from '../../main/ets/constants/modules/PermissionStrings'

function buildPermissionAccount(accountId: number, isForeground: boolean = false): PermissionManagedAccount {
  return {
    accountId: accountId,
    displayName: `用户 ${accountId}`,
    isForeground: isForeground,
    isAvailable: true
  } as PermissionManagedAccount
}

function buildPermissionAccountListResult(accountId: number = 100): PermissionAccountListResult {
  return {
    accounts: [buildPermissionAccount(accountId, true)],
    selectedAccountId: accountId
  } as PermissionAccountListResult
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
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let loadInitialStateMock = mockKit.mockFunc(PermissionService, PermissionService.loadInitialState)
        when(loadInitialStateMock)().afterReturn(Promise.resolve({
          selectedAccountId: 100,
          selectedAppKey: '',
          inventoryMessage: '',
          accounts: [buildPermissionAccount(100, true)],
          appSnapshots: [],
          installPolicies: []
        } as PermissionInitialData))

        await viewModel.loadInitialState()

        expect(viewModel.state.initialized).assertTrue()
        expect(viewModel.state.loading).assertFalse()
        expect(viewModel.state.accounts.length).assertEqual(1)
        expect(viewModel.state.summary.appCount).assertEqual(0)
        expect(viewModel.state.summary.managedCount).assertEqual(0)
      } finally {
        mockKit.clearAll()
        done()
      }
    })

    it('should apply account install policies from initial state', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let loadInitialStateMock = mockKit.mockFunc(PermissionService, PermissionService.loadInitialState)
        when(loadInitialStateMock)().afterReturn(Promise.resolve({
          selectedAccountId: 100,
          selectedAppKey: '',
          inventoryMessage: '',
          accounts: [buildPermissionAccount(100, true)],
          appSnapshots: [],
          installPolicies: [{
            accountId: 100,
            policyId: 'com.example.future_app_id',
            policy: 'denied'
          } as AccountInstallPolicySnapshot]
        } as PermissionInitialData))

        await viewModel.loadInitialState()

        expect(viewModel.state.installPolicies.length).assertEqual(1)
        expect(viewModel.state.policyRecords.length).assertEqual(1)
        expect(viewModel.state.policyRecords[0].actionKind).assertEqual('install-deny')
      } finally {
        mockKit.clearAll()
        done()
      }
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

    it('should initialize permission state for account change before page initialization', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let app = buildManagedApplication(100, 'com.example.mail', 'Mail')
        let loadInitialStateMock = mockKit.mockFunc(PermissionService, PermissionService.loadInitialState)
        when(loadInitialStateMock)().afterReturn(Promise.resolve({
          selectedAccountId: 100,
          selectedAppKey: '',
          inventoryMessage: '',
          accounts: [buildPermissionAccount(100, true)],
          appSnapshots: [buildAppSnapshot(app)],
          installPolicies: []
        } as PermissionInitialData))

        let success = await viewModel.refreshForAccountChange()

        expect(success).assertTrue()
        expect(viewModel.state.initialized).assertTrue()
        expect(viewModel.state.selectedAccountId).assertEqual(100)
        expect(viewModel.state.appSnapshots.length).assertEqual(1)
      } finally {
        mockKit.clearAll()
        done()
      }
    })

    it('should refresh account state for account change without switching when current account remains', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let currentApp = buildManagedApplication(100, 'com.example.mail', 'Mail')
        viewModel.state.initialized = true
        viewModel.state.selectedAccountId = 100
        viewModel.state.accounts = [buildPermissionAccount(100, true)]
        viewModel.state.selectedAppKey = currentApp.appKey
        viewModel.state.appSnapshots = [buildAppSnapshot(currentApp)]
        viewModel.state.filteredAppKeys = [currentApp.appKey]
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
            appSnapshots: [buildAppSnapshot(currentApp)],
            installPolicies: []
          } as ApplicationInventoryResult)
        })

        let success = await viewModel.refreshForAccountChange()

        expect(success).assertTrue()
        expect(viewModel.state.selectedAccountId).assertEqual(100)
        expect(loadedAccountId).assertEqual(100)
        expect(viewModel.state.accounts.length).assertEqual(2)
        expect(viewModel.state.selectedAppKey).assertEqual(currentApp.appKey)
      } finally {
        mockKit.clearAll()
        done()
      }
    })

    it('should fallback and clear selected app when account change removes current account', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let removedApp = buildManagedApplication(100, 'com.example.mail', 'Mail')
        viewModel.state.initialized = true
        viewModel.state.selectedAccountId = 100
        viewModel.state.accounts = [buildPermissionAccount(100, true)]
        viewModel.state.selectedAppKey = removedApp.appKey
        viewModel.state.appSnapshots = [buildAppSnapshot(removedApp, true)]
        viewModel.state.policyRecords = PermissionService.buildPolicyRecordsFromState(viewModel.state.appSnapshots, [])
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

        let success = await viewModel.refreshForAccountChange()

        expect(success).assertTrue()
        expect(viewModel.state.selectedAccountId).assertEqual(101)
        expect(loadedAccountId).assertEqual(101)
        expect(viewModel.state.selectedAppKey).assertEqual('')
        expect(viewModel.state.policyRecords.length).assertEqual(0)
      } finally {
        mockKit.clearAll()
        done()
      }
    })

    it('should finish current-account refresh before processing an account change', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let app = buildManagedApplication(100, 'com.example.mail', 'Mail')
        viewModel.state.initialized = true
        viewModel.state.selectedAccountId = 100
        viewModel.state.accounts = [buildPermissionAccount(100, true)]
        let applicationLoadCount = 0
        let accountLoadCount = 0
        let resolveCurrentRefresh: (value: ApplicationInventoryResult) => void =
          (_value: ApplicationInventoryResult): void => {}
        let currentRefreshResult = new Promise<ApplicationInventoryResult>((resolve) => {
          resolveCurrentRefresh = resolve
        })
        let loadAccountsMock = mockKit.mockFunc(PermissionService, PermissionService.loadAccounts)
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        when(loadAccountsMock)().afterAction((): Promise<PermissionAccountListResult> => {
          accountLoadCount++
          return Promise.resolve(buildPermissionAccountListResult(100))
        })
        when(loadApplicationsMock)(ArgumentMatchers.any).afterAction((
          _accountId: number
        ): Promise<ApplicationInventoryResult> => {
          applicationLoadCount++
          if (applicationLoadCount === 1) {
            return currentRefreshResult
          }
          return Promise.resolve({
            appSnapshots: [buildAppSnapshot(app)],
            installPolicies: []
          } as ApplicationInventoryResult)
        })

        let pageRefresh = viewModel.refreshApplicationList()
        let accountRefresh = viewModel.refreshForAccountChange()

        expect(applicationLoadCount).assertEqual(1)
        expect(accountLoadCount).assertEqual(0)
        resolveCurrentRefresh({
          appSnapshots: [buildAppSnapshot(app)],
          installPolicies: []
        } as ApplicationInventoryResult)
        expect(await pageRefresh).assertTrue()
        expect(await accountRefresh).assertTrue()
        expect(applicationLoadCount).assertEqual(2)
        expect(accountLoadCount).assertEqual(1)
      } finally {
        mockKit.clearAll()
        done()
      }
    })

    it('should coalesce account events into one trailing refresh after an in-flight account refresh', 0,
      async (done: Function) => {
        let mockKit = new MockKit()
        try {
          let viewModel = new PermissionViewModel()
          let app = buildManagedApplication(100, 'com.example.mail', 'Mail')
          viewModel.state.initialized = true
          viewModel.state.selectedAccountId = 100
          viewModel.state.accounts = [buildPermissionAccount(100, true)]
          let accountLoadCount = 0
          let applicationLoadCount = 0
          let resolveFirstRefresh: (value: ApplicationInventoryResult) => void =
            (_value: ApplicationInventoryResult): void => {}
          let firstRefreshResult = new Promise<ApplicationInventoryResult>((resolve) => {
            resolveFirstRefresh = resolve
          })
          let loadAccountsMock = mockKit.mockFunc(PermissionService, PermissionService.loadAccounts)
          let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
          when(loadAccountsMock)().afterAction((): Promise<PermissionAccountListResult> => {
            accountLoadCount++
            return Promise.resolve(buildPermissionAccountListResult(100))
          })
          when(loadApplicationsMock)(ArgumentMatchers.any).afterAction((
            _accountId: number
          ): Promise<ApplicationInventoryResult> => {
            applicationLoadCount++
            if (applicationLoadCount === 1) {
              return firstRefreshResult
            }
            return Promise.resolve({
              appSnapshots: [buildAppSnapshot(app)],
              installPolicies: []
            } as ApplicationInventoryResult)
          })

          let firstAccountEvent = viewModel.refreshForAccountChange()
          await Promise.resolve()
          await Promise.resolve()
          await Promise.resolve()
          await Promise.resolve()
          expect(accountLoadCount).assertEqual(1)
          expect(applicationLoadCount).assertEqual(1)

          let secondAccountEvent = viewModel.refreshForAccountChange()
          let thirdAccountEvent = viewModel.refreshForAccountChange()
          resolveFirstRefresh({
            appSnapshots: [buildAppSnapshot(app)],
            installPolicies: []
          } as ApplicationInventoryResult)

          expect(await firstAccountEvent).assertTrue()
          expect(await secondAccountEvent).assertTrue()
          expect(await thirdAccountEvent).assertTrue()
          expect(accountLoadCount).assertEqual(2)
          expect(applicationLoadCount).assertEqual(2)
        } finally {
          mockKit.clearAll()
          done()
        }
      })

    it('should reuse an in-flight current-account refresh', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let app = buildManagedApplication(100, 'com.example.mail', 'Mail')
        viewModel.state.initialized = true
        viewModel.state.selectedAccountId = 100
        viewModel.state.accounts = [buildPermissionAccount(100, true)]
        let applicationLoadCount = 0
        let resolveRefresh: (value: ApplicationInventoryResult) => void =
          (_value: ApplicationInventoryResult): void => {}
        let refreshResult = new Promise<ApplicationInventoryResult>((resolve) => {
          resolveRefresh = resolve
        })
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        when(loadApplicationsMock)(ArgumentMatchers.any).afterAction((
          _accountId: number
        ): Promise<ApplicationInventoryResult> => {
          applicationLoadCount++
          return refreshResult
        })

        let firstRefresh = viewModel.refreshApplicationList()
        let secondRefresh = viewModel.refreshApplicationList()

        expect(applicationLoadCount).assertEqual(1)
        resolveRefresh({
          appSnapshots: [buildAppSnapshot(app)],
          installPolicies: []
        } as ApplicationInventoryResult)
        expect(await firstRefresh).assertTrue()
        expect(await secondRefresh).assertTrue()
        expect(applicationLoadCount).assertEqual(1)
      } finally {
        mockKit.clearAll()
        done()
      }
    })

    it('should preserve confirmed state when current-account refresh fails', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let app = buildManagedApplication(100, 'com.example.mail', 'Mail')
        let confirmedSnapshot = buildAppSnapshot(app, true, true, true)
        viewModel.state.initialized = true
        viewModel.state.selectedAccountId = 100
        viewModel.state.accounts = [buildPermissionAccount(100, true)]
        viewModel.state.selectedAppKey = app.appKey
        viewModel.state.appSnapshots = [confirmedSnapshot]
        viewModel.state.policyRecords = PermissionService.buildPolicyRecordsFromState(
          viewModel.state.appSnapshots,
          []
        )
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        when(loadApplicationsMock)(ArgumentMatchers.any).afterReturn(
          Promise.reject(new Error('taskpool snapshot failed'))
        )

        let success = await viewModel.refreshApplicationList()

        expect(success).assertFalse()
        expect(viewModel.state.loading).assertFalse()
        expect(viewModel.state.selectedAppKey).assertEqual(app.appKey)
        expect(viewModel.state.appSnapshots.length).assertEqual(1)
        expect(viewModel.state.appSnapshots[0].runningBlocked).assertTrue()
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

    it('should add newly installed application after manual inventory refresh', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let currentApp = buildManagedApplication(100, 'com.example.mail', 'Mail')
        let newApp = buildManagedApplication(100, 'com.example.browser', 'Browser')
        viewModel.state.initialized = true
        viewModel.state.selectedAccountId = 100
        viewModel.state.accounts = [buildPermissionAccount(100, true)]
        viewModel.state.selectedAppKey = currentApp.appKey
        viewModel.state.appSnapshots = [buildAppSnapshot(currentApp)]
        viewModel.state.filteredAppKeys = [currentApp.appKey]
        let loadAccountsMock = mockKit.mockFunc(PermissionService, PermissionService.loadAccounts)
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        when(loadAccountsMock)().afterReturn(Promise.resolve(buildPermissionAccountListResult(100)))
        when(loadApplicationsMock)(ArgumentMatchers.any).afterReturn(Promise.resolve({
          appSnapshots: [buildAppSnapshot(currentApp), buildAppSnapshot(newApp)],
          installPolicies: []
        } as ApplicationInventoryResult))

        let success = await viewModel.refreshAccountsAndApplicationList()

        expect(success).assertTrue()
        expect(viewModel.state.selectedAccountId).assertEqual(100)
        expect(viewModel.state.selectedAppKey).assertEqual(currentApp.appKey)
        expect(viewModel.state.appSnapshots.length).assertEqual(2)
        expect(viewModel.state.filteredAppKeys.includes(newApp.appKey)).assertTrue()
      } finally {
        mockKit.clearAll()
        done()
      }
    })

    it('should clear selected application after manual refresh when target is uninstalled', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let currentApp = buildManagedApplication(100, 'com.example.mail', 'Mail')
        let otherApp = buildManagedApplication(100, 'com.example.browser', 'Browser')
        viewModel.state.initialized = true
        viewModel.state.selectedAccountId = 100
        viewModel.state.accounts = [buildPermissionAccount(100, true)]
        viewModel.state.selectedAppKey = currentApp.appKey
        viewModel.state.appSnapshots = [buildAppSnapshot(currentApp, true)]
        viewModel.state.policyRecords = PermissionService.buildPolicyRecordsFromState(viewModel.state.appSnapshots, [])
        let loadAccountsMock = mockKit.mockFunc(PermissionService, PermissionService.loadAccounts)
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        when(loadAccountsMock)().afterReturn(Promise.resolve(buildPermissionAccountListResult(100)))
        when(loadApplicationsMock)(ArgumentMatchers.any).afterReturn(Promise.resolve({
          appSnapshots: [buildAppSnapshot(otherApp)],
          installPolicies: []
        } as ApplicationInventoryResult))

        let success = await viewModel.refreshAccountsAndApplicationList()

        expect(success).assertTrue()
        expect(viewModel.state.selectedAppKey).assertEqual('')
        expect(viewModel.state.appSnapshots.length).assertEqual(1)
        expect(viewModel.state.appSnapshots[0].appKey).assertEqual(otherApp.appKey)
        expect(viewModel.state.policyRecords.length).assertEqual(0)
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

    it('should accept explicit app id as install block target', 0, () => {
      let policyId = PermissionService.normalizeInstallBlockPolicyId(' com.example.future_app_id_signature ')

      expect(policyId).assertEqual('com.example.future_app_id_signature')
    })

    it('should accept explicit app identifier as install block target', 0, () => {
      let policyId = PermissionService.normalizeInstallBlockPolicyId(' 6917606289429086981 ')

      expect(policyId).assertEqual('6917606289429086981')
    })

    it('should reject bundle name install block target', 0, () => {
      let failed = false
      try {
        PermissionService.normalizeInstallBlockPolicyId('com.example.future')
      } catch (err) {
        failed = true
      }

      expect(failed).assertTrue()
    })

    it('should reject display name install block target', 0, () => {
      let failed = false
      try {
        PermissionService.normalizeInstallBlockPolicyId('Mail')
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

    it('should only load selected app 3D details when target application changes', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let app = buildManagedApplication(100, 'com.example.label', 'Label')
        let profileCalls = 0
        let accountSnapshotCalls = 0
        let loadPermissionProfileMock = mockKit.mockFunc(PermissionService, PermissionService.loadPermissionProfile)
        let loadAccountPolicySnapshotMock = mockKit.mockFunc(
          PermissionService,
          PermissionService.loadAndReconcileAccountPolicySnapshot
        )
        when(loadPermissionProfileMock)(ArgumentMatchers.any).afterAction((
          snapshot: PermissionAppSnapshot
        ): Promise<ApplicationPermissionProfile> => {
          profileCalls++
          let profile = buildEmptyPermissionProfile(snapshot)
          profile.threeDGroups = [{
            groupKey: 'downloads',
            title: 'Downloads',
            permissionNames: ['ohos.permission.READ_WRITE_DOWNLOAD_DIRECTORY'],
            declaredPermissions: ['ohos.permission.READ_WRITE_DOWNLOAD_DIRECTORY'],
            managedState: 'denied',
            canManage: true,
            disabledReason: ''
          } as ThreeDPermissionItem]
          return Promise.resolve(profile)
        })
        when(loadAccountPolicySnapshotMock)(ArgumentMatchers.any).afterAction((
          _accountId: number,
          snapshots: PermissionAppSnapshot[]
        ): Promise<ApplicationInventoryResult> => {
          accountSnapshotCalls++
          return Promise.resolve({
            appSnapshots: snapshots,
            installPolicies: []
          } as ApplicationInventoryResult)
        })

        viewModel.state.selectedAccountId = 100
        viewModel.state.appSnapshots = [buildAppSnapshot(app, true, true, true)]
        viewModel.state.installPolicies = [{
          accountId: 100,
          policyId: 'com.example.future_app_id',
          policy: 'denied'
        } as AccountInstallPolicySnapshot]

        let result = await viewModel.selectApplicationAndLoadDetails(app.appKey)
        let selectedApp = viewModel.state.appSnapshots.find((item: PermissionAppSnapshot): boolean =>
          item.appKey === app.appKey
        )
        let downloadsGroup = selectedApp?.threeDGroups.find((item: ThreeDPermissionItem): boolean =>
          item.groupKey === 'downloads'
        )

        expect(result).assertTrue()
        expect(profileCalls).assertEqual(1)
        expect(accountSnapshotCalls).assertEqual(0)
        expect(selectedApp?.uninstallProtected).assertTrue()
        expect(selectedApp?.runningBlocked).assertTrue()
        expect(selectedApp?.networkBlocked).assertTrue()
        expect(viewModel.state.installPolicies.length).assertEqual(1)
        expect(downloadsGroup?.managedState).assertEqual('denied')
      } finally {
        mockKit.clearAll()
        done()
      }
    })

    it('should refresh selected application state after a successful running policy write', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let app = buildManagedApplication(100, 'com.example.label', 'Label')
        let loadAccountsMock = mockKit.mockFunc(PermissionService, PermissionService.loadAccounts)
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        let setRunningPolicyMock = mockKit.mockFunc(PermissionService, PermissionService.setRunningBlocked)
        let loadAccountPolicySnapshotMock = mockKit.mockFunc(
          PermissionService,
          PermissionService.loadAndReconcileAccountPolicySnapshot
        )
        when(loadAccountsMock)().afterReturn(Promise.resolve(buildPermissionAccountListResult(100)))
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
        let loadAccountsMock = mockKit.mockFunc(PermissionService, PermissionService.loadAccounts)
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        let setUninstallPolicyMock = mockKit.mockFunc(PermissionService, PermissionService.setUninstallProtected)
        let setNetworkPolicyMock = mockKit.mockFunc(PermissionService, PermissionService.setNetworkBlocked)
        when(loadAccountsMock)().afterReturn(Promise.resolve(buildPermissionAccountListResult(100)))
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

    it('should apply account policy snapshot while keeping loaded 3D detail', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let app = buildManagedApplication(100, 'com.example.label', 'Label')
        let previousSnapshot = buildAppSnapshot(app, true, true, true)
        previousSnapshot.threeDLoadState = 'loaded'
        previousSnapshot.threeDGroups = [{
          groupKey: 'downloads',
          title: 'Downloads',
          permissionNames: ['ohos.permission.READ_WRITE_DOWNLOAD_DIRECTORY'],
          declaredPermissions: ['ohos.permission.READ_WRITE_DOWNLOAD_DIRECTORY'],
          managedState: 'denied',
          canManage: true,
          disabledReason: ''
        } as ThreeDPermissionItem]
        previousSnapshot.threeDPolicies = [{
          recordId: `three-d:${app.appKey}:downloads`,
          appKey: app.appKey,
          groupKey: 'downloads',
          actionKind: 'three-d',
          policyValue: 'denied',
          policyType: 'Downloads',
          targetName: 'Label',
          targetDetail: 'com.example.label / Downloads',
          statusLabel: 'denied',
          scopeLabel: 'account 100'
        } as PermissionThreeDPolicySnapshot]
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        when(loadApplicationsMock)(ArgumentMatchers.any).afterReturn(Promise.resolve({
          appSnapshots: [buildAppSnapshot(app, false, false, false)],
          installPolicies: [{
            accountId: 100,
            policyId: 'com.example.future_app_id',
            policy: 'denied'
          } as AccountInstallPolicySnapshot]
        } as ApplicationInventoryResult))

        viewModel.state.selectedAccountId = 100
        viewModel.state.selectedAppKey = app.appKey
        viewModel.state.appSnapshots = [previousSnapshot]
        viewModel.state.installPolicies = []

        let success = await viewModel.refreshApplicationList()

        let selectedApp = viewModel.state.appSnapshots.find((item: PermissionAppSnapshot): boolean => item.appKey === app.appKey)
        expect(success).assertTrue()
        expect(selectedApp?.uninstallProtected).assertFalse()
        expect(selectedApp?.runningBlocked).assertFalse()
        expect(selectedApp?.networkBlocked).assertFalse()
        expect(selectedApp?.threeDLoadState).assertEqual('loaded')
        expect(viewModel.state.installPolicies.length).assertEqual(1)
        expect(viewModel.state.policyRecords.length).assertEqual(2)
      } finally {
        mockKit.clearAll()
        done()
      }
    })

    it('should drop loaded 3D detail when app identity changes on refresh', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let app = buildManagedApplication(100, 'com.example.label', 'Label')
        let previousSnapshot = buildAppSnapshot(app, false, false, false)
        previousSnapshot.threeDLoadState = 'loaded'
        previousSnapshot.threeDGroups = [{
          groupKey: 'downloads',
          title: 'Downloads',
          permissionNames: ['ohos.permission.READ_WRITE_DOWNLOAD_DIRECTORY'],
          declaredPermissions: ['ohos.permission.READ_WRITE_DOWNLOAD_DIRECTORY'],
          managedState: 'denied',
          canManage: true,
          disabledReason: ''
        } as ThreeDPermissionItem]
        previousSnapshot.threeDPolicies = [{
          recordId: `three-d:${app.appKey}:downloads`,
          appKey: app.appKey,
          groupKey: 'downloads',
          actionKind: 'three-d',
          policyValue: 'denied',
          policyType: 'Downloads',
          targetName: 'Label',
          targetDetail: 'com.example.label / Downloads',
          statusLabel: 'denied',
          scopeLabel: 'account 100'
        } as PermissionThreeDPolicySnapshot]
        let refreshedSnapshot = buildAppSnapshot(app, false, false, false)
        refreshedSnapshot.appIdentifier = `${app.appIdentifier}.new`
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        when(loadApplicationsMock)(ArgumentMatchers.any).afterReturn(Promise.resolve({
          appSnapshots: [refreshedSnapshot],
          installPolicies: []
        } as ApplicationInventoryResult))

        viewModel.state.selectedAccountId = 100
        viewModel.state.selectedAppKey = app.appKey
        viewModel.state.appSnapshots = [previousSnapshot]
        viewModel.state.installPolicies = []

        let success = await viewModel.refreshApplicationList()

        let selectedApp = viewModel.state.appSnapshots.find((item: PermissionAppSnapshot): boolean => item.appKey === app.appKey)
        expect(success).assertTrue()
        expect(viewModel.state.selectedAppKey).assertEqual('')
        expect(selectedApp?.appIdentifier).assertEqual(refreshedSnapshot.appIdentifier)
        expect(selectedApp?.threeDLoadState).assertEqual('idle')
        expect(selectedApp?.threeDGroups.length).assertEqual(0)
        expect(viewModel.state.policyRecords.length).assertEqual(0)
      } finally {
        mockKit.clearAll()
        done()
      }
    })

    it('should de-duplicate install deny policy by account and app identity', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let policyId = 'com.example.future_app_id'
        let loadAccountsMock = mockKit.mockFunc(PermissionService, PermissionService.loadAccounts)
        let setInstallPolicyMock = mockKit.mockFunc(PermissionService, PermissionService.setDisallowedInstallPolicyId)
        when(loadAccountsMock)().afterReturn(Promise.resolve(buildPermissionAccountListResult(100)))
        when(setInstallPolicyMock)(ArgumentMatchers.any).afterReturn(Promise.resolve({
          success: true,
          message: 'ok'
        } as PermissionActionResult))

        viewModel.state.selectedAccountId = 100
        viewModel.state.appSnapshots = []
        viewModel.state.installBlockKeyword = policyId
        viewModel.state.installPolicies = [
          {
            accountId: 100,
            policyId: policyId,
            policy: 'denied'
          } as AccountInstallPolicySnapshot,
          {
            accountId: 100,
            policyId: 'com.example.other',
            policy: 'denied'
          } as AccountInstallPolicySnapshot,
          {
            accountId: 101,
            policyId: policyId,
            policy: 'denied'
          } as AccountInstallPolicySnapshot
        ]

        let result = await viewModel.setDisallowedInstallByKeyword()
        let currentAccountMatches = viewModel.state.installPolicies.filter((policy: AccountInstallPolicySnapshot): boolean =>
          policy.accountId === 100 && policy.policyId === policyId
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
        let loadAccountsMock = mockKit.mockFunc(PermissionService, PermissionService.loadAccounts)
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        let deletePolicyRecordMock = mockKit.mockFunc(PermissionService, PermissionService.deletePolicyRecord)
        let loadAccountPolicySnapshotMock = mockKit.mockFunc(
          PermissionService,
          PermissionService.loadAndReconcileAccountPolicySnapshot
        )
        when(loadAccountsMock)().afterReturn(Promise.resolve(buildPermissionAccountListResult(100)))
        when(loadApplicationsMock)(ArgumentMatchers.any).afterReturn(Promise.resolve({
          appSnapshots: applications,
          installPolicies: []
        } as ApplicationInventoryResult))
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
        let loadAccountsMock = mockKit.mockFunc(PermissionService, PermissionService.loadAccounts)
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        let deletePolicyRecordMock = mockKit.mockFunc(PermissionService, PermissionService.deletePolicyRecord)
        when(loadAccountsMock)().afterReturn(Promise.resolve(buildPermissionAccountListResult(100)))
        when(loadApplicationsMock)(ArgumentMatchers.any).afterReturn(Promise.resolve({
          appSnapshots: applications,
          installPolicies: []
        } as ApplicationInventoryResult))
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
        let loadAccountsMock = mockKit.mockFunc(PermissionService, PermissionService.loadAccounts)
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        let setRunningPolicyMock = mockKit.mockFunc(PermissionService, PermissionService.setRunningBlocked)
        when(loadAccountsMock)().afterReturn(Promise.resolve(buildPermissionAccountListResult(100)))
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
        let loadAccountsMock = mockKit.mockFunc(PermissionService, PermissionService.loadAccounts)
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        let setNetworkPolicyMock = mockKit.mockFunc(PermissionService, PermissionService.setNetworkBlocked)
        when(loadAccountsMock)().afterReturn(Promise.resolve(buildPermissionAccountListResult(100)))
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

    it('should reject app policy write when selected application disappears before action', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let app = buildManagedApplication(100, 'com.example.label', 'Label')
        viewModel.state.selectedAccountId = 100
        viewModel.state.accounts = [buildPermissionAccount(100, true)]
        viewModel.state.selectedAppKey = app.appKey
        viewModel.state.appSnapshots = [buildAppSnapshot(app)]
        viewModel.state.policyRecords = PermissionService.buildPolicyRecordsFromState(viewModel.state.appSnapshots, [])
        let loadAccountsMock = mockKit.mockFunc(PermissionService, PermissionService.loadAccounts)
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        let setRunningPolicyMock = mockKit.mockFunc(PermissionService, PermissionService.setRunningBlocked)
        when(loadAccountsMock)().afterReturn(Promise.resolve(buildPermissionAccountListResult(100)))
        when(loadApplicationsMock)(ArgumentMatchers.any).afterReturn(Promise.resolve({
          appSnapshots: [],
          installPolicies: []
        } as ApplicationInventoryResult))
        when(setRunningPolicyMock)().afterReturn(Promise.resolve({
          success: true,
          message: 'unexpected'
        } as PermissionActionResult))

        let result = await viewModel.setSelectedRunningPolicy('denied')

        expect(result.success).assertFalse()
        expect(result.message).assertEqual(PermissionApplicationStrings.APPLICATION_CONTEXT_CHANGED)
        expect(viewModel.state.selectedAppKey).assertEqual('')
        expect(viewModel.state.appSnapshots.length).assertEqual(0)
        expect(viewModel.state.policyRecords.length).assertEqual(0)
      } finally {
        mockKit.clearAll()
        done()
      }
    })

    it('should reject app policy write when selected application identity changes before action', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let app = buildManagedApplication(100, 'com.example.label', 'Label')
        let refreshedSnapshot = buildAppSnapshot(app)
        refreshedSnapshot.appIdentifier = `${app.appIdentifier}.new`
        viewModel.state.selectedAccountId = 100
        viewModel.state.accounts = [buildPermissionAccount(100, true)]
        viewModel.state.selectedAppKey = app.appKey
        viewModel.state.appSnapshots = [buildAppSnapshot(app)]
        let loadAccountsMock = mockKit.mockFunc(PermissionService, PermissionService.loadAccounts)
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        let setRunningPolicyMock = mockKit.mockFunc(PermissionService, PermissionService.setRunningBlocked)
        when(loadAccountsMock)().afterReturn(Promise.resolve(buildPermissionAccountListResult(100)))
        when(loadApplicationsMock)(ArgumentMatchers.any).afterReturn(Promise.resolve({
          appSnapshots: [refreshedSnapshot],
          installPolicies: []
        } as ApplicationInventoryResult))
        when(setRunningPolicyMock)().afterReturn(Promise.resolve({
          success: true,
          message: 'unexpected'
        } as PermissionActionResult))

        let result = await viewModel.setSelectedRunningPolicy('denied')

        expect(result.success).assertFalse()
        expect(result.message).assertEqual(PermissionApplicationStrings.APPLICATION_CONTEXT_CHANGED)
        expect(viewModel.state.selectedAppKey).assertEqual('')
        expect(viewModel.state.appSnapshots[0].appIdentifier).assertEqual(refreshedSnapshot.appIdentifier)
        expect(viewModel.state.policyRecords.length).assertEqual(0)
      } finally {
        mockKit.clearAll()
        done()
      }
    })

    it('should reject account policy write when current account disappears before action', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let app = buildManagedApplication(100, 'com.example.label', 'Label')
        let fallbackApp = buildManagedApplication(101, 'com.example.browser', 'Browser')
        let policyId = 'com.example.future_app_id'
        viewModel.state.selectedAccountId = 100
        viewModel.state.accounts = [buildPermissionAccount(100, true)]
        viewModel.state.selectedAppKey = app.appKey
        viewModel.state.appSnapshots = [buildAppSnapshot(app)]
        viewModel.state.installBlockKeyword = policyId
        let loadAccountsMock = mockKit.mockFunc(PermissionService, PermissionService.loadAccounts)
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        let setInstallPolicyMock = mockKit.mockFunc(PermissionService, PermissionService.setDisallowedInstallPolicyId)
        when(loadAccountsMock)().afterReturn(Promise.resolve({
          accounts: [buildPermissionAccount(101, true)],
          selectedAccountId: 101
        } as PermissionAccountListResult))
        when(loadApplicationsMock)(ArgumentMatchers.any).afterReturn(Promise.resolve({
          appSnapshots: [buildAppSnapshot(fallbackApp)],
          installPolicies: []
        } as ApplicationInventoryResult))
        when(setInstallPolicyMock)(ArgumentMatchers.any).afterReturn(Promise.resolve({
          success: true,
          message: 'unexpected'
        } as PermissionActionResult))

        let result = await viewModel.setDisallowedInstallByKeyword()

        expect(result.success).assertFalse()
        expect(result.message).assertEqual(PermissionApplicationStrings.ACCOUNT_CONTEXT_CHANGED)
        expect(viewModel.state.selectedAccountId).assertEqual(101)
        expect(viewModel.state.selectedAppKey).assertEqual('')
        expect(viewModel.state.appSnapshots[0].accountId).assertEqual(101)
        expect(viewModel.state.installPolicies.length).assertEqual(0)
        expect(viewModel.state.installBlockKeyword).assertEqual(policyId)
      } finally {
        mockKit.clearAll()
        done()
      }
    })

    it('should reject policy deletion when refreshed policy record disappears', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let app = buildManagedApplication(100, 'com.example.label', 'Label')
        viewModel.state.selectedAccountId = 100
        viewModel.state.accounts = [buildPermissionAccount(100, true)]
        viewModel.state.selectedAppKey = app.appKey
        let applications: PermissionAppSnapshot[] = [buildAppSnapshot(app, false, true)]
        viewModel.state.appSnapshots = applications
        viewModel.state.policyRecords = PermissionService.buildPolicyRecordsFromState(applications, [])
        let networkRecord = viewModel.state.policyRecords.find((r: PermissionPolicyRecord): boolean =>
          r.actionKind === 'network'
        )
        let loadAccountsMock = mockKit.mockFunc(PermissionService, PermissionService.loadAccounts)
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        let deletePolicyRecordMock = mockKit.mockFunc(PermissionService, PermissionService.deletePolicyRecord)
        when(loadAccountsMock)().afterReturn(Promise.resolve(buildPermissionAccountListResult(100)))
        when(loadApplicationsMock)(ArgumentMatchers.any).afterReturn(Promise.resolve({
          appSnapshots: [buildAppSnapshot(app, false, false)],
          installPolicies: []
        } as ApplicationInventoryResult))
        when(deletePolicyRecordMock)().afterReturn(Promise.resolve({
          success: true,
          message: 'unexpected'
        } as PermissionActionResult))

        let result = await viewModel.deletePolicyRecord(networkRecord!.key)

        let selectedApp = viewModel.state.appSnapshots.find((item: PermissionAppSnapshot): boolean =>
          item.appKey === app.appKey
        )
        expect(result.success).assertFalse()
        expect(result.message).assertEqual(PermissionApplicationStrings.POLICY_CONTEXT_CHANGED)
        expect(selectedApp?.networkBlocked).assertFalse()
        expect(viewModel.state.policyRecords.length).assertEqual(0)
      } finally {
        mockKit.clearAll()
        done()
      }
    })

    it('should reject policy deletion when target application identity changes before action', 0, async (done: Function) => {
      let mockKit = new MockKit()
      try {
        let viewModel = new PermissionViewModel()
        let app = buildManagedApplication(100, 'com.example.label', 'Label')
        let refreshedSnapshot = buildAppSnapshot(app, true, false)
        refreshedSnapshot.appIdentifier = `${app.appIdentifier}.new`
        viewModel.state.selectedAccountId = 100
        viewModel.state.accounts = [buildPermissionAccount(100, true)]
        viewModel.state.selectedAppKey = app.appKey
        let applications: PermissionAppSnapshot[] = [buildAppSnapshot(app, true, false)]
        viewModel.state.appSnapshots = applications
        viewModel.state.policyRecords = PermissionService.buildPolicyRecordsFromState(applications, [])
        let runningRecord = viewModel.state.policyRecords.find((r: PermissionPolicyRecord): boolean =>
          r.actionKind === 'running'
        )
        let loadAccountsMock = mockKit.mockFunc(PermissionService, PermissionService.loadAccounts)
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        let deletePolicyRecordMock = mockKit.mockFunc(PermissionService, PermissionService.deletePolicyRecord)
        when(loadAccountsMock)().afterReturn(Promise.resolve(buildPermissionAccountListResult(100)))
        when(loadApplicationsMock)(ArgumentMatchers.any).afterReturn(Promise.resolve({
          appSnapshots: [refreshedSnapshot],
          installPolicies: []
        } as ApplicationInventoryResult))
        when(deletePolicyRecordMock)().afterReturn(Promise.resolve({
          success: true,
          message: 'unexpected'
        } as PermissionActionResult))

        let result = await viewModel.deletePolicyRecord(runningRecord!.key)

        expect(result.success).assertFalse()
        expect(result.message).assertEqual(PermissionApplicationStrings.POLICY_CONTEXT_CHANGED)
        expect(viewModel.state.selectedAppKey).assertEqual('')
        expect(viewModel.state.appSnapshots[0].appIdentifier).assertEqual(refreshedSnapshot.appIdentifier)
        expect(viewModel.state.policyRecords.length).assertEqual(1)
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
        let loadAccountsMock = mockKit.mockFunc(PermissionService, PermissionService.loadAccounts)
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        let deletePolicyRecordMock = mockKit.mockFunc(PermissionService, PermissionService.deletePolicyRecord)
        when(loadAccountsMock)().afterReturn(Promise.resolve(buildPermissionAccountListResult(100)))
        when(loadApplicationsMock)(ArgumentMatchers.any).afterReturn(Promise.resolve({
          appSnapshots: applications,
          installPolicies: []
        } as ApplicationInventoryResult))
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
        let loadAccountsMock = mockKit.mockFunc(PermissionService, PermissionService.loadAccounts)
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        let setThreeDStateMock = mockKit.mockFunc(PermissionService, PermissionService.setThreeDState)
        when(loadAccountsMock)().afterReturn(Promise.resolve(buildPermissionAccountListResult(100)))
        when(loadApplicationsMock)(ArgumentMatchers.any).afterReturn(Promise.resolve({
          appSnapshots: [snapshot],
          installPolicies: []
        } as ApplicationInventoryResult))
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
        let loadAccountsMock = mockKit.mockFunc(PermissionService, PermissionService.loadAccounts)
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        let setThreeDStateMock = mockKit.mockFunc(PermissionService, PermissionService.setThreeDState)
        when(loadAccountsMock)().afterReturn(Promise.resolve(buildPermissionAccountListResult(100)))
        when(loadApplicationsMock)(ArgumentMatchers.any).afterReturn(Promise.resolve({
          appSnapshots: [snapshot],
          installPolicies: []
        } as ApplicationInventoryResult))
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

        let result = await PermissionService.loadAndReconcileAccountPolicySnapshot(100, [snapshot])
        let records = PermissionService.buildPolicyRecordsFromState(result.appSnapshots, result.installPolicies)

        expect(records.filter((r: PermissionPolicyRecord): boolean => r.actionKind === 'three-d').length).assertEqual(0)
        expect(records.some((r: PermissionPolicyRecord): boolean => r.appKey === '100:com.example.missing')).assertFalse()
        expect(PermissionPolicyLocalRepository.listActiveByAccount(100).length).assertEqual(0)
      } finally {
        mockKit.clearAll()
        PermissionPolicyLocalRepository.resetForTest()
        done()
      }
    })

    it('should remove stale local 3D records when app identity changes', 0, async (done: Function) => {
      let mockKit = new MockKit()
      PermissionPolicyLocalRepository.resetForTest()
      try {
        let app = buildManagedApplication(100, 'com.example.mail', 'Mail')
        let snapshot = buildAppSnapshot(app)
        await PermissionPolicyLocalRepository.upsertActive({
          recordId: `three-d:${app.appKey}:downloads`,
          accountId: 100,
          appKey: app.appKey,
          bundleName: app.bundleName,
          appIdentifier: `${app.appIdentifier}.old`,
          appIndex: app.appIndex,
          policyType: 'Downloads',
          policyValue: 'denied',
          targetName: app.label,
          targetDetail: `${app.bundleName} / Downloads`,
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

        let result = await PermissionService.loadAndReconcileAccountPolicySnapshot(100, [snapshot])
        let records = PermissionService.buildPolicyRecordsFromState(result.appSnapshots, result.installPolicies)

        expect(records.filter((r: PermissionPolicyRecord): boolean => r.actionKind === 'three-d').length).assertEqual(0)
        expect(PermissionPolicyLocalRepository.listActiveByAccount(100).length).assertEqual(0)
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
        let loadAccountsMock = mockKit.mockFunc(PermissionService, PermissionService.loadAccounts)
        let loadApplicationsMock = mockKit.mockFunc(PermissionService, PermissionService.loadApplications)
        let setRunningPolicyMock = mockKit.mockFunc(PermissionService, PermissionService.setRunningBlocked)
        when(loadAccountsMock)().afterReturn(Promise.resolve(buildPermissionAccountListResult(100)))
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
