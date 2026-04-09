/**
 * Identity page smoke test.
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Component, Driver, ON } from '@kit.TestKit'
import { TestLogUtils } from '../../utils/TestLogUtils'

const TAG = 'IdentityPageTest'
const BUNDLE_NAME = 'com.huawei.securitytool'
const ABILITY_NAME = 'EntryAbility'

export default function identityPageTest() {
  describe('IdentityPage Test', () => {
    let driver: Driver

    beforeAll(async () => {
      TestLogUtils.info(TAG, 'IdentityPage tests starting...')
      const delegator = abilityDelegatorRegistry.getAbilityDelegator()
      await delegator.startAbility({
        bundleName: BUNDLE_NAME,
        moduleName: 'entry',
        abilityName: ABILITY_NAME
      })
      await sleep(2000)
      driver = Driver.create()
      await driver.delayMs(1000)

      const identityEntry = await clickByText(driver, '身份鉴别')
      expect(identityEntry).assertTrue()
      await driver.delayMs(1000)
    })

    afterAll(async () => {
      TestLogUtils.info(TAG, 'IdentityPage tests completed')
    })

    it('should display page title and save action', 0, async () => {
      await driver.assertComponentExist(ON.text('身份鉴别'))
      await driver.assertComponentExist(ON.text('保存配置'))
    })

    it('should display password policy items', 0, async () => {
      await driver.assertComponentExist(ON.text('最小密码长度'))
      await driver.assertComponentExist(ON.text('要求包含大写字母'))
      await driver.assertComponentExist(ON.text('要求包含小写字母'))
      await driver.assertComponentExist(ON.text('要求包含数字'))
      await driver.assertComponentExist(ON.text('要求包含特殊字符'))
      await driver.assertComponentExist(ON.text('密码有效期'))
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
