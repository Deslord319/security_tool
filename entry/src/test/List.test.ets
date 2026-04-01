import localUnitTest from './common/LocalUnit.test'
import secureStorageTest from './common/secure-storage.test'
import firewallModelsTest from './firewall/models.test'
import firewallPresetServiceTest from './firewall/preset-service.test'
import firewallServiceTest from './firewall/service.test'
import authTest from './auth/service.test'
import peripheralModelsTest from './peripheral/models.test'
import peripheralServiceTest from './peripheral/service.test'
import peripheralConnectionRecordServiceTest from './peripheral/connection-record-service.test'
import peripheralConnectionRecordUsbConsumerTest from './peripheral/connection-record-usb-consumer.test'
import peripheralConnectionRecordBluetoothAclConsumerTest from './peripheral/connection-record-bluetooth-acl-consumer.test'
import peripheralConnectionRecordPipelineTest from './peripheral/connection-record-pipeline.test'
import identityTest from './identity/service.test'
import identitySettingsViewModelTest from './identity/settings-viewmodel.test'
import helpFeedbackStringsTest from './help/strings.test'
import logManageModelsTest from './log-manage/models.test'
import logAuditServiceTest from './log-manage/audit-service.test'
import logStorageServiceTest from './log-manage/storage-service.test'
import logRuntimeCollectorTest from './log-manage/runtime-collector.test'
import logManageViewModelTest from './log-manage/viewmodel.test'
import toolSettingsViewModelTest from './tool-settings/viewmodel.test'
import adminServiceTest from './enterprise/admin-service.test'
import dataModelsTest from './models/data-models.test'
import dashboardViewModelTest from './dashboard/viewmodel.test'

export default function testsuite() {
  // Common
  localUnitTest()
  secureStorageTest()

  // Firewall
  firewallModelsTest()
  firewallPresetServiceTest()
  firewallServiceTest()

  // Auth
  authTest()

  // Peripheral
  peripheralModelsTest()
  peripheralServiceTest()
  peripheralConnectionRecordServiceTest()
  peripheralConnectionRecordUsbConsumerTest()
  peripheralConnectionRecordBluetoothAclConsumerTest()
  peripheralConnectionRecordPipelineTest()

  // Identity
  identityTest()
  identitySettingsViewModelTest()

  // Help
  helpFeedbackStringsTest()

  // Log manage
  logManageModelsTest()
  logAuditServiceTest()
  logStorageServiceTest()
  logRuntimeCollectorTest()
  logManageViewModelTest()

  // Tool settings
  toolSettingsViewModelTest()

  // Enterprise
  adminServiceTest()

  // Shared models
  dataModelsTest()

  // Dashboard
  dashboardViewModelTest()
}
