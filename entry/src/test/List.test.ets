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
import logManageModelsTest from './log-manage/models.test'
import logAuditServiceTest from './log-manage/audit-service.test'
import logStorageServiceTest from './log-manage/storage-service.test'
import logStorageSettingsViewModelTest from './log-manage/storage-settings-viewmodel.test'
import logRuntimeCollectorTest from './log-manage/runtime-collector.test'
import adminServiceTest from './enterprise/admin-service.test'
import dataModelsTest from './models/data-models.test'

export default function testsuite() {
  // 通用基础测试
  localUnitTest()
  secureStorageTest()

  // 防火墙模块
  firewallModelsTest()
  firewallPresetServiceTest()
  firewallServiceTest()

  // 认证模块
  authTest()

  // 外设模块
  peripheralModelsTest()
  peripheralServiceTest()
  peripheralConnectionRecordServiceTest()

  // 身份鉴别模块
  identityTest()
  identitySettingsViewModelTest()

  // 日志管理模块
  logManageModelsTest()
  logAuditServiceTest()
  logStorageServiceTest()
  logStorageSettingsViewModelTest()
  logRuntimeCollectorTest()

  // 企业管理员模块
  adminServiceTest()

  // 数据模型
  dataModelsTest()
}
