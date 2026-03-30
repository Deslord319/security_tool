import localUnitTest from './common/LocalUnit.test'
import secureStorageTest from './common/secure-storage.test'
import firewallModelsTest from './firewall/models.test'
import firewallPresetServiceTest from './firewall/preset-service.test'
import firewallServiceTest from './firewall/service.test'
import authTest from './auth/service.test'
import peripheralModelsTest from './peripheral/models.test'
import peripheralServiceTest from './peripheral/service.test'
import peripheralConnectionRecordServiceTest from './peripheral/connection-record-service.test'
import identityTest from './identity/service.test'
import identitySettingsViewModelTest from './identity/settings-viewmodel.test'
import helpFeedbackStringsTest from './help/strings.test'
import logManageModelsTest from './log-manage/models.test'
import logAuditServiceTest from './log-manage/audit-service.test'
import logStorageServiceTest from './log-manage/storage-service.test'
import logStorageSettingsViewModelTest from './log-manage/storage-settings-viewmodel.test'
import logRuntimeCollectorTest from './log-manage/runtime-collector.test'
import toolSettingsViewModelTest from './tool-settings/viewmodel.test'
import adminServiceTest from './enterprise/admin-service.test'
import dataModelsTest from './models/data-models.test'

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

  // Identity
  identityTest()
  identitySettingsViewModelTest()

  // Help
  helpFeedbackStringsTest()

  // Log manage
  logManageModelsTest()
  logAuditServiceTest()
  logStorageServiceTest()
  logStorageSettingsViewModelTest()
  logRuntimeCollectorTest()

  // Tool settings
  toolSettingsViewModelTest()

  // Enterprise
  adminServiceTest()

  // Shared models
  dataModelsTest()
}
