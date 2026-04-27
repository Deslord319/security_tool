import { LogUtils } from '../utils/LogUtils'
import { common, ConfigurationConstant } from '@kit.AbilityKit'
import { ThemeMode, ThemePreference, ThemeOption } from './ThemeColors'
import { PreferencesAccessor } from '../storage/preferences/PreferencesAccessor'

const TAG = 'ThemeManager'

const PREFERENCES_NAME = 'theme_preferences'
const KEY_THEME_MODE = 'theme_mode'
const KEY_THEME_PREFERENCE = 'theme_preference'
const KEY_THEME_OPTION = 'theme_option'

// AppStorage 键名
export const STORAGE_KEY_THEME = 'currentTheme'
export const STORAGE_KEY_PREFERENCE = 'themePreference'
export const STORAGE_KEY_OPTION = 'themeOption'

export class ThemeManager {
  private static instance: ThemeManager
  private context: common.UIAbilityContext | null = null
  private initialized: boolean = false
  private listeners: Array<() => void> = []
  // 保存 initSync 时检测到的系统主题，用于后续 reapply 和 NOT_SET fallback
  private lastDetectedSystemTheme: ThemeMode = ThemeMode.LIGHT

  private constructor() {
  }

  static getInstance(): ThemeManager {
    if (!ThemeManager.instance) {
      ThemeManager.instance = new ThemeManager()
    }
    return ThemeManager.instance
  }

  // 初始化入口：同步设置系统主题 + 异步加载用户偏好
  init(context: common.UIAbilityContext): void {
    this.initSync(context)
    this.initAsync().catch((err: Error) => {
      LogUtils.error(TAG, 'ThemeManager initAsync failed: %{public}s', JSON.stringify(err))
    })
  }

  // 同步初始化：立即检测系统主题并设置 AppStorage
  // 确保页面加载前 AppStorage 中已有正确的系统主题
  private initSync(context: common.UIAbilityContext): void {
    if (this.initialized) {
      return
    }

    this.context = context

    // 同步获取系统主题（无异步操作）
    const systemTheme = this.getSystemTheme()
    this.lastDetectedSystemTheme = systemTheme

    // 用系统主题作为初始值（而非硬编码 LIGHT）
    AppStorage.setOrCreate<ThemeMode>(STORAGE_KEY_THEME, systemTheme)
    AppStorage.setOrCreate<ThemePreference>(STORAGE_KEY_PREFERENCE, ThemePreference.SYSTEM)
    AppStorage.setOrCreate<ThemeOption>(STORAGE_KEY_OPTION, ThemeOption.SYSTEM)
  }

  // 异步初始化：后台加载用户持久化偏好，必要时覆盖初始主题
  private async initAsync(): Promise<void> {
    if (this.initialized) {
      return
    }

    try {
      let pref = PreferencesAccessor.of(this.context!, PREFERENCES_NAME)
      // 读取保存的选项（新逻辑：system/light/dark 三选一）
      let savedOption = await pref.getString(KEY_THEME_OPTION, '') as ThemeOption
      if (savedOption !== ThemeOption.SYSTEM && savedOption !== ThemeOption.LIGHT && savedOption !== ThemeOption.DARK) {
        savedOption = await this.loadLegacyThemeOption(pref)
      }

      // 更新 AppStorage
      AppStorage.setOrCreate<ThemeOption>(STORAGE_KEY_OPTION, savedOption)

      // 根据选项应用主题
      if (savedOption === ThemeOption.SYSTEM) {
        AppStorage.setOrCreate<ThemePreference>(STORAGE_KEY_PREFERENCE, ThemePreference.SYSTEM)
        // 保持 initSync 设置的系统主题
      } else {
        AppStorage.setOrCreate<ThemePreference>(STORAGE_KEY_PREFERENCE, ThemePreference.MANUAL)
        const theme = savedOption === ThemeOption.DARK ? ThemeMode.DARK : ThemeMode.LIGHT
        AppStorage.setOrCreate<ThemeMode>(STORAGE_KEY_THEME, theme)
      }

      this.initialized = true
      this.notifyThemeChanged()
    } catch (err) {
      LogUtils.error(TAG, 'ThemeManager initAsync failed: %{public}s', JSON.stringify(err))
    }
  }

