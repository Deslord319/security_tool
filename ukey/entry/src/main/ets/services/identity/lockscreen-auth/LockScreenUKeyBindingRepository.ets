import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import {
  LockScreenUKeyActiveCredential,
  LockScreenUKeyBinding,
  LockScreenUKeyCredentialLifecycle,
  LockScreenUKeyUserCredential,
  PREF_KEY_LOCKSCREEN_UKEY_ACTIVE_CREDENTIAL,
  PREF_KEY_LOCKSCREEN_UKEY_BINDING,
  PREF_STORE_NAME_LOCKSCREEN_AUTH
} from '../../../models/identity/lockscreen-auth/LockScreenAuthModels'
import { PreferencesAccessor } from '../../../storage/preferences/PreferencesAccessor'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'LockScreenUKey.BindingRepo'

function isValidCredentialLifecycle(lifecycle: LockScreenUKeyCredentialLifecycle): boolean {
  return lifecycle === 'active' || lifecycle === 'failed'
}

function isValidUserCredential(credential: LockScreenUKeyUserCredential): boolean {
  return typeof credential.credentialIdHex === 'string' && credential.credentialIdHex.length > 0 &&
    typeof credential.pluginInfo === 'string' && credential.pluginInfo.length > 0 &&
    typeof credential.userId === 'number' && Number.isFinite(credential.userId) &&
    typeof credential.createdAt === 'number' && Number.isFinite(credential.createdAt) &&
    isValidCredentialLifecycle(credential.lifecycle)
}

function isValidUserCredentialList(credentials: LockScreenUKeyUserCredential[]): boolean {
  if (!Array.isArray(credentials) || credentials.length === 0) {
    return false
  }
  return credentials.every((credential: LockScreenUKeyUserCredential): boolean => {
    return isValidUserCredential(credential)
  })
}

export interface LockScreenUKeyBindingRepository {
  loadBinding(context: common.Context): Promise<LockScreenUKeyBinding | null>
  saveBinding(context: common.Context, binding: LockScreenUKeyBinding): Promise<boolean>
}

export interface LockScreenUKeyActiveCredentialRepository {
  loadActiveCredential(context: common.Context): Promise<LockScreenUKeyActiveCredential | null>
  saveActiveCredential(context: common.Context, credential: LockScreenUKeyActiveCredential): Promise<boolean>
  clearActiveCredential(context: common.Context): Promise<boolean>
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
    let validRoot = typeof binding.fingerprint === 'string' && binding.fingerprint.length > 0 &&
      typeof binding.deviceId === 'string' && binding.deviceId.length > 0 &&
      typeof binding.credentialIdHex === 'string' && binding.credentialIdHex.length > 0 &&
      typeof binding.pluginInfo === 'string' && binding.pluginInfo.length > 0 &&
      typeof binding.userId === 'number' && Number.isFinite(binding.userId)
    return validRoot && isValidUserCredentialList(binding.userCredentials)
  }
}

export class PreferencesLockScreenUKeyActiveCredentialRepository implements LockScreenUKeyActiveCredentialRepository {
  async loadActiveCredential(context: common.Context): Promise<LockScreenUKeyActiveCredential | null> {
    try {
      let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_LOCKSCREEN_AUTH)
      let credential = await pref.getJsonObject<LockScreenUKeyActiveCredential | null>(
        PREF_KEY_LOCKSCREEN_UKEY_ACTIVE_CREDENTIAL,
        null
      )
      if (!PreferencesLockScreenUKeyActiveCredentialRepository.isValidActiveCredential(credential)) {
        return null
      }
      return credential
    } catch (err) {
      let error = err as Error
      let errorCode = typeof (err as BusinessError)?.code === 'number' ? (err as BusinessError).code : -1
      let errorMessage = typeof error?.message === 'string' && error.message.length > 0 ? error.message : 'unknown'
      LogUtils.warn(TAG, `[LOAD_ACTIVE_FAIL] loadActiveCredential | code=${errorCode}, message=${errorMessage}`)
      return null
    }
  }

  async saveActiveCredential(
    context: common.Context,
    credential: LockScreenUKeyActiveCredential
  ): Promise<boolean> {
    if (!PreferencesLockScreenUKeyActiveCredentialRepository.isValidActiveCredential(credential)) {
      LogUtils.warn(TAG, '[SAVE_ACTIVE_SKIP] saveActiveCredential | reason=invalid_credential')
      return false
    }
    try {
      let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_LOCKSCREEN_AUTH)
      let saved = await pref.setJson(PREF_KEY_LOCKSCREEN_UKEY_ACTIVE_CREDENTIAL, credential)
      if (!saved) {
        LogUtils.error(TAG, '[SAVE_ACTIVE_FAIL] saveActiveCredential | reason=preferences_write_failed')
      }
      return saved
    } catch (err) {
      let error = err as Error
      let errorCode = typeof (err as BusinessError)?.code === 'number' ? (err as BusinessError).code : -1
      let errorMessage = typeof error?.message === 'string' && error.message.length > 0 ? error.message : 'unknown'
      LogUtils.error(TAG, `[SAVE_ACTIVE_FAIL] saveActiveCredential | code=${errorCode}, message=${errorMessage}`)
      return false
    }
  }

  async clearActiveCredential(context: common.Context): Promise<boolean> {
    try {
      let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_LOCKSCREEN_AUTH)
      let cleared = await pref.setValue(PREF_KEY_LOCKSCREEN_UKEY_ACTIVE_CREDENTIAL, '')
      if (!cleared) {
        LogUtils.error(TAG, '[CLEAR_ACTIVE_FAIL] clearActiveCredential | reason=preferences_write_failed')
      }
      return cleared
    } catch (err) {
      let error = err as Error
      let errorCode = typeof (err as BusinessError)?.code === 'number' ? (err as BusinessError).code : -1
      let errorMessage = typeof error?.message === 'string' && error.message.length > 0 ? error.message : 'unknown'
      LogUtils.error(TAG, `[CLEAR_ACTIVE_FAIL] clearActiveCredential | code=${errorCode}, message=${errorMessage}`)
      return false
    }
  }

  private static isValidActiveCredential(credential: LockScreenUKeyActiveCredential | null): boolean {
    if (!credential) {
      return false
    }
    let validRoot = typeof credential.credentialIdHex === 'string' && credential.credentialIdHex.length > 0 &&
      typeof credential.pluginInfo === 'string' && credential.pluginInfo.length > 0 &&
      typeof credential.fingerprint === 'string' && credential.fingerprint.length > 0 &&
      typeof credential.deviceId === 'string' && credential.deviceId.length > 0 &&
      typeof credential.userId === 'number' && Number.isFinite(credential.userId) &&
      isValidCredentialLifecycle(credential.lifecycle)
    return validRoot && isValidUserCredentialList(credential.userCredentials)
  }
}
