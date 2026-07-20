import appConstantsTest from './common/app-constants.test'
import dialogServiceTest from './common/dialog-service.test'
import dialogStringsTest from './common/dialog-strings.test'
import errorUtilsTest from './common/error-utils.test'
import csvFileExportServiceTest from './common/csv-file-export-service.test'
import authServiceBehaviorTest from './auth/auth-service.behavior.test'
import dashboardViewModelTest from './dashboard/viewmodel.test'
import enterpriseAdminAbilityTest from './enterprise/admin-ability.test'
import entryAbilityTest from './entryability/entryability.test'
import adminServiceTest from './enterprise/admin-service.test'
import firewallAccountChangeCoordinatorTest from './firewall/account-change-coordinator.test'
import firewallAccountChangeHandlerTest from './firewall/account-change-handler.test'
import firewallModelsTest from './firewall/models.test'
import firewallLocalRepositoryTest from './firewall/local-repository.test'
import firewallModeStrategyTest from './firewall/mode-strategy.test'
import firewallOverviewViewModelTest from './firewall/overview-viewmodel.test'
import firewallRuleFormModelTest from './firewall/rule-form-model.test'
import firewallRulesViewModelTest from './firewall/rules-viewmodel.test'
import firewallRuleUtilsTest from './firewall/rule-utils.test'
import firewallServiceTest from './firewall/service.test'
import systemUserProviderTest from './firewall/system-user-provider.test'
import firewallStringsTest from './firewall/strings.test'
import firewallUserDispatchViewModelTest from './firewall/user-dispatch-viewmodel.test'
import helpFeedbackStringsTest from './help/strings.test'
import identityServiceBehaviorTest from './identity/service-behavior.test'
import identityServiceTest from './identity/service.test'
import identitySettingsViewModelTest from './identity/settings-viewmodel.test'
import userAuthAdapterTest from './identity/user-auth-adapter.test'
import logAuditSourceTest from './log-manage/audit-source.test'
import logCollectorServiceTest from './log-manage/collector-service.test'
import logSettingsRepositoryTest from './log-manage/settings-repository.test'
import logCrashSourceTest from './log-manage/crash-source.test'
import logEntryNormalizerTest from './log-manage/entry-normalizer.test'
import logExportServiceTest from './log-manage/export-service.test'
import logArchiveExtractorTest from './log-manage/archive-extractor.test'
import logImportHashTest from './log-manage/import-hash.test'
import logImportLineReaderTest from './log-manage/import-line-reader.test'
import logImportServiceTest from './log-manage/import-service.test'
import crashImportRuleTest from './log-manage/crash-import-rule.test'
import kernelImportRuleTest from './log-manage/kernel-import-rule.test'
import systemImportRuleTest from './log-manage/system-import-rule.test'
import logListViewModelTest from './log-manage/list-viewmodel.test'
import logMaintenanceServiceTest from './log-manage/maintenance-service.test'
import logManageModelsTest from './log-manage/models.test'
import logManageModelsStateTest from './log-manage/log-manage-models.test'
import logPathUtilsTest from './log-manage/path-utils.test'
import logEntryRepositoryTest from './log-manage/entry-repository.test'
import logSettingsViewModelTest from './log-manage/settings-viewmodel.test'
import logTimestampResolverTest from './log-manage/timestamp-resolver.test'
import logPowerLifecycleSourceTest from './log-manage/power-lifecycle-source.test'
import dataModelsTest from './models/data-models.test'
import peripheralBluetoothAclConsumerTest from './peripheral/connection-record-bluetooth-acl-consumer.test'
import bluetoothConnectionRecordCoordinatorTest from './peripheral/bluetooth-connection-record-coordinator.test'
import peripheralPipelineTest from './peripheral/connection-record-pipeline.test'
import peripheralConnectionRecordServiceTest from './peripheral/connection-record-service.test'
import peripheralDevicePolicyDispatchServiceTest from './peripheral/device-policy-dispatch-service.test'
import usbDevicePolicyStateServiceTest from './peripheral/usb-device-policy-state-service.test'
import usbDeviceIdentityResolverTest from './peripheral/usb-device-identity-resolver.test'
import peripheralUsbConsumerTest from './peripheral/connection-record-usb-consumer.test'
import peripheralModelsTest from './peripheral/models.test'
import peripheralServiceTest from './peripheral/service.test'
import peripheralStringsTest from './peripheral/strings.test'
import peripheralTraceRepositoryTest from './peripheral/trace-repository.test'
import peripheralPayloadUtilsTest from './peripheral/payload-utils.test'
import peripheralTraceMaintenanceServiceTest from './peripheral/trace-maintenance-service.test'
import peripheralDevicePolicyRepositoryTest from './peripheral/device-policy-repository.test'
import peripheralPolicySnapshotTraceServiceTest from './peripheral/policy-snapshot-trace-service.test'
import bluetoothPolicySnapshotTraceServiceTest from './peripheral/bluetooth-policy-snapshot-trace-service.test'
import runtimeProducerAdapterTest from './peripheral/runtime-producer-adapter.test'
import usbGlobalPolicyServiceTest from './peripheral/usb-global-policy-service.test'
import permissionViewModelTest from './permission-manage/viewmodel.test'
import themeManagerTest from './theme/theme-manager.test'
import toolSettingsRepositoryTest from './tool-settings/repository.test'
import systemSettingsServiceTest from './tool-settings/system-settings-service.test'
import toolSettingsViewModelTest from './tool-settings/viewmodel.test'
import peripheralRecordDisplayUtilsTest from './utils/PeripheralRecordDisplayUtils.test'
import peripheralRecordViewDataUtilsTest from './utils/PeripheralRecordViewDataUtils.test'
import ipv4UtilsTest from './utils/Ipv4Utils.test'
import hoverUtilsTest from './utils/HoverUtils.test'
import exportMessageUtilsTest from './utils/ExportMessageUtils.test'
import formControlUtilsTest from './utils/FormControlUtils.test'
import logUtilsTest from './utils/LogUtils.test'
import routeStateUtilsTest from './utils/RouteStateUtils.test'
import scrollBarStyleUtilsTest from './utils/ScrollBarStyleUtils.test'
import timedLoadingDialogRunnerTest from './utils/TimedLoadingDialogRunner.test'
import valuePickerTest from './utils/ValuePicker.test'
import interfaceControlViewModelTest from './viewmodels/InterfaceControlViewModel.test'
import peripheralPolicyViewModelTest from './viewmodels/PeripheralPolicyViewModel.test'
import peripheralRecordViewModelTest from './viewmodels/PeripheralRecordViewModel.test'
import peripheralViewModelTest from './viewmodels/PeripheralViewModel.test'
import peripheralPageTest from './views/PeripheralPage.test'
import settingsPagesStateTest from './views/SettingsPagesState.test'

