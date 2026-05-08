import { beforeEach, describe, expect, it } from '@ohos/hypium'
import { ConfigurationConstant, common } from '@kit.AbilityKit'

import {
  STORAGE_KEY_OPTION,
  STORAGE_KEY_PREFERENCE,
  STORAGE_KEY_THEME,
  ThemeManager
} from '../../main/ets/theme/ThemeManager'
import { ThemeMode, ThemeOption, ThemePreference } from '../../main/ets/theme/ThemeColors'

interface ThemeManagerContractAccess {
  context: common.UIAbilityContext | null
  dataPreferences: Object | null
  initialized: boolean
  listeners: Array<() => void>
  lastDetectedSystemTheme: ThemeMode
  initSync(context: common.UIAbilityContext): void
}

function createContext(colorMode: ConfigurationConstant.ColorMode): common.UIAbilityContext {
  return {
    config: {
      colorMode
    }
  } as common.UIAbilityContext
}

function resetStorage(): void {
  AppStorage.setOrCreate<ThemeMode>(STORAGE_KEY_THEME, ThemeMode.LIGHT)
  AppStorage.setOrCreate<ThemePreference>(STORAGE_KEY_PREFERENCE, ThemePreference.SYSTEM)
  AppStorage.setOrCreate<ThemeOption>(STORAGE_KEY_OPTION, ThemeOption.SYSTEM)
}

function getStoredPreference(): ThemePreference {
  return AppStorage.get<ThemePreference>(STORAGE_KEY_PREFERENCE) || ThemePreference.SYSTEM
}

export default function themeManagerTest() {
  describe('ThemeManager', () => {
    let manager: ThemeManager
    let access: ThemeManagerContractAccess

    beforeEach(() => {
      manager = ThemeManager.getInstance()
      let rawManager = manager as Object
      access = rawManager as ThemeManagerContractAccess
      access.context = null
      access.dataPreferences = null
      access.initialized = false
      access.listeners = []
      access.lastDetectedSystemTheme = ThemeMode.LIGHT
      resetStorage()
    })

    it('should return singleton instance', 0, () => {
      expect(ThemeManager.getInstance() === ThemeManager.getInstance()).assertTrue()
    })

    it('should initialize sync storage from system dark mode', 0, () => {
      access.initSync(createContext(ConfigurationConstant.ColorMode.COLOR_MODE_DARK))

      expect(manager.getCurrentTheme()).assertEqual(ThemeMode.DARK)
      expect(getStoredPreference()).assertEqual(ThemePreference.SYSTEM)
      expect(manager.getCurrentOption()).assertEqual(ThemeOption.SYSTEM)
    })

    it('should update system theme when configuration changes in system mode', 0, () => {
      let notified = 0
      manager.subscribe(() => {
        notified++
      })
      access.initSync(createContext(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT))

      manager.onConfigurationUpdate(ConfigurationConstant.ColorMode.COLOR_MODE_DARK)

      expect(manager.getCurrentTheme()).assertEqual(ThemeMode.DARK)
      expect(notified).assertEqual(1)
    })

    it('should ignore configuration updates in manual mode', 0, async () => {
      await manager.setOption(ThemeOption.LIGHT)
      let notified = 0
      manager.subscribe(() => {
        notified++
      })

      manager.onConfigurationUpdate(ConfigurationConstant.ColorMode.COLOR_MODE_DARK)

      expect(manager.getCurrentTheme()).assertEqual(ThemeMode.LIGHT)
      expect(getStoredPreference()).assertEqual(ThemePreference.MANUAL)
      expect(notified).assertEqual(0)
    })

    it('should toggle theme and persist option in memory state', 0, async () => {
      resetStorage()

      await manager.toggleTheme()

      expect(manager.getCurrentTheme()).assertEqual(ThemeMode.DARK)
      expect(getStoredPreference()).assertEqual(ThemePreference.MANUAL)
      expect(manager.getCurrentOption()).assertEqual(ThemeOption.DARK)
    })

    it('should switch back to system preference using detected context theme', 0, async () => {
      access.context = createContext(ConfigurationConstant.ColorMode.COLOR_MODE_DARK)
      access.lastDetectedSystemTheme = ThemeMode.DARK
      await manager.setOption(ThemeOption.LIGHT)

      await manager.setOption(ThemeOption.SYSTEM)

      expect(getStoredPreference()).assertEqual(ThemePreference.SYSTEM)
      expect(manager.getCurrentTheme()).assertEqual(ThemeMode.DARK)
    })

    it('should apply manual option without preferences backend', 0, async () => {
      await manager.setOption(ThemeOption.DARK)

      expect(manager.getCurrentTheme()).assertEqual(ThemeMode.DARK)
      expect(getStoredPreference()).assertEqual(ThemePreference.MANUAL)
      expect(manager.getCurrentOption()).assertEqual(ThemeOption.DARK)
    })

    it('should reapply manual theme and notify unique listeners only once', 0, () => {
      let notified = 0
      let listener = () => {
        notified++
      }
      AppStorage.setOrCreate<ThemeMode>(STORAGE_KEY_THEME, ThemeMode.DARK)
      AppStorage.setOrCreate<ThemePreference>(STORAGE_KEY_PREFERENCE, ThemePreference.MANUAL)
      manager.subscribe(listener)
      manager.subscribe(listener)

      manager.reapplyTheme()

      expect(manager.getCurrentTheme()).assertEqual(ThemeMode.DARK)
      expect(notified).assertEqual(1)
    })

    it('should stop notifying removed listeners', 0, () => {
      let notified = 0
      let listener = () => {
        notified++
      }
      manager.subscribe(listener)
      manager.unsubscribe(listener)

      manager.reapplyTheme()

      expect(notified).assertEqual(0)
    })
  })
}
