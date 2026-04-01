/**
 * Firewall rules page smoke test.
 */
import { describe, beforeAll, afterAll, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'FirewallRulesPageTest'
const DOMAIN = 0x0000
const BUNDLE_NAME = 'com.huawei.securitytool'
const ABILITY_NAME = 'EntryAbility'

export default function firewallRulesPageTest() {
  describe('FirewallRulesPage Test', () => {
    let driver: Driver

    beforeAll(async () => {
      hilog.info(DOMAIN, TAG, 'FirewallRulesPage tests starting...')
      const delegator = abilityDelegatorRegistry.getAbilityDelegator()
      await delegator.startAbility({
        bundleName: BUNDLE_NAME,
        abilityName: ABILITY_NAME
      })
      await sleep(2000)
      driver = Driver.create()
      await driver.delayMs(1000)
      await driver.click(ON.text('防火墙管理'))
      await driver.delayMs(1000)
      await driver.click(ON.text('规则页'))
      await driver.delayMs(1000)
    })

    afterAll(async () => {
      hilog.info(DOMAIN, TAG, 'FirewallRulesPage tests completed')
    })

    it('should display rules page header', 0, async () => {
      await driver.assertComponentExist(ON.text('自定义模式'))
      await driver.assertComponentExist(ON.text('+ 新增规则'))
      await driver.assertComponentExist(ON.text('入站规则'))
      await driver.assertComponentExist(ON.text('出站规则'))
    })

    it('should display tabs', 0, async () => {
      await driver.assertComponentExist(ON.text('全部'))
      await driver.assertComponentExist(ON.text('IP'))
      await driver.assertComponentExist(ON.text('域名'))
      await driver.assertComponentExist(ON.text('DNS'))
    })
  })
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}
