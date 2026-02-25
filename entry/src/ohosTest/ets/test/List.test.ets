import abilityTest from './Ability.test'
import statCardTest from './components/StatCard.test'
import pageSnapshotTest from './e2e/PageSnapshot.test'
import firewallFlowTest from './e2e/flows/FirewallFlow.test'

export default function testsuite() {
  // 原有 Ability 测试
  abilityTest()

  // 组件测试
  statCardTest()

  // E2E 测试 - 页面快照回归
  pageSnapshotTest()

  // E2E 测试 - 防火墙流程
  firewallFlowTest()
}