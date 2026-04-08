import localUnitTest from './common/LocalUnit.test'
import firewallModelsTest from './firewall/models.test'
import firewallStringsTest from './firewall/strings.test'
import helpFeedbackStringsTest from './help/strings.test'
import logAuditSourceTest from './log-manage/audit-source.test'
import logCrashSourceTest from './log-manage/crash-source.test'
import logManageModelsTest from './log-manage/models.test'
import logPathUtilsTest from './log-manage/path-utils.test'
import dataModelsTest from './models/data-models.test'
import peripheralStringsTest from './peripheral/strings.test'

export default function testsuite() {
  // Keep this list aligned with the currently maintained local-unit tests.
  // Several historical test files under src/test still require migration to the
  // current ArkTS/Hypium APIs and are intentionally not wired into the suite yet.
  localUnitTest()
  firewallModelsTest()
  firewallStringsTest()
  helpFeedbackStringsTest()
  logAuditSourceTest()
  logCrashSourceTest()
  logManageModelsTest()
  logPathUtilsTest()
  dataModelsTest()
  peripheralStringsTest()
}
