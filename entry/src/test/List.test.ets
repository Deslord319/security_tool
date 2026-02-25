import localUnitTest from './LocalUnit.test'
import dataModelsTest from './models/DataModels.test'
import firewallServiceTest from './services/FirewallService.test'

export default function testsuite() {
  // 原有测试
  localUnitTest()

  // 单元测试 - 数据模型
  dataModelsTest()

  // 服务层测试 - 防火墙服务
  firewallServiceTest()
}