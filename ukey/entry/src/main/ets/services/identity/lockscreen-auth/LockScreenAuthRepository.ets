import { common } from '@kit.AbilityKit'
import {
  DEFAULT_LOCKSCREEN_AUTH_CONFIG,
  LockScreenAuthConfig,
  PREF_KEY_LOCKSCREEN_UKEY_AUTH_ENABLED,
  PREF_STORE_NAME_LOCKSCREEN_AUTH
} from '../../../models/identity/lockscreen-auth/LockScreenAuthModels'
import { PreferencesAccessor } from '../../../storage/preferences/PreferencesAccessor'
import { ErrorUtils } from '../../../utils/ErrorUtils'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'LockScreenAuth.Repository'

export interface LockScreenAuthRepository {
  loadConfig(context: common.Context): Promise<LockScreenAuthConfig>
  saveConfig(context: common.Context, config: LockScreenAuthConfig): Promise<boolean>
}

export class PreferencesLockScreenAuthRepository implements LockScreenAuthRepository {
  async loadConfig(context: common.Context): Promise<LockScreenAuthConfig> {
    try {
      let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_LOCKSCREEN_AUTH)
      let config: LockScreenAuthConfig = {
        ukeyUnlockEnabled: await pref.getBoolean(
          PREF_KEY_LOCKSCREEN_UKEY_AUTH_ENABLED,
          DEFAULT_LOCKSCREEN_AUTH_CONFIG.ukeyUnlockEnabled
        )
      }
      return config
    } catch (err) {
      let info = ErrorUtils.toBusinessErrorInfo(err)
      LogUtils.error(TAG, `[LOAD_FAIL] loadConfig | code=${info.code}, message=${info.message}, fallback=default`)
      return {
        ukeyUnlockEnabled: DEFAULT_LOCKSCREEN_AUTH_CONFIG.ukeyUnlockEnabled
      }
    }
  }

  async saveConfig(context: common.Context, config: LockScreenAuthConfig): Promise<boolean> {
    try {
      let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_LOCKSCREEN_AUTH)
      let saved = await pref.setValue(PREF_KEY_LOCKSCREEN_UKEY_AUTH_ENABLED, config.ukeyUnlockEnabled)
      if (!saved) {
        LogUtils.error(TAG, '[SAVE_FAIL] saveConfig | reason=preferences_write_failed')
        return false
      }
      return true
    } catch (err) {
      let info = ErrorUtils.toBusinessErrorInfo(err)
      LogUtils.error(TAG, `[SAVE_FAIL] saveConfig | code=${info.code}, message=${info.message}`)
      return false
    }
  }
}
