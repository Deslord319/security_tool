import { common } from '@kit.AbilityKit'
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
import { ErrorUtils } from '../../../utils/ErrorUtils'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'LockScreenUKey.BindingRepo'

export function canUpdateUKeyBinding(
  existing: LockScreenUKeyBinding | null,
  incoming: LockScreenUKeyBinding
): boolean {
  return existing === null || existing.fingerprint === incoming.fingerprint
}

function isValidCredentialLifecycle(lifecycle: LockScreenUKeyCredentialLifecycle): boolean {
  return lifecycle === 'active' || lifecycle === 'inactive' || lifecycle === 'failed'
}

function isValidUserCredential(credential: LockScreenUKeyUserCredential): boolean {
  return typeof credential.credentialIdHex === 'string' && credential.credentialIdHex.length > 0 &&
    typeof credential.templateId === 'string' && credential.templateId.length > 0 &&
    typeof credential.pluginInfo === 'string' && credential.pluginInfo.length > 0 &&
    typeof credential.userId === 'number' && Number.isFinite(credential.userId) &&
    typeof credential.createdAt === 'number' && Number.isFinite(credential.createdAt) &&
    isValidCredentialLifecycle(credential.lifecycle)
}

function isValidUserCredentialList(credentials: LockScreenUKeyUserCredential[], allowEmpty: boolean = false): boolean {
  if (!Array.isArray(credentials)) {
    return false
  }
  if (credentials.length === 0) {
    return allowEmpty
  }
  return credentials.every((credential: LockScreenUKeyUserCredential): boolean => {
    return isValidUserCredential(credential)
  })
}

function isValidActiveUserCredentialList(credentials: LockScreenUKeyUserCredential[]): boolean {
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
      let info = ErrorUtils.toBusinessErrorInfo(err)
      LogUtils.warn(TAG, `[LOAD_FAIL] loadBinding | code=${info.code}, message=${info.message}`)
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
      let stored = await pref.getStringResult(PREF_KEY_LOCKSCREEN_UKEY_BINDING, '')
      if (!stored.success) {
        LogUtils.error(TAG, '[SAVE_REJECT] saveBinding | reason=existing_binding_unreadable')
        return false
      }
      let existing: LockScreenUKeyBinding | null = null
      if (stored.value.length > 0) {
        try {
          existing = JSON.parse(stored.value) as LockScreenUKeyBinding
        } catch (err) {
          LogUtils.error(TAG, `[SAVE_REJECT] saveBinding | reason=existing_binding_malformed, err=${JSON.stringify(err)}`)
          return false
        }
        if (!PreferencesLockScreenUKeyBindingRepository.isValidBinding(existing)) {
          LogUtils.error(TAG, '[SAVE_REJECT] saveBinding | reason=existing_binding_invalid')
          return false
        }
      }
      if (!canUpdateUKeyBinding(existing, binding)) {
        LogUtils.error(TAG,
          `[SAVE_REJECT] saveBinding | reason=immutable_fingerprint, existing=${existing?.fingerprint ?? '-'}, incoming=${binding.fingerprint}`)
        return false
      }
      let saved = await pref.setJson(PREF_KEY_LOCKSCREEN_UKEY_BINDING, binding)
      if (!saved) {
        LogUtils.error(TAG, '[SAVE_FAIL] saveBinding | reason=preferences_write_failed')
      }
      return saved
    } catch (err) {
      let info = ErrorUtils.toBusinessErrorInfo(err)
      LogUtils.error(TAG, `[SAVE_FAIL] saveBinding | code=${info.code}, message=${info.message}`)
      return false
    }
  }

  private static isValidBinding(binding: LockScreenUKeyBinding | null): boolean {
    if (!binding) {
      return false
    }
    let validRoot = typeof binding.fingerprint === 'string' && binding.fingerprint.length > 0 &&
      typeof binding.deviceId === 'string' && binding.deviceId.length > 0
    return validRoot && isValidUserCredentialList(binding.userCredentials, true)
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
      let info = ErrorUtils.toBusinessErrorInfo(err)
      LogUtils.warn(TAG, `[LOAD_ACTIVE_FAIL] loadActiveCredential | code=${info.code}, message=${info.message}`)
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
      let info = ErrorUtils.toBusinessErrorInfo(err)
      LogUtils.error(TAG, `[SAVE_ACTIVE_FAIL] saveActiveCredential | code=${info.code}, message=${info.message}`)
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
      let info = ErrorUtils.toBusinessErrorInfo(err)
      LogUtils.error(TAG, `[CLEAR_ACTIVE_FAIL] clearActiveCredential | code=${info.code}, message=${info.message}`)
      return false
    }
  }

  private static isValidActiveCredential(credential: LockScreenUKeyActiveCredential | null): boolean {
    if (!credential) {
      return false
    }
    let validRoot = typeof credential.fingerprint === 'string' && credential.fingerprint.length > 0 &&
      typeof credential.deviceId === 'string' && credential.deviceId.length > 0 &&
      isValidCredentialLifecycle(credential.lifecycle)
    return validRoot && isValidActiveUserCredentialList(credential.userCredentials)
  }
}
