import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import {
  LockScreenUKeyBinding,
  PREF_KEY_LOCKSCREEN_UKEY_BINDING,
  PREF_STORE_NAME_LOCKSCREEN_AUTH
} from '../../../models/identity/lockscreen-auth/LockScreenAuthModels'
import { PreferencesAccessor } from '../../../storage/preferences/PreferencesAccessor'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'LockScreenUKey.BindingRepo'

export interface LockScreenUKeyBindingRepository {
  loadBinding(context: common.Context): Promise<LockScreenUKeyBinding | null>
  saveBinding(context: common.Context, binding: LockScreenUKeyBinding): Promise<boolean>
}

export class PreferencesLockScreenUKeyBindingRepository implements LockScreenUKeyBindingRepository {
  async loadBinding(context: common.Context): Promise<LockScreenUKeyBinding | null> {
    try {
      let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_LOCKSCREEN_AUTH)
      let binding = await pref.getJsonObject<LockScreenUKeyBinding | null>(
        PREF_KEY_LOCKSCREEN_UKEY_BINDING,
        null
      )
      if (!PreferencesLockScreenUKeyBindingRepository.isValidBinding(binding)) {
        return null
      }
      return binding
    } catch (err) {
      let error = err as Error
      let errorCode = typeof (err as BusinessError)?.code === 'number' ? (err as BusinessError).code : -1
      let errorMessage = typeof error?.message === 'string' && error.message.length > 0 ? error.message : 'unknown'
      LogUtils.warn(TAG, `[LOAD_FAIL] loadBinding | code=${errorCode}, message=${errorMessage}`)
      return null
    }
  }

  async saveBinding(context: common.Context, binding: LockScreenUKeyBinding): Promise<boolean> {
    if (!PreferencesLockScreenUKeyBindingRepository.isValidBinding(binding)) {
      LogUtils.warn(TAG, '[SAVE_SKIP] saveBinding | reason=invalid_binding')
      return false
    }
    try {
      let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_LOCKSCREEN_AUTH)
      let saved = await pref.setJson(PREF_KEY_LOCKSCREEN_UKEY_BINDING, binding)
      if (!saved) {
        LogUtils.error(TAG, '[SAVE_FAIL] saveBinding | reason=preferences_write_failed')
      }
      return saved
    } catch (err) {
      let error = err as Error
      let errorCode = typeof (err as BusinessError)?.code === 'number' ? (err as BusinessError).code : -1
      let errorMessage = typeof error?.message === 'string' && error.message.length > 0 ? error.message : 'unknown'
      LogUtils.error(TAG, `[SAVE_FAIL] saveBinding | code=${errorCode}, message=${errorMessage}`)
      return false
    }
  }

  private static isValidBinding(binding: LockScreenUKeyBinding | null): boolean {
    if (!binding) {
      return false
    }
    return typeof binding.fingerprint === 'string' && binding.fingerprint.length > 0 &&
      typeof binding.deviceId === 'string' && binding.deviceId.length > 0 &&
      typeof binding.credentialIdHex === 'string' && binding.credentialIdHex.length > 0 &&
      typeof binding.pluginInfo === 'string' && binding.pluginInfo.length > 0 &&
      typeof binding.userId === 'number' && Number.isFinite(binding.userId)
  }
}
