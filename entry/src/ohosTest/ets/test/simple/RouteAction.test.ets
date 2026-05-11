import { describe, beforeAll, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver } from '@kit.TestKit'
import { TestLogUtils } from '../../utils/TestLogUtils'
import { clickById, clickByText, existsById, existsByText, safeDelay, sleep } from '../../utils/TestDriverUtils'

const TAG = 'RouteActionTest'
const BUNDLE_NAME = 'com.huawei.securitytool'
const ABILITY_NAME = 'EntryAbility'

type SingleRouteId =
  | 'dashboard'
  | 'firewall'
  | 'log-manage'
  | 'peripheral-manage'
  | 'identity'
  | 'tool-settings'
  | 'help-feedback'
type RouteId = SingleRouteId | 'all'
type SingleThemeId = 'light' | 'dark' | 'system'
type ThemeId = SingleThemeId | 'all'

const ROUTE_ORDER: SingleRouteId[] = [
  'dashboard',
  'firewall',
  'log-manage',
  'peripheral-manage',
  'identity',
  'tool-settings',
  'help-feedback'
]

function routeNavText(route: SingleRouteId): string {
  switch (route) {
    case 'dashboard':
      return '安全总览'
    case 'firewall':
      return '防火墙管理'
    case 'log-manage':
      return '日志管理'
    case 'peripheral-manage':
      return '外设管理'
    case 'identity':
      return '身份鉴别'
    case 'tool-settings':
      return '工具设置'
    case 'help-feedback':
      return '帮助与反馈'
    default:
      return '安全总览'
  }
}

function routeMarkerTexts(route: SingleRouteId): string[] {
  switch (route) {
    case 'dashboard':
      return ['快捷方式', '管理员状态']
    case 'firewall':
      return ['公共网络模式', '私有网络模式', '自定义规则']
    case 'log-manage':
      return ['导出日志', '打开存储设置']
    case 'peripheral-manage':
      return ['接口管控', '设备连接记录', '黑白名单']
    case 'identity':
      return ['口令复杂度策略', '密码有效期']
    case 'tool-settings':
      return ['启动时身份校验', '认证方式']
    case 'help-feedback':
      return ['使用指南', '联系与反馈']
    default:
      return ['快捷方式']
  }
}

function routeContainerId(route: SingleRouteId): string {
  return `route-page-${route}`
}

function getArgString(name: string, defaultValue: string): string {
  try {
    const args = abilityDelegatorRegistry.getArguments()
    const raw = args?.parameters?.[name]
    if (typeof raw === 'string' && raw.length > 0) {
      return raw
    }
    if (typeof raw === 'number' || typeof raw === 'boolean') {
      return `${raw}`
    }
  } catch (_err) {
    // ignore
  }
  return defaultValue
}

function parseRoute(raw: string): RouteId {
  switch (raw) {
    case 'firewall':
    case 'log-manage':
    case 'peripheral-manage':
    case 'identity':
    case 'tool-settings':
    case 'help-feedback':
    case 'all':
      return raw
    default:
      return 'dashboard'
  }
}

function parseTheme(raw: string): ThemeId {
  switch (raw) {
    case 'light':
    case 'system':
    case 'all':
      return raw
    default:
      return 'dark'
  }
}

function routeSequence(route: RouteId): SingleRouteId[] {
  if (route === 'all') {
    return ROUTE_ORDER
  }
  return [route]
}

function themeSequence(theme: ThemeId): SingleThemeId[] {
  if (theme === 'all') {
    return ['light', 'dark', 'system']
  }
  return [theme]
}

async function openTopMenu(driver: Driver): Promise<void> {
  const clicked = await clickById(driver, 'top-menu-trigger')
  expect(clicked).assertTrue()
  await safeDelay(driver, 300)
  const popupVisible = await existsByText(driver, '显示模式')
  expect(popupVisible).assertTrue()
}

async function ensureTheme(driver: Driver, targetTheme: SingleThemeId): Promise<void> {
  if (targetTheme === 'system') {
    await openTopMenu(driver)
    const clicked = await clickById(driver, 'theme-option-system')
    expect(clicked).assertTrue()
    await safeDelay(driver, 400)
    return
  }

  await openTopMenu(driver)
  const optionId = targetTheme === 'dark' ? 'theme-option-dark' : 'theme-option-light'
  const clicked = await clickById(driver, optionId)
  expect(clicked).assertTrue()
  await safeDelay(driver, 400)

  const markerId = targetTheme === 'dark' ? 'theme-marker-dark' : 'theme-marker-light'
  const applied = await existsById(driver, markerId)
  expect(applied).assertTrue()
}

async function navigateToRoute(driver: Driver, route: SingleRouteId): Promise<void> {
  if (route === 'help-feedback') {
    await openTopMenu(driver)
    const menuClicked = await clickById(driver, 'menu-action-help-feedback')
    expect(menuClicked).assertTrue()
    await safeDelay(driver, 500)
    return
  }

  const clicked = await clickByText(driver, routeNavText(route))
  expect(clicked).assertTrue()
  await safeDelay(driver, route === 'log-manage' ? 800 : 500)
}

async function waitForRoute(driver: Driver, route: SingleRouteId): Promise<void> {
  const containerId = routeContainerId(route)
  const markers = routeMarkerTexts(route)

  for (let attempt = 0; attempt < 6; attempt++) {
    const containerExists = await existsById(driver, containerId)
    if (containerExists) {
      return
    }
    for (let i = 0; i < markers.length; i++) {
      const markerExists = await existsByText(driver, markers[i])
      if (markerExists) {
        return
      }
    }
    await safeDelay(driver, 350)
  }

  expect(false).assertTrue()
}

async function waitForAppReady(driver: Driver): Promise<void> {
  for (let attempt = 0; attempt < 10; attempt++) {
    if (await existsById(driver, 'top-menu-trigger')) {
      return
    }
    await safeDelay(driver, 300)
  }
  expect(false).assertTrue()
}

export default function routeActionTest() {
  describe('Route Action Test', () => {
    let driver: Driver
    const route = parseRoute(getArgString('route', 'all'))
    const theme = parseTheme(getArgString('theme', 'all'))

    beforeAll(async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator()
      await delegator.startAbility({
        bundleName: BUNDLE_NAME,
        moduleName: 'entry',
        abilityName: ABILITY_NAME,
      })
      await sleep(1500)
      driver = Driver.create()
      await safeDelay(driver, 800)
      await waitForAppReady(driver)
      TestLogUtils.info(TAG, 'route action start, route=%{public}s, theme=%{public}s', route, theme)
    })

    const routes = routeSequence(route)
    const themes = themeSequence(theme)

    for (let i = 0; i < themes.length; i++) {
      const currentTheme = themes[i]
      for (let j = 0; j < routes.length; j++) {
        const currentRoute = routes[j]
        it(`should navigate to ${currentRoute} with ${currentTheme} theme`, 0, async () => {
          await ensureTheme(driver, currentTheme)
          TestLogUtils.info(TAG, 'theme applied: %{public}s', currentTheme)

          await navigateToRoute(driver, currentRoute)
          await waitForRoute(driver, currentRoute)
          TestLogUtils.info(TAG, 'route verified: %{public}s | theme=%{public}s', currentRoute, currentTheme)
        })
      }
    }
  })
}
