import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { hilog } from '@kit.PerformanceAnalysisKit'
import {
  AuthMethod,
  DEFAULT_TOOL_SETTINGS,
  PREF_KEY_AUTH_METHOD,
  PREF_KEY_STARTUP_AUTH,
  PREF_STORE_NAME_TOOL,
  ToolSettingsConfig
} from '../models/DataModels'

const TAG = 'ToolSettings.Repository'
const DOMAIN = 0x0014

interface ToolSettingsLoggableError {
  code?: number
  message?: string
}

export interface ToolSettingsRepository {
  loadConfig(context: common.UIAbilityContext): Promise<ToolSettingsConfig>
  saveConfig(context: common.UIAbilityContext, config: ToolSettingsConfig): Promise<void>
}

export class PreferencesToolSettingsRepository implements ToolSettingsRepository {
  async loadConfig(context: common.UIAbilityContext): Promise<ToolSettingsConfig> {
    hilog.info(DOMAIN, TAG, `[LOAD_START] loadConfig | store=${PREF_STORE_NAME_TOOL}`)
    try {
      let store = await preferences.getPreferences(context, PREF_STORE_NAME_TOOL)
      let startupAuthRaw = await store.get(PREF_KEY_STARTUP_AUTH, DEFAULT_TOOL_SETTINGS.startupAuthEnabled)
      let authMethodRaw = await store.get(PREF_KEY_AUTH_METHOD, DEFAULT_TOOL_SETTINGS.authMethod)
      let config: ToolSettingsConfig = {
        startupAuthEnabled: this.normalizeStartupAuthEnabled(startupAuthRaw),
        authMethod: this.normalizeAuthMethod(authMethodRaw)
      }
      hilog.info(
        DOMAIN,
        TAG,
        `[LOAD_SUCCESS] loadConfig | startupAuthEnabled=${config.startupAuthEnabled}, authMethod=${config.authMethod}`
      )
      return config
    } catch (err) {
      let errorCode = this.getErrorCode(err)
      let errorMessage = this.getErrorMessage(err)
      hilog.error(
        DOMAIN,
        TAG,
        `[LOAD_FAIL] loadConfig | code=${errorCode}, message=${errorMessage}, fallback=default`
      )
      return this.cloneConfig(DEFAULT_TOOL_SETTINGS)
    }
  }

  async saveConfig(context: common.UIAbilityContext, config: ToolSettingsConfig): Promise<void> {
    let normalizedConfig = this.cloneConfig(config)
    hilog.info(
      DOMAIN,
      TAG,
      `[SAVE_START] saveConfig | startupAuthEnabled=${normalizedConfig.startupAuthEnabled}, authMethod=${normalizedConfig.authMethod}`
    )
    try {
      let store = await preferences.getPreferences(context, PREF_STORE_NAME_TOOL)
      await store.put(PREF_KEY_STARTUP_AUTH, normalizedConfig.startupAuthEnabled)
      await store.put(PREF_KEY_AUTH_METHOD, normalizedConfig.authMethod)
      await store.flush()
      hilog.info(
        DOMAIN,
        TAG,
        `[SAVE_SUCCESS] saveConfig | startupAuthEnabled=${normalizedConfig.startupAuthEnabled}, authMethod=${normalizedConfig.authMethod}`
      )
    } catch (err) {
      let errorCode = this.getErrorCode(err)
      let errorMessage = this.getErrorMessage(err)
      hilog.error(
        DOMAIN,
        TAG,
        `[SAVE_FAIL] saveConfig | code=${errorCode}, message=${errorMessage}`
      )
      throw new Error(errorMessage)
    }
  }

  // Tool Settings is consumed by both the page and EntryAbility, so normalization
  // lives in the repository to keep both callers on the same config baseline.
  private cloneConfig(config: ToolSettingsConfig): ToolSettingsConfig {
    return {
      startupAuthEnabled: config.startupAuthEnabled,
      authMethod: config.authMethod
    }
  }

  private normalizeStartupAuthEnabled(value: Object): boolean {
    if (typeof value === 'boolean') {
      return value
    }
    if (typeof value === 'number') {
      return value !== 0
    }
    if (typeof value === 'string') {
      let normalized = value.trim().toLowerCase()
      return normalized === 'true' || normalized === '1' || normalized === 'yes'
    }
    return DEFAULT_TOOL_SETTINGS.startupAuthEnabled
  }

  private normalizeAuthMethod(value: Object): AuthMethod {
    if (value === AuthMethod.PIN) {
      return AuthMethod.PIN
    }
    if (value === AuthMethod.FINGERPRINT) {
      return AuthMethod.FINGERPRINT
    }
    if (typeof value === 'number') {
      return value === AuthMethod.FINGERPRINT ? AuthMethod.FINGERPRINT : AuthMethod.PIN
    }
    return DEFAULT_TOOL_SETTINGS.authMethod
  }

  private getErrorCode(err: Object): number | string {
    let error = err as ToolSettingsLoggableError
    if (typeof error?.code === 'number') {
      return error.code
    }
    return 'unknown'
  }

  private getErrorMessage(err: Object): string {
    let error = err as ToolSettingsLoggableError
    if (typeof error?.message === 'string' && error.message.length > 0) {
      return error.message
    }
    return 'unknown'
  }
}
