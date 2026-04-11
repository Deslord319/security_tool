import localUnitTest from './common/LocalUnit.test'
import appConstantsTest from './common/app-constants.test'
import dialogServiceTest from './common/dialog-service.test'
import dialogStringsTest from './common/dialog-strings.test'
import errorUtilsTest from './common/error-utils.test'
import secureStorageTest from './common/secure-storage.test'
import authServiceTest from './auth/service.test'
import dashboardViewModelTest from './dashboard/viewmodel.test'
import enterpriseAdminAbilityTest from './enterprise/admin-ability.test'
import entryAbilityTest from './entryability/entryability.test'
import adminServiceTest from './enterprise/admin-service.test'
import firewallAuthServiceTest from './firewall/auth-service.test'
import customModeStrategyTest from './firewall/custom-mode-strategy.test'
import firewallModeRuleBuilderTest from './firewall/mode-rule-builder.test'
import firewallModelsTest from './firewall/models.test'
import firewallPresetConfigReaderTest from './firewall/preset-config-reader.test'
import firewallRulesServiceTest from './firewall/rules-service.test'
import firewallServiceTest from './firewall/service.test'
import firewallStrategyFactoryTest from './firewall/strategy-factory.test'
import systemUserProviderTest from './firewall/system-user-provider.test'
import firewallUserDispatchServiceTest from './firewall/user-dispatch.test'
import firewallStringsTest from './firewall/strings.test'
import helpFeedbackStringsTest from './help/strings.test'
import identityServiceBehaviorTest from './identity/service-behavior.test'
import identityServiceTest from './identity/service.test'
import identitySettingsViewModelTest from './identity/settings-viewmodel.test'
import logAuditSourceTest from './log-manage/audit-source.test'
import logCollectorServiceTest from './log-manage/collector-service.test'
import logSettingsRepositoryTest from './log-manage/settings-repository.test'
import logCrashSourceTest from './log-manage/crash-source.test'
import logEntryNormalizerTest from './log-manage/entry-normalizer.test'
import logExportServiceTest from './log-manage/export-service.test'
import logListViewModelTest from './log-manage/list-viewmodel.test'
import logMaintenanceServiceTest from './log-manage/maintenance-service.test'
import logManageModelsTest from './log-manage/models.test'
import logPathUtilsTest from './log-manage/path-utils.test'
import logEntryRepositoryTest from './log-manage/entry-repository.test'
import logSettingsViewModelTest from './log-manage/settings-viewmodel.test'
import logTimestampResolverTest from './log-manage/timestamp-resolver.test'
import logValuePickerTest from './log-manage/value-picker.test'
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
import themeManagerTest from './theme/theme-manager.test'
import toolSettingsRepositoryTest from './tool-settings/repository.test'
import systemSettingsServiceTest from './tool-settings/system-settings-service.test'
import toolSettingsViewModelTest from './tool-settings/viewmodel.test'
import peripheralRecordDisplayUtilsTest from './utils/PeripheralRecordDisplayUtils.test'
import peripheralRecordViewDataUtilsTest from './utils/PeripheralRecordViewDataUtils.test'
import ipv4UtilsTest from './utils/Ipv4Utils.test'
import interfaceControlViewModelTest from './viewmodels/InterfaceControlViewModel.test'
import peripheralPolicyViewModelTest from './viewmodels/PeripheralPolicyViewModel.test'
import peripheralRecordViewModelTest from './viewmodels/PeripheralRecordViewModel.test'
import peripheralViewModelTest from './viewmodels/PeripheralViewModel.test'
import peripheralPageTest from './views/PeripheralPage.test'

export default function testsuite() {
  localUnitTest()
  appConstantsTest()
  dialogServiceTest()
  dialogStringsTest()
  errorUtilsTest()
  secureStorageTest()
  authServiceTest()
  entryAbilityTest()
  dashboardViewModelTest()
  enterpriseAdminAbilityTest()
  adminServiceTest()
  firewallAuthServiceTest()
  customModeStrategyTest()
  firewallModeRuleBuilderTest()
  firewallModelsTest()
  firewallPresetConfigReaderTest()
  firewallRulesServiceTest()
  firewallServiceTest()
  firewallStrategyFactoryTest()
  systemUserProviderTest()
  firewallUserDispatchServiceTest()
  firewallStringsTest()
  helpFeedbackStringsTest()
  identityServiceBehaviorTest()
  identityServiceTest()
  identitySettingsViewModelTest()
  logAuditSourceTest()
  logCollectorServiceTest()
  logSettingsRepositoryTest()
  logCrashSourceTest()
  logEntryNormalizerTest()
  logExportServiceTest()
  logListViewModelTest()
  logMaintenanceServiceTest()
  logManageModelsTest()
  logPathUtilsTest()
  logEntryRepositoryTest()
  logSettingsViewModelTest()
  logTimestampResolverTest()
  logValuePickerTest()
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
  themeManagerTest()
  toolSettingsRepositoryTest()
  systemSettingsServiceTest()
  toolSettingsViewModelTest()
  peripheralRecordDisplayUtilsTest()
  peripheralRecordViewDataUtilsTest()
  ipv4UtilsTest()
  interfaceControlViewModelTest()
  peripheralPolicyViewModelTest()
  peripheralRecordViewModelTest()
  peripheralViewModelTest()
  peripheralPageTest()
}
