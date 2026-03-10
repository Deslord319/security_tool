import { describe, beforeAll, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON, Component } from '@kit.TestKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'RouteActionTest'
const DOMAIN = 0x0000
const BUNDLE_NAME = 'com.huawei.securitytool'
const ABILITY_NAME = 'EntryAbility'

type RouteId = 'dashboard' | 'firewall' | 'peripheral-manage'
type ThemeId = 'light' | 'dark' | 'system'

function navTextForRoute(route: RouteId): string {
  if (route === 'firewall') {
    return '防火墙'
  }
  if (route === 'peripheral-manage') {
    return '外设管理'
  }
  return '总览'
}

function pageTitleForRoute(route: RouteId): string {
  if (route === 'firewall') {
    return '防火墙'
  }
  if (route === 'peripheral-manage') {
    return '外设管理'
  }
  return '安全总览'
}

function getArg(name: string, defaultValue: string): string {
  try {
    const args = abilityDelegatorRegistry.getArguments()
    const raw = args?.parameters?.[name]
    if (typeof raw === 'string' && raw.length > 0) {
      return raw
    }
  } catch (_err) {
    // ignore
  }
  return defaultValue
}

function parseRoute(raw: string): RouteId {
  if (raw === 'firewall' || raw === 'peripheral-manage') {
    return raw
  }
  return 'dashboard'
}

function parseTheme(raw: string): ThemeId {
  if (raw === 'light' || raw === 'system') {
    return raw
  }
  return 'dark'
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

async function findByTextWithRetry(driver: Driver, text: string, attempts: number = 3): Promise<Component | null> {
  for (let i = 0; i < attempts; i++) {
    const component = await driver.findComponent(ON.text(text))
    if (component) {
      return component
    }
    await driver.delayMs(300)
  }
  return null
}

async function ensureTheme(driver: Driver, targetTheme: ThemeId): Promise<void> {
  if (targetTheme === 'system') {
    return
  }

  const menuTrigger = await driver.findComponent(ON.id('top-menu-trigger'))
  if (!menuTrigger) {
    return
  }

  await menuTrigger.click()
  await driver.delayMs(300)

  const optionId = targetTheme === 'dark' ? 'theme-option-dark' : 'theme-option-light'
  const switchEntry = await driver.findComponent(ON.id(optionId))
  if (!switchEntry) {
    return
  }

  await switchEntry.click()
  await driver.delayMs(400)

  const expectedMarkerId = targetTheme === 'dark' ? 'theme-marker-dark' : 'theme-marker-light'
  const applied = await driver.exists(ON.id(expectedMarkerId))
  expect(applied).assertTrue()
}

export default function routeActionTest() {
  describe('Route Action Test', () => {
    let driver: Driver
    const route = parseRoute(getArg('route', 'dashboard'))
    const theme = parseTheme(getArg('theme', 'dark'))

    beforeAll(async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator()
      await delegator.startAbility({
        bundleName: BUNDLE_NAME,
        moduleName: 'entry',
        abilityName: ABILITY_NAME,
        parameters: {
          skip_startup_auth: 'true',
        },
      })
      await sleep(500)
      driver = Driver.create()
      await driver.delayMs(300)
      hilog.info(DOMAIN, TAG, `route action start, route=${route}, theme=${theme}`)
    })

    it('should navigate to target route', 0, async () => {
      const navText = navTextForRoute(route)
      const titleText = pageTitleForRoute(route)

      await ensureTheme(driver, theme)
      const nav = await findByTextWithRetry(driver, navText, 3)
      expect(nav !== null).assertTrue()
      await nav!.click()
      await driver.delayMs(500)

      await driver.assertComponentExist(ON.text(titleText))
      hilog.info(DOMAIN, TAG, `route action done, route=${route}`)
    })
  })
}

