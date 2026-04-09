/**
 * Firewall rules page smoke test.
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Component, Driver, ON } from '@kit.TestKit'
import { TestLogUtils } from '../../utils/TestLogUtils'

const TAG = 'FirewallRulesPageTest'
const BUNDLE_NAME = 'com.huawei.securitytool'
const ABILITY_NAME = 'EntryAbility'

export default function firewallRulesPageTest() {
  describe('FirewallRulesPage Test', () => {
    let driver: Driver

    beforeAll(async () => {
      TestLogUtils.info(TAG, 'FirewallRulesPage tests starting...')
      const delegator = abilityDelegatorRegistry.getAbilityDelegator()
      await delegator.startAbility({
        bundleName: BUNDLE_NAME,
        moduleName: 'entry',
        abilityName: ABILITY_NAME
      })
      await sleep(2000)
      driver = Driver.create()
      await driver.delayMs(1000)

      const firewallEntry = await clickByText(driver, '防火墙管理')
      expect(firewallEntry).assertTrue()
      await driver.delayMs(1000)

      const rulesEntry = await clickByText(driver, '规则页')
      expect(rulesEntry).assertTrue()
      await driver.delayMs(1200)
    })

    afterAll(async () => {
      TestLogUtils.info(TAG, 'FirewallRulesPage tests completed')
    })

    it('should display rules page header', 0, async () => {
      await driver.assertComponentExist(ON.text('自定义模式'))
      await driver.assertComponentExist(ON.text('新增规则'))
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

async function findByText(driver: Driver, text: string): Promise<Component | null> {
  try {
    return await driver.findComponent(ON.text(text))
  } catch (_err) {
    return null
  }
}

async function clickByText(driver: Driver, text: string): Promise<boolean> {
  const component = await findByText(driver, text)
  if (component === null) {
    return false
  }
  try {
    await component.click()
    return true
  } catch (_err) {
    return false
  }
}
