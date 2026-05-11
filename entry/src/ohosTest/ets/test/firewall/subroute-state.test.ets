/**
 * Firewall subroute restore device test.
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver } from '@kit.TestKit'
import { TestLogUtils } from '../../utils/TestLogUtils'
import { clickByText, existsById, existsByText, safeDelay, sleep } from '../../utils/TestDriverUtils'

const TAG = 'FirewallSubrouteStateTest'
const BUNDLE_NAME = 'com.huawei.securitytool'
const ABILITY_NAME = 'EntryAbility'

export default function firewallSubrouteStateTest() {
  describe('Firewall Subroute State Test', () => {
    let driver: Driver

    beforeAll(async () => {
      TestLogUtils.info(TAG, 'firewall subroute state test starting...')
      const delegator = abilityDelegatorRegistry.getAbilityDelegator()
      await delegator.startAbility({
        bundleName: BUNDLE_NAME,
        moduleName: 'entry',
        abilityName: ABILITY_NAME
      })
      await sleep(1800)
      driver = Driver.create()
      await safeDelay(driver, 800)
      await waitForId(driver, 'top-menu-trigger')
    })

    afterAll(async () => {
      await clickByText(driver, '安全总览')
      TestLogUtils.info(TAG, 'firewall subroute state test completed')
    })

    it('should restore rules page after leaving firewall module', 0, async () => {
      await clickAndExpect(driver, '防火墙管理')
      await waitForText(driver, '规则页')

      await clickAndExpect(driver, '规则页')
      await waitForRulesPage(driver)

      await clickAndExpect(driver, '身份鉴别')
      await waitForText(driver, '口令复杂度策略')

      await clickAndExpect(driver, '防火墙管理')
      await waitForRulesPage(driver)
    })
  })
}

async function clickAndExpect(driver: Driver, text: string): Promise<void> {
  const clicked = await clickByText(driver, text)
  expect(clicked).assertTrue()
  await safeDelay(driver, 700)
}

async function waitForId(driver: Driver, id: string): Promise<void> {
  for (let attempt = 0; attempt < 12; attempt++) {
    if (await existsById(driver, id)) {
      return
    }
    await safeDelay(driver, 350)
  }
  expect(false).assertTrue()
}

async function waitForText(driver: Driver, text: string): Promise<void> {
  for (let attempt = 0; attempt < 12; attempt++) {
    if (await existsByText(driver, text)) {
      return
    }
    await safeDelay(driver, 350)
  }
  expect(false).assertTrue()
}

async function waitForRulesPage(driver: Driver): Promise<void> {
  for (let attempt = 0; attempt < 18; attempt++) {
    if (await existsById(driver, 'route-page-firewall-rules')) {
      return
    }
    if (await existsByText(driver, '新增规则') && await existsByText(driver, '全部规则')) {
      return
    }
    await safeDelay(driver, 500)
  }
  expect(false).assertTrue()
}
