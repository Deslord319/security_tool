import localUnitTest from './common/LocalUnit.test'
import firewallModelsTest from './firewall/models.test'
import firewallServiceTest from './firewall/service.test'
import peripheralModelsTest from './peripheral/models.test'

export default function testsuite() {
  // 通用基础测试
  localUnitTest()

  // 防火墙模块
  firewallModelsTest()
  firewallServiceTest()

  // 外设模块
  peripheralModelsTest()
}
