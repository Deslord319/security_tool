/**
 * Help and feedback page smoke test.
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Component, Driver, ON } from '@kit.TestKit'
import { TestLogUtils } from '../../utils/TestLogUtils'

const TAG = 'HelpFeedbackPageTest'
const BUNDLE_NAME = 'com.huawei.securitytool'
const ABILITY_NAME = 'EntryAbility'

export default function helpFeedbackPageTest() {
  describe('HelpFeedbackPage Test', () => {
    let driver: Driver

    beforeAll(async () => {
      TestLogUtils.info(TAG, 'HelpFeedbackPage tests starting...')
      const delegator = abilityDelegatorRegistry.getAbilityDelegator()
      await delegator.startAbility({
        bundleName: BUNDLE_NAME,
        moduleName: 'entry',
        abilityName: ABILITY_NAME
      })
      await sleep(2000)
      driver = Driver.create()
      await driver.delayMs(1000)
      const menuOpened = await clickById(driver, 'top-menu-trigger')
      expect(menuOpened).assertTrue()
      await driver.delayMs(400)

      const helpFeedbackEntry = await clickById(driver, 'menu-action-help-feedback')
      expect(helpFeedbackEntry).assertTrue()
      await driver.delayMs(1000)
    })

    afterAll(async () => {
      TestLogUtils.info(TAG, 'HelpFeedbackPage tests completed')
    })

    it('should display page header and sections', 0, async () => {
      await driver.assertComponentExist(ON.text('帮助与反馈'))
      await driver.assertComponentExist(ON.text('使用指南'))
      await driver.assertComponentExist(ON.text('常见问题'))
      await driver.assertComponentExist(ON.text('联系与反馈'))
    })

    it('should display guide items', 0, async () => {
      await driver.assertComponentExist(ON.text('防火墙管理'))
      await driver.assertComponentExist(ON.text('外设管理'))
      await driver.assertComponentExist(ON.text('身份鉴别'))
      await driver.assertComponentExist(ON.text('工具设置'))
    })

    it('should display faq and contact info', 0, async () => {
      const faqExists = await existsByText(driver, '如何启用启动校验？')
      expect(faqExists).assertTrue()
      await driver.assertComponentExist(ON.text('反馈邮箱'))
      await driver.assertComponentExist(ON.text('consumer@huawei.com'))
    })
  })
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

async function findById(driver: Driver, id: string): Promise<Component | null> {
  try {
    return await driver.findComponent(ON.id(id))
  } catch (_err) {
    return null
  }
}

async function findByText(driver: Driver, text: string): Promise<Component | null> {
  try {
    return await driver.findComponent(ON.text(text))
  } catch (_err) {
    return null
  }
}

async function clickComponent(component: Component | null): Promise<boolean> {
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

async function clickById(driver: Driver, id: string): Promise<boolean> {
  return await clickComponent(await findById(driver, id))
}

async function existsByText(driver: Driver, text: string): Promise<boolean> {
  return await findByText(driver, text) !== null
}
