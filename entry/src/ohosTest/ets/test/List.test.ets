import abilityTest from './common/Ability.test'
import dashboardComponentTest from './dashboard/component.test'
import dashboardSnapshotTest from './dashboard/snapshot.test'
import firewallComponentTest from './firewall/component.test'
import firewallFlowTest from './firewall/flow.test'
import peripheralSnapshotTest from './peripheral/snapshot.test'
import multiPageNavigationTest from './navigation/multi-page.test'
import logManageComponentTest from './log-manage/component.test'
import logManageFlowTest from './log-manage/flow.test'

export default function testsuite() {
  // 通用基础测试
  abilityTest()

  // Dashboard 模块
  dashboardComponentTest()
  dashboardSnapshotTest()

  // 防火墙模块
  firewallComponentTest()
  firewallFlowTest()

  // 外设模块
  peripheralSnapshotTest()

  // 日志管理模块
  logManageComponentTest()
  logManageFlowTest()

  // 跨模块导航测试
  multiPageNavigationTest()
}
