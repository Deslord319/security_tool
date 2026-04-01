/**
 * Add rule dialog smoke test.
 */
import { describe, beforeAll, afterAll, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { TestLogUtils } from '../../utils/TestLogUtils'

const TAG = 'AddRuleDialogTest'
const BUNDLE_NAME = 'com.huawei.securitytool'
const ABILITY_NAME = 'EntryAbility'

export default function addRuleDialogTest() {
  describe('AddRuleDialog Component Test', () => {
    let driver: Driver

    beforeAll(async () => {
      TestLogUtils.info(TAG, 'AddRuleDialog tests starting...')
      const delegator = abilityDelegatorRegistry.getAbilityDelegator()
      await delegator.startAbility({
        bundleName: BUNDLE_NAME,
        abilityName: ABILITY_NAME
      })
      await sleep(2000)
      driver = Driver.create()
      await driver.delayMs(1000)

      const firewallNav = await driver.findComponent(ON.text('防火墙管理'))
      if (firewallNav) {
        await firewallNav.click()
        await driver.delayMs(800)
      }

      const rulesPage = await driver.findComponent(ON.text('规则页'))
      if (rulesPage) {
        await rulesPage.click()
        await driver.delayMs(800)
      }

      const addRule = await driver.findComponent(ON.text('+ 新增规则'))
      if (addRule) {
        await addRule.click()
        await driver.delayMs(500)
      }
    })

    afterAll(async () => {
      TestLogUtils.info(TAG, 'AddRuleDialog tests completed')
    })

    it('should display dialog fields', 0, async () => {
      await driver.assertComponentExist(ON.text('新增规则'))
      await driver.assertComponentExist(ON.text('规则类型'))
      await driver.assertComponentExist(ON.text('规则名称'))
      await driver.assertComponentExist(ON.text('地址'))
      await driver.assertComponentExist(ON.text('协议'))
      await driver.assertComponentExist(ON.text('动作'))
      await driver.assertComponentExist(ON.text('方向'))
    })

    it('should display action buttons', 0, async () => {
      await driver.assertComponentExist(ON.text('取消'))
      await driver.assertComponentExist(ON.text('确定'))
    })
  })
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}
