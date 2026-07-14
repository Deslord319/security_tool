import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { PREF_STORE_NAME_LOCKSCREEN_AUTH } from '../../models/identity/lockscreen-auth/LockScreenAuthModels'
import { LogUtils } from '../../utils/LogUtils'

type PrefScalar = string | number | boolean

export interface PrefStringReadResult {
  success: boolean
  value: string
}

const TAG = 'LockScreenAuthPreferences'

export class LockScreenAuthPreferences {
  private context: common.Context

  private constructor(context: common.Context) {
    this.context = context
  }

  static async get(context: common.Context): Promise<LockScreenAuthPreferences | null> {
    if (!preferences.isStorageTypeSupported(preferences.StorageType.GSKV)) {
      LogUtils.error(TAG, '[GSKV_INIT_FAIL] GSKV is not supported')
      return null
    }
    let accessor = new LockScreenAuthPreferences(context)
    if (!await accessor.isAvailable()) {
      LogUtils.error(TAG, '[GSKV_INIT_FAIL] shared lockscreen auth store is unavailable')
      return null
    }
    return accessor
  }

  private async store(): Promise<preferences.Preferences | null> {
    try {
      let options: preferences.Options = {
        name: PREF_STORE_NAME_LOCKSCREEN_AUTH,
        storageType: preferences.StorageType.GSKV
      }
      return await preferences.getPreferences(this.context, options)
    } catch (err) {
      LogUtils.error(TAG, `getPreferences failed: err=${JSON.stringify(err)}`)
      return null
    }
  }

  private async isAvailable(): Promise<boolean> {
    return await this.store() !== null
  }

  private async getString(key: string, defaultValue: string): Promise<string> {
    let result = await this.getStringResult(key, defaultValue)
    return result.success ? result.value : defaultValue
  }

  async getStringResult(key: string, defaultValue: string): Promise<PrefStringReadResult> {
    let store = await this.store()
    if (!store) {
      return { success: false, value: defaultValue }
    }
    try {
      let raw = await store.get(key, defaultValue)
      return {
        success: true,
        value: typeof raw === 'string' ? raw : defaultValue
      }
    } catch (err) {
      LogUtils.error(TAG, `getString failed: key=${key}, err=${JSON.stringify(err)}`)
      return { success: false, value: defaultValue }
    }
  }

  async getBoolean(key: string, defaultValue: boolean): Promise<boolean> {
    let store = await this.store()
    if (!store) {
      return defaultValue
    }
    try {
      let raw = await store.get(key, defaultValue)
      return typeof raw === 'boolean' ? raw : defaultValue
    } catch (err) {
      LogUtils.error(TAG, `getBoolean failed: key=${key}, err=${JSON.stringify(err)}`)
      return defaultValue
    }
  }

  async getJsonObject<T>(key: string, defaultValue: T): Promise<T> {
    let raw = await this.getString(key, '')
    if (raw.length === 0) {
      return defaultValue
    }
    try {
      let parsed: Object = JSON.parse(raw) as Object
      return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed as T : defaultValue
    } catch (err) {
      LogUtils.error(TAG, `getJsonObject failed: key=${key}, err=${JSON.stringify(err)}`)
      return defaultValue
    }
  }

  async setValue(key: string, value: PrefScalar): Promise<boolean> {
    let store = await this.store()
    if (!store) {
      return false
    }
    try {
      await store.put(key, value)
      return true
    } catch (err) {
      LogUtils.error(TAG, `setValue failed: key=${key}, err=${JSON.stringify(err)}`)
      return false
    }
  }

  async setJson(key: string, value: object): Promise<boolean> {
    return this.setValue(key, JSON.stringify(value))
  }
}