  // 获取系统当前主题
  private getSystemTheme(): ThemeMode {
    if (!this.context) {
      LogUtils.warn('ThemeManager', 'getSystemTheme: context is null, returning LIGHT')
      return ThemeMode.LIGHT
    }

    try {
      const config = this.context.config
      const colorMode = config?.colorMode
      if (config && config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
        return ThemeMode.DARK
      }
      if (config && config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
        return ThemeMode.LIGHT
      }
      // COLOR_MODE_NOT_SET 或其他未知值：使用上次检测到的系统主题
      // 这避免了 setColorMode(NOT_SET) 触发的瞬态状态导致误判
      LogUtils.info('ThemeManager', 'getSystemTheme: colorMode is NOT_SET or unknown, fallback to lastDetected=%{public}s', this.lastDetectedSystemTheme)
      return this.lastDetectedSystemTheme
    } catch (err) {
      LogUtils.error('ThemeManager', 'getSystemTheme failed: %{public}s', JSON.stringify(err))
    }

    return this.lastDetectedSystemTheme
  }

  // 系统配置变化回调，接收 newConfig 以获取最新的系统配置
  onConfigurationUpdate(colorMode?: ConfigurationConstant.ColorMode): void {
    const preference = AppStorage.get<ThemePreference>(STORAGE_KEY_PREFERENCE)
    if (preference === ThemePreference.SYSTEM) {
      // 优先使用传入的 colorMode（来自 onConfigurationUpdate 回调的 newConfig）
      let systemTheme: ThemeMode
      if (colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
        systemTheme = ThemeMode.DARK
        this.lastDetectedSystemTheme = systemTheme
      } else if (colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
        systemTheme = ThemeMode.LIGHT
        this.lastDetectedSystemTheme = systemTheme
      } else {
        // 如果没有传入明确的 colorMode，回退到 context.config
        systemTheme = this.getSystemTheme()
      }
      AppStorage.setOrCreate<ThemeMode>(STORAGE_KEY_THEME, systemTheme)
      this.notifyThemeChanged()
    }
  }

  // 重新应用正确的主题（在页面组件初始化后调用，修复 @StorageLink 默认值覆写）
  reapplyTheme(): void {
    const preference = AppStorage.get<ThemePreference>(STORAGE_KEY_PREFERENCE) || ThemePreference.SYSTEM
    let themeToApply: ThemeMode

    if (preference === ThemePreference.MANUAL) {
      // 手动模式：使用 initAsync 已设置的值（如果已完成），否则保持当前值
      themeToApply = AppStorage.get<ThemeMode>(STORAGE_KEY_THEME) || ThemeMode.LIGHT
      // 如果 initAsync 还没完成，当前值可能被覆盖了，暂用 lastDetected
      // 但手动模式理论上 initAsync 会覆盖回正确值
    } else {
      // 跟随系统：使用 initSync 时检测到的系统主题
      themeToApply = this.lastDetectedSystemTheme
    }

    AppStorage.setOrCreate<ThemeMode>(STORAGE_KEY_THEME, themeToApply)
    this.notifyThemeChanged()
  }

  // 设置主题（手动切换）
  async setTheme(mode: ThemeMode): Promise<void> {
    // 切换为手动模式
    AppStorage.setOrCreate<ThemePreference>(STORAGE_KEY_PREFERENCE, ThemePreference.MANUAL)
    AppStorage.setOrCreate<ThemeMode>(STORAGE_KEY_THEME, mode)
    this.notifyThemeChanged()

    // 持久化
    await this.savePreferences(mode, ThemePreference.MANUAL)
  }

  // 切换主题（在当前主题和另一主题间切换），同步更新 Option
  async toggleTheme(): Promise<void> {
    const current = AppStorage.get<ThemeMode>(STORAGE_KEY_THEME) || ThemeMode.LIGHT
    const newTheme = current === ThemeMode.DARK ? ThemeMode.LIGHT : ThemeMode.DARK
    const newOption = newTheme === ThemeMode.DARK ? ThemeOption.DARK : ThemeOption.LIGHT

    AppStorage.setOrCreate<ThemeMode>(STORAGE_KEY_THEME, newTheme)
    AppStorage.setOrCreate<ThemePreference>(STORAGE_KEY_PREFERENCE, ThemePreference.MANUAL)
    AppStorage.setOrCreate<ThemeOption>(STORAGE_KEY_OPTION, newOption)
    this.notifyThemeChanged()

    await this.saveOption(newOption)
  }

  // 设置用户偏好
  async setPreference(preference: ThemePreference): Promise<void> {
    AppStorage.setOrCreate<ThemePreference>(STORAGE_KEY_PREFERENCE, preference)

    if (preference === ThemePreference.SYSTEM) {
      // 切换为跟随系统时，立即应用系统主题
      const systemTheme = this.getSystemTheme()
      AppStorage.setOrCreate<ThemeMode>(STORAGE_KEY_THEME, systemTheme)
      await this.savePreferences(systemTheme, ThemePreference.SYSTEM)
    } else {
      // 手动模式保持当前主题
      const currentTheme = AppStorage.get<ThemeMode>(STORAGE_KEY_THEME) || ThemeMode.LIGHT
      await this.savePreferences(currentTheme, ThemePreference.MANUAL)
    }
    this.notifyThemeChanged()
  }

