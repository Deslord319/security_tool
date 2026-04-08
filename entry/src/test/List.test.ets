import localUnitTest from './common/LocalUnit.test'
import secureStorageTest from './common/secure-storage.test'
import authServiceTest from './auth/service.test'
import dashboardViewModelTest from './dashboard/viewmodel.test'
import adminServiceTest from './enterprise/admin-service.test'
import firewallModelsTest from './firewall/models.test'
import firewallServiceTest from './firewall/service.test'
import firewallStringsTest from './firewall/strings.test'
import helpFeedbackStringsTest from './help/strings.test'
import identityServiceTest from './identity/service.test'
import identitySettingsViewModelTest from './identity/settings-viewmodel.test'
import logAuditSourceTest from './log-manage/audit-source.test'
import logCollectorServiceTest from './log-manage/collector-service.test'
import logCrashSourceTest from './log-manage/crash-source.test'
import logEntryNormalizerTest from './log-manage/entry-normalizer.test'
import logExportServiceTest from './log-manage/export-service.test'
import logListViewModelTest from './log-manage/list-viewmodel.test'
import logManageModelsTest from './log-manage/models.test'
import logPathUtilsTest from './log-manage/path-utils.test'
import logRepositoryTest from './log-manage/repository.test'
import logSettingsViewModelTest from './log-manage/settings-viewmodel.test'
import dataModelsTest from './models/data-models.test'
import peripheralBluetoothAclConsumerTest from './peripheral/connection-record-bluetooth-acl-consumer.test'
import peripheralPipelineTest from './peripheral/connection-record-pipeline.test'
import peripheralConnectionRecordServiceTest from './peripheral/connection-record-service.test'
import peripheralDevicePolicyDispatchServiceTest from './peripheral/device-policy-dispatch-service.test'
import peripheralUsbConsumerTest from './peripheral/connection-record-usb-consumer.test'
import peripheralModelsTest from './peripheral/models.test'
import peripheralServiceTest from './peripheral/service.test'
import peripheralStringsTest from './peripheral/strings.test'
import peripheralTraceRepositoryTest from './peripheral/trace-repository.test'
import toolSettingsViewModelTest from './tool-settings/viewmodel.test'
import peripheralRecordDisplayUtilsTest from './utils/PeripheralRecordDisplayUtils.test'
import peripheralRecordViewDataUtilsTest from './utils/PeripheralRecordViewDataUtils.test'
import interfaceControlViewModelTest from './viewmodels/InterfaceControlViewModel.test'
import peripheralPolicyViewModelTest from './viewmodels/PeripheralPolicyViewModel.test'
import peripheralRecordViewModelTest from './viewmodels/PeripheralRecordViewModel.test'
import peripheralViewModelTest from './viewmodels/PeripheralViewModel.test'
import peripheralPageTest from './views/PeripheralPage.test'

export default function testsuite() {
  localUnitTest()
  secureStorageTest()
  authServiceTest()
  dashboardViewModelTest()
  adminServiceTest()
  firewallModelsTest()
  firewallServiceTest()
  firewallStringsTest()
  helpFeedbackStringsTest()
  identityServiceTest()
  identitySettingsViewModelTest()
  logAuditSourceTest()
  logCollectorServiceTest()
  logCrashSourceTest()
  logEntryNormalizerTest()
  logExportServiceTest()
  logListViewModelTest()
  logManageModelsTest()
  logPathUtilsTest()
  logRepositoryTest()
  logSettingsViewModelTest()
  dataModelsTest()
  peripheralBluetoothAclConsumerTest()
  peripheralPipelineTest()
  peripheralConnectionRecordServiceTest()
  peripheralDevicePolicyDispatchServiceTest()
  peripheralUsbConsumerTest()
  peripheralModelsTest()
  peripheralServiceTest()
  peripheralStringsTest()
  peripheralTraceRepositoryTest()
  toolSettingsViewModelTest()
  peripheralRecordDisplayUtilsTest()
  peripheralRecordViewDataUtilsTest()
  interfaceControlViewModelTest()
  peripheralPolicyViewModelTest()
  peripheralRecordViewModelTest()
  peripheralViewModelTest()
  peripheralPageTest()
}
