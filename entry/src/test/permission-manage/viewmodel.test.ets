import { describe, expect, it } from '@ohos/hypium'
import { ManagedApplicationInfo } from '../../main/ets/models/PermissionModels'
import {
  ApplicationInventoryRawRecord,
  ApplicationInventoryRepository
} from '../../main/ets/services/permission-manage/ApplicationInventoryRepository'
import { ApplicationControlRepository } from '../../main/ets/services/permission-manage/ApplicationControlRepository'
import { PermissionService } from '../../main/ets/services/permission-manage/PermissionService'
import { PermissionViewModel } from '../../main/ets/viewmodels/permission-manage/PermissionViewModel'
import { ApplicationNetworkPolicyRepository } from '../../main/ets/services/permission-manage/ApplicationNetworkPolicyRepository'

export default function permissionViewModelTest() {
  describe('PermissionViewModel', () => {
    it('should keep default read-only skeleton state before initialization', 0, () => {
      let viewModel = new PermissionViewModel()

      expect(viewModel.state.initialized).assertFalse()
      expect(viewModel.state.loading).assertFalse()
      expect(viewModel.state.summary.appCount).assertEqual(0)
      expect(viewModel.state.applications.length).assertEqual(0)
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
          networkPolicy: 'denied',
          keepAliveEnabled: true,
          autoStartEnabled: false
        } as ManagedApplicationInfo
      ]

      let summary = PermissionService.buildSummary(applications)

      expect(summary.appCount).assertEqual(1)
      expect(summary.managedCount).assertEqual(1)
      expect(summary.networkRestrictedCount).assertEqual(1)
      expect(summary.keepAliveCount).assertEqual(1)
    })

    it('should normalize manageable applications and skip system or self bundle', 0, () => {
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

      expect(applications.length).assertEqual(1)
      expect(applications[0].key).assertEqual('100:com.example.demo:demo-id:1')
      expect(applications[0].label).assertEqual('Demo')
      expect(applications[0].installPolicy).assertEqual('default')
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
        disallowedRunningIds: ['com.example.mail'],
        keepAliveBundleNames: ['com.example.mail'],
        autoStartBundleNames: ['com.example.browser']
      })

      let mail = merged.find((app: ManagedApplicationInfo): boolean => app.bundleName === 'com.example.mail')
      let browser = merged.find((app: ManagedApplicationInfo): boolean => app.bundleName === 'com.example.browser')

      expect(mail?.installPolicy).assertEqual('allowed')
      expect(mail?.uninstallProtected).assertTrue()
      expect(mail?.runningPolicy).assertEqual('denied')
      expect(mail?.keepAliveEnabled).assertTrue()
      expect(mail?.autoStartEnabled).assertFalse()
      expect(browser?.installPolicy).assertEqual('denied')
      expect(browser?.runningPolicy).assertEqual('allowed')
      expect(browser?.autoStartEnabled).assertTrue()
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

    it('should update filtered applications and selected app by search keyword', 0, () => {
      let viewModel = new PermissionViewModel()
      viewModel.state.applications = ApplicationInventoryRepository.normalizeApplications(100, [
        { bundleName: 'com.example.mail', label: 'Mail' } as ApplicationInventoryRawRecord,
        { bundleName: 'com.example.browser', label: 'Browser' } as ApplicationInventoryRawRecord
      ], 'com.huawei.securitytool')

      viewModel.setSearchKeyword('browser')

      expect(viewModel.state.filteredApplications.length).assertEqual(1)
      expect(viewModel.state.selectedAppKey).assertEqual('100:com.example.browser:com.example.browser:0')
    })
  })
}
