import { LogUtils } from '../../../utils/LogUtils'
import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { PreferencesAccessor } from '../../../storage/preferences/PreferencesAccessor'

import { AuthMethod } from '../../../models/AuthModels'
import {
  DEFAULT_TOOL_SETTINGS,
  PREF_KEY_AUTH_METHOD,
  PREF_KEY_STARTUP_AUTH,
  PREF_STORE_NAME_TOOL,
  ToolSettingsConfig
} from '../../../models/ToolSettingsModels'

const TAG = 'ToolSettings.Repository'

export interface ToolSettingsRepository {
  loadConfig(context: common.UIAbilityContext): Promise<ToolSettingsConfig>
  saveConfig(context: common.UIAbilityContext, config: ToolSettingsConfig): Promise<boolean>
}

export class PreferencesToolSettingsRepository implements ToolSettingsRepository {
  async loadConfig(context: common.UIAbilityContext): Promise<ToolSettingsConfig> {
    LogUtils.info(TAG, `[LOAD_START] loadConfig | store=${PREF_STORE_NAME_TOOL}`)
    try {
      let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_TOOL)
      let config: ToolSettingsConfig = {
        startupAuthEnabled: await pref.getBoolean(PREF_KEY_STARTUP_AUTH, DEFAULT_TOOL_SETTINGS.startupAuthEnabled),
        authMethod: this.normalizeAuthMethod(
          await pref.getNumber(PREF_KEY_AUTH_METHOD, DEFAULT_TOOL_SETTINGS.authMethod)
        )
      }
      LogUtils.info(TAG,
        `[LOAD_SUCCESS] loadConfig | startupAuthEnabled=${config.startupAuthEnabled}, authMethod=${config.authMethod}`
      )
      return config
    } catch (err) {
      let error = err as Error
      let errorCode = typeof (err as BusinessError)?.code === 'number' ? (err as BusinessError).code : -1
      let errorMessage = typeof error?.message === 'string' && error.message.length > 0 ? error.message : 'unknown'
      LogUtils.error(TAG, `[LOAD_FAIL] loadConfig | code=${errorCode}, message=${errorMessage}, fallback=default`)
      return {
        startupAuthEnabled: DEFAULT_TOOL_SETTINGS.startupAuthEnabled,
        authMethod: DEFAULT_TOOL_SETTINGS.authMethod
      }
    }
  }

  async saveConfig(context: common.UIAbilityContext, config: ToolSettingsConfig): Promise<boolean> {
    LogUtils.info(TAG,
      `[SAVE_START] saveConfig | startupAuthEnabled=${config.startupAuthEnabled}, authMethod=${config.authMethod}`
    )
    try {
      let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_TOOL)
      let saved = await pref.setMany([
        { key: PREF_KEY_STARTUP_AUTH, value: config.startupAuthEnabled },
        { key: PREF_KEY_AUTH_METHOD, value: config.authMethod }
      ])
      if (!saved) {
        LogUtils.error(TAG, '[SAVE_FAIL] saveConfig | reason=preferences_write_failed')
        return false
      }
      LogUtils.info(TAG,
        `[SAVE_SUCCESS] saveConfig | startupAuthEnabled=${config.startupAuthEnabled}, authMethod=${config.authMethod}`
      )
      return true
    } catch (err) {
      let error = err as Error
      let errorCode = typeof (err as BusinessError)?.code === 'number' ? (err as BusinessError).code : -1
      let errorMessage = typeof error?.message === 'string' && error.message.length > 0 ? error.message : 'unknown'
      LogUtils.error(TAG, `[SAVE_FAIL] saveConfig | code=${errorCode}, message=${errorMessage}`)
      return false
    }
  }

  private normalizeAuthMethod(value: number): AuthMethod {
    if (value === AuthMethod.PIN) {
      return AuthMethod.PIN
    }
    if (value === AuthMethod.FINGERPRINT) {
      return AuthMethod.FINGERPRINT
    }
    return DEFAULT_TOOL_SETTINGS.authMethod
  }
}