  // 获取当前主题
  getCurrentTheme(): ThemeMode {
    return AppStorage.get<ThemeMode>(STORAGE_KEY_THEME) || ThemeMode.LIGHT
  }

  // 获取当前偏好
  getCurrentPreference(): ThemePreference {
    return AppStorage.get<ThemePreference>(STORAGE_KEY_PREFERENCE) || ThemePreference.SYSTEM
  }

  // 获取当前选项
  getCurrentOption(): ThemeOption {
    return AppStorage.get<ThemeOption>(STORAGE_KEY_OPTION) || ThemeOption.SYSTEM
  }

  // 设置主题选项（菜单三选一）
  async setOption(option: ThemeOption): Promise<void> {
    AppStorage.setOrCreate<ThemeOption>(STORAGE_KEY_OPTION, option)

    if (option === ThemeOption.SYSTEM) {
      AppStorage.setOrCreate<ThemePreference>(STORAGE_KEY_PREFERENCE, ThemePreference.SYSTEM)
      const systemTheme = this.getSystemTheme()
      AppStorage.setOrCreate<ThemeMode>(STORAGE_KEY_THEME, systemTheme)
    } else {
      AppStorage.setOrCreate<ThemePreference>(STORAGE_KEY_PREFERENCE, ThemePreference.MANUAL)
      const theme = option === ThemeOption.DARK ? ThemeMode.DARK : ThemeMode.LIGHT
      AppStorage.setOrCreate<ThemeMode>(STORAGE_KEY_THEME, theme)
    }
    this.notifyThemeChanged()

    // 持久化
    await this.saveOption(option)
  }

  subscribe(listener: () => void): void {
    if (this.listeners.includes(listener)) {
      return
    }
    this.listeners = [...this.listeners, listener]
  }

  unsubscribe(listener: () => void): void {
    this.listeners = this.listeners.filter((item: () => void) => item !== listener)
  }

  private notifyThemeChanged(): void {
    this.listeners.forEach((listener: () => void) => {
      try {
        listener()
      } catch (err) {
        LogUtils.warn(TAG, 'notifyThemeChanged listener failed: %{public}s', JSON.stringify(err))
      }
    })
  }

  // 保存选项到 Preferences
  private async saveOption(option: ThemeOption): Promise<void> {
    if (!this.context) {
      return
    }

    try {
      let pref = PreferencesAccessor.of(this.context, PREFERENCES_NAME)
      let saved = await pref.setValue(KEY_THEME_OPTION, option)
      if (!saved) {
        LogUtils.error(TAG, 'saveOption failed: preferences_write_failed')
      }
    } catch (err) {
      LogUtils.error(TAG, 'savePreferences failed: %{public}s', JSON.stringify(err))
    }
  }

  // 保存偏好到 Preferences
  private async savePreferences(theme: ThemeMode, preference: ThemePreference): Promise<void> {
    if (!this.context) {
      return
    }

    try {
      let pref = PreferencesAccessor.of(this.context, PREFERENCES_NAME)
      let option = preference === ThemePreference.SYSTEM
        ? ThemeOption.SYSTEM
        : (theme === ThemeMode.DARK ? ThemeOption.DARK : ThemeOption.LIGHT)
      let saved = await pref.setMany([
        { key: KEY_THEME_MODE, value: theme },
        { key: KEY_THEME_PREFERENCE, value: preference },
        { key: KEY_THEME_OPTION, value: option }
      ])
      if (!saved) {
        LogUtils.error(TAG, 'savePreferences failed: preferences_write_failed')
      }
    } catch (err) {
      LogUtils.error(TAG, 'ThemeManager initAsync failed: %{public}s', JSON.stringify(err))
    }
  }

  private async loadLegacyThemeOption(pref: PreferencesAccessor): Promise<ThemeOption> {
    let savedPreference = await pref.getString(KEY_THEME_PREFERENCE, ThemePreference.SYSTEM) as ThemePreference
    if (savedPreference === ThemePreference.SYSTEM) {
      return ThemeOption.SYSTEM
    }
    let savedTheme = await pref.getString(KEY_THEME_MODE, ThemeMode.LIGHT) as ThemeMode
    return savedTheme === ThemeMode.DARK ? ThemeOption.DARK : ThemeOption.LIGHT
  }
}
