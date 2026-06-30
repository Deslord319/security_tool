import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import {
  DEFAULT_LOCKSCREEN_AUTH_CONFIG,
  LockScreenAuthConfig,
  PREF_KEY_LOCKSCREEN_UKEY_AUTH_ENABLED,
  PREF_STORE_NAME_LOCKSCREEN_AUTH
} from '../../../models/identity/lockscreen-auth/LockScreenAuthModels'
import { PreferencesAccessor } from '../../../storage/preferences/PreferencesAccessor'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'LockScreenAuth.Repository'

export interface LockScreenAuthRepository {
  loadConfig(context: common.Context): Promise<LockScreenAuthConfig>
  saveConfig(context: common.Context, config: LockScreenAuthConfig): Promise<boolean>
}

export class PreferencesLockScreenAuthRepository implements LockScreenAuthRepository {
  async loadConfig(context: common.Context): Promise<LockScreenAuthConfig> {
    LogUtils.info(TAG, `[LOAD_START] loadConfig | store=${PREF_STORE_NAME_LOCKSCREEN_AUTH}`)
    try {
      let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_LOCKSCREEN_AUTH)
      let config: LockScreenAuthConfig = {
        ukeyUnlockEnabled: await pref.getBoolean(
          PREF_KEY_LOCKSCREEN_UKEY_AUTH_ENABLED,
          DEFAULT_LOCKSCREEN_AUTH_CONFIG.ukeyUnlockEnabled
        )
      }
      LogUtils.info(TAG, `[LOAD_SUCCESS] loadConfig | ukeyUnlockEnabled=${config.ukeyUnlockEnabled}`)
      return config
    } catch (err) {
      let error = err as Error
      let errorCode = typeof (err as BusinessError)?.code === 'number' ? (err as BusinessError).code : -1
      let errorMessage = typeof error?.message === 'string' && error.message.length > 0 ? error.message : 'unknown'
      LogUtils.error(TAG, `[LOAD_FAIL] loadConfig | code=${errorCode}, message=${errorMessage}, fallback=default`)
      return {
        ukeyUnlockEnabled: DEFAULT_LOCKSCREEN_AUTH_CONFIG.ukeyUnlockEnabled
      }
    }
  }

  async saveConfig(context: common.Context, config: LockScreenAuthConfig): Promise<boolean> {
    LogUtils.info(TAG, `[SAVE_START] saveConfig | ukeyUnlockEnabled=${config.ukeyUnlockEnabled}`)
    try {
      let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_LOCKSCREEN_AUTH)
      let saved = await pref.setValue(PREF_KEY_LOCKSCREEN_UKEY_AUTH_ENABLED, config.ukeyUnlockEnabled)
      if (!saved) {
        LogUtils.error(TAG, '[SAVE_FAIL] saveConfig | reason=preferences_write_failed')
        return false
      }
      LogUtils.info(TAG, `[SAVE_SUCCESS] saveConfig | ukeyUnlockEnabled=${config.ukeyUnlockEnabled}`)
      return true
    } catch (err) {
      let error = err as Error
      let errorCode = typeof (err as BusinessError)?.code === 'number' ? (err as BusinessError).code : -1
      let errorMessage = typeof error?.message === 'string' && error.message.length > 0 ? error.message : 'unknown'
      LogUtils.error(TAG, `[SAVE_FAIL] saveConfig | code=${errorCode}, message=${errorMessage}`)
      return false
    }
  }
}