export default function testsuite() {
  appConstantsTest()
  dialogServiceTest()
  dialogStringsTest()
  errorUtilsTest()
  csvFileExportServiceTest()
  authServiceBehaviorTest()
  entryAbilityTest()
  dashboardViewModelTest()
  enterpriseAdminAbilityTest()
  adminServiceTest()
  firewallAccountChangeCoordinatorTest()
  firewallModelsTest()
  firewallLocalRepositoryTest()
  firewallModeStrategyTest()
  firewallRuleFormModelTest()
  firewallRuleUtilsTest()
  firewallServiceTest()
  systemUserProviderTest()
  firewallStringsTest()
  firewallUserDispatchViewModelTest()
  helpFeedbackStringsTest()
  identityServiceBehaviorTest()
  identityServiceTest()
  identitySettingsViewModelTest()
  userAuthAdapterTest()
  logAuditSourceTest()
  logCollectorServiceTest()
  logSettingsRepositoryTest()
  logCrashSourceTest()
  logEntryNormalizerTest()
  logExportServiceTest()
  logArchiveExtractorTest()
  logImportHashTest()
  logImportLineReaderTest()
  logImportServiceTest()
  crashImportRuleTest()
  kernelImportRuleTest()
  systemImportRuleTest()
  logListViewModelTest()
  logMaintenanceServiceTest()
  logManageModelsTest()
  logManageModelsStateTest()
  logPathUtilsTest()
  logEntryRepositoryTest()
  logSettingsViewModelTest()
  logTimestampResolverTest()
  logPowerLifecycleSourceTest()
  dataModelsTest()
  peripheralBluetoothAclConsumerTest()
  bluetoothConnectionRecordCoordinatorTest()
  peripheralPipelineTest()
  peripheralConnectionRecordServiceTest()
  peripheralDevicePolicyDispatchServiceTest()
  usbDevicePolicyStateServiceTest()
  usbDeviceIdentityResolverTest()
  peripheralUsbConsumerTest()
  peripheralModelsTest()
  peripheralServiceTest()
  peripheralStringsTest()
  peripheralTraceRepositoryTest()
  peripheralPayloadUtilsTest()
  peripheralTraceMaintenanceServiceTest()
  peripheralDevicePolicyRepositoryTest()
  peripheralPolicySnapshotTraceServiceTest()
  bluetoothPolicySnapshotTraceServiceTest()
  runtimeProducerAdapterTest()
  usbGlobalPolicyServiceTest()
  permissionViewModelTest()
  themeManagerTest()
  toolSettingsRepositoryTest()
  systemSettingsServiceTest()
  toolSettingsViewModelTest()
  peripheralRecordDisplayUtilsTest()
  peripheralRecordViewDataUtilsTest()
  ipv4UtilsTest()
  hoverUtilsTest()
  exportMessageUtilsTest()
  formControlUtilsTest()
  logUtilsTest()
  routeStateUtilsTest()
  scrollBarStyleUtilsTest()
  timedLoadingDialogRunnerTest()
  valuePickerTest()
  interfaceControlViewModelTest()
  peripheralPolicyViewModelTest()
  peripheralRecordViewModelTest()
  peripheralViewModelTest()
  peripheralPageTest()
  settingsPagesStateTest()
  firewallOverviewViewModelTest()
  firewallRulesViewModelTest()
  firewallAccountChangeHandlerTest()
}
