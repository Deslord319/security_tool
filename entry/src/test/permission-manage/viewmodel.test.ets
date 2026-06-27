import { describe, expect, it } from '@ohos/hypium'
import { ManagedApplicationInfo, PermissionLocalPolicyRecord, PermissionPolicyRecord } from '../../main/ets/models/PermissionModels'
import {
  ApplicationInventoryRawRecord,
  ApplicationInventoryRepository
} from '../../main/ets/services/permission-manage/ApplicationInventoryRepository'
import { ApplicationControlRepository } from '../../main/ets/services/permission-manage/ApplicationControlRepository'
import { PermissionService } from '../../main/ets/services/permission-manage/PermissionService'
import { PermissionViewModel } from '../../main/ets/viewmodels/permission-manage/PermissionViewModel'
import { ApplicationNetworkPolicyRepository } from '../../main/ets/services/permission-manage/ApplicationNetworkPolicyRepository'
import { PermissionPolicyLocalRepository } from '../../main/ets/services/permission-manage/PermissionPolicyLocalRepository'

export default function permissionViewModelTest() {
  describe('PermissionViewModel', () => {
    it('should keep default read-only skeleton state before initialization', 0, () => {
      let viewModel = new PermissionViewModel()

      expect(viewModel.state.initialized).assertFalse()
      expect(viewModel.state.loading).assertFalse()
      expect(viewModel.state.summary.appCount).assertEqual(0)
      expect(viewModel.state.applications.length).assertEqual(0)
      expect(viewModel.state.selectedApplication).assertNull()
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
      expect(demo?.key).assertEqual('100:com.example.demo:demo-id:1')
      expect(demo?.label).assertEqual('Demo')
      expect(demo?.installPolicy).assertEqual('default')
      expect(nonRemovable?.key).assertEqual('100:com.example.nonremovable:com.example.nonremovable:0')
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
      expect(first?.key).assertEqual('100:com.example.first:com.example.first:0')
      expect(second?.key).assertEqual('100:com.example.second:com.example.second:0')
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

      let merged = ApplicationControlRepository.mergeControlStates(applications, {
        allowedInstallIds: ['mail-id'],
        disallowedInstallIds: ['com.example.browser'],
        disallowedUninstallIds: ['mail-id'],
        allowedRunningIds: ['browser-id'],
        disallowedRunningIds: ['com.example.mail']
      })

      let mail = merged.find((app: ManagedApplicationInfo): boolean => app.bundleName === 'com.example.mail')
      let browser = merged.find((app: ManagedApplicationInfo): boolean => app.bundleName === 'com.example.browser')

      expect(mail?.installPolicy).assertEqual('allowed')
      expect(mail?.uninstallProtected).assertTrue()
      expect(mail?.runningPolicy).assertEqual('denied')
      expect(browser?.installPolicy).assertEqual('denied')
      expect(browser?.runningPolicy).assertEqual('allowed')
    })

    it('should clean both bundle name and app identifier when resetting running policy', 0, () => {
      let app = ApplicationInventoryRepository.normalizeApplications(100, [
        {
          bundleName: 'com.example.mail',
          label: 'Mail',
          appIdentifier: 'mail-id',
          systemApp: false
        } as ApplicationInventoryRawRecord
      ], 'com.huawei.securitytool')[0]

      let cleanupIds = ApplicationControlRepository.buildRunningPolicyCleanupIdsForTest(app)

      expect(cleanupIds.length).assertEqual(2)
      expect(cleanupIds.includes('com.example.mail')).assertTrue()
      expect(cleanupIds.includes('mail-id')).assertTrue()
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

      let merged = ApplicationNetworkPolicyRepository.mergeNetworkStates(applications, ['10002'])
      let mail = merged.find((app: ManagedApplicationInfo): boolean => app.bundleName === 'com.example.mail')
      let browser = merged.find((app: ManagedApplicationInfo): boolean => app.bundleName === 'com.example.browser')

      expect(mail?.networkPolicy).assertEqual('default')
      expect(browser?.networkPolicy).assertEqual('denied')
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
        recordId: 'sixd:100:mail:downloads',
        accountId: 100,
        appKey: '100:mail:mail:0',
        bundleName: 'mail',
        appIdentifier: 'mail',
        appIndex: 0,
        policyType: 'Downloads',
        policyValue: 'denied',
        targetName: 'Mail',
        targetDetail: 'mail / Downloads',
        statusLabel: 'denied',
        scopeLabel: 'account 100',
        actionKind: 'sixd',
        policyId: 'downloads',
        status: 'active',
        createdAt: 1,
        updatedAt: 1,
        lastError: ''
      } as PermissionLocalPolicyRecord)
      await PermissionPolicyLocalRepository.upsertActive({
        recordId: 'sixd:101:mail:downloads',
        accountId: 101,
        appKey: '101:mail:mail:0',
        bundleName: 'mail',
        appIdentifier: 'mail',
        appIndex: 0,
        policyType: 'Downloads',
        policyValue: 'denied',
        targetName: 'Mail',
        targetDetail: 'mail / Downloads',
        statusLabel: 'denied',
        scopeLabel: 'account 101',
        actionKind: 'sixd',
        policyId: 'downloads',
        status: 'active',
        createdAt: 1,
        updatedAt: 1,
        lastError: ''
      } as PermissionLocalPolicyRecord)

      expect(PermissionPolicyLocalRepository.listActiveByAccount(100).length).assertEqual(1)
      await PermissionPolicyLocalRepository.remove('sixd:100:mail:downloads')
      expect(PermissionPolicyLocalRepository.listActiveByAccount(100).length).assertEqual(0)
      expect(PermissionPolicyLocalRepository.listActiveByAccount(101).length).assertEqual(1)
      PermissionPolicyLocalRepository.resetForTest()
      done()
    })

    it('should only merge local 6D records into current policy records', 0, () => {
      let systemRecords: PermissionPolicyRecord[] = []
      let localRecords: PermissionLocalPolicyRecord[] = [
        {
          recordId: 'running:100:mail',
          accountId: 100,
          appKey: '100:mail:mail:0',
          bundleName: 'mail',
          appIdentifier: 'mail',
          appIndex: 0,
          policyType: 'running',
          policyValue: 'denied',
          targetName: 'Mail',
          targetDetail: 'mail',
          statusLabel: 'denied',
          scopeLabel: 'account 100',
          actionKind: 'running',
          policyId: '',
          status: 'active',
          createdAt: 1,
          updatedAt: 1,
          lastError: ''
        } as PermissionLocalPolicyRecord,
        {
          recordId: 'sixd:100:mail:downloads',
          accountId: 100,
          appKey: '100:mail:mail:0',
          bundleName: 'mail',
          appIdentifier: 'mail',
          appIndex: 0,
          policyType: 'Downloads',
          policyValue: 'denied',
          targetName: 'Mail',
          targetDetail: 'mail / Downloads',
          statusLabel: 'denied',
          scopeLabel: 'account 100',
          actionKind: 'sixd',
          policyId: 'downloads',
          status: 'active',
          createdAt: 1,
          updatedAt: 1,
          lastError: ''
        } as PermissionLocalPolicyRecord
      ]

      let merged = PermissionService.mergePolicyRecordsForTest(systemRecords, localRecords)

      expect(merged.length).assertEqual(1)
      expect(merged[0].key).assertEqual('sixd:100:mail:downloads')
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

      expect(viewModel.state.selectedApplication?.bundleName).assertEqual('com.example.second')
      expect(viewModel.state.selectedApplication?.label).assertEqual('Label')
    })
  })
}
