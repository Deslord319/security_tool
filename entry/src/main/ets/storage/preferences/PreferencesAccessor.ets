import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { LogUtils } from '../../utils/LogUtils'

type PrefScalar = string | number | boolean

interface PrefWriteItem {
  key: string
  value: PrefScalar
}

const TAG = 'PreferencesAccessor'

export class PreferencesAccessor {
  private static cache: Map<string, preferences.Preferences> = new Map()
  private static pendingPromises: Map<string, Promise<preferences.Preferences | null>> = new Map()
  private context: common.Context
  private storeName: string

  private constructor(context: common.Context, storeName: string) {
    this.context = context
    this.storeName = storeName
  }

  static of(context: common.Context, storeName: string): PreferencesAccessor {
    return new PreferencesAccessor(context, storeName)
  }

  private cacheKey(): string {
    return `${this.context.filesDir || ''}::${this.storeName}`
  }

  private async store(): Promise<preferences.Preferences | null> {
    let key = this.cacheKey()
    let cached = PreferencesAccessor.cache.get(key)
    if (cached) {
      return cached
    }
    let pending = PreferencesAccessor.pendingPromises.get(key)
    if (pending) {
      return pending
    }
    let promise = this.createStore(key)
    PreferencesAccessor.pendingPromises.set(key, promise)
    let result = await promise
    PreferencesAccessor.pendingPromises.delete(key)
    return result
  }

  private async createStore(key: string): Promise<preferences.Preferences | null> {
    try {
      let instance = await preferences.getPreferences(this.context, this.storeName)
      PreferencesAccessor.cache.set(key, instance)
      return instance
    } catch (err) {
      LogUtils.error(TAG, `getPreferences failed: store=${this.storeName}, err=${JSON.stringify(err)}`)
      return null
    }
  }

  async getString(key: string, defaultValue: string): Promise<string> {
    let store = await this.store()
    if (!store) {
      return defaultValue
    }
    try {
      let raw = await store.get(key, defaultValue)
      return typeof raw === 'string' ? raw : defaultValue
    } catch (err) {
      LogUtils.error(TAG, `getString failed: store=${this.storeName}, key=${key}, err=${JSON.stringify(err)}`)
      return defaultValue
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
      LogUtils.error(TAG, `getBoolean failed: store=${this.storeName}, key=${key}, err=${JSON.stringify(err)}`)
      return defaultValue
    }
  }

  async getNumber(key: string, defaultValue: number): Promise<number> {
    let store = await this.store()
    if (!store) {
      return defaultValue
    }
    try {
      let raw = await store.get(key, defaultValue)
      if (typeof raw === 'number' && Number.isFinite(raw)) {
        return raw
      }
      if (typeof raw === 'string') {
        let parsed = Number(raw)
        if (Number.isFinite(parsed)) {
          return parsed
        }
      }
      return defaultValue
    } catch (err) {
      LogUtils.error(TAG, `getNumber failed: store=${this.storeName}, key=${key}, err=${JSON.stringify(err)}`)
      return defaultValue
    }
  }

  async getJsonArray<T>(key: string, defaultValue: T[]): Promise<T[]> {
    let raw = await this.getString(key, '[]')
    try {
      let parsed: Object = JSON.parse(raw) as Object
      return Array.isArray(parsed) ? parsed as T[] : defaultValue
    } catch (err) {
      LogUtils.error(TAG, `getJsonArray failed: store=${this.storeName}, key=${key}, err=${JSON.stringify(err)}`)
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
      LogUtils.error(TAG, `getJsonObject failed: store=${this.storeName}, key=${key}, err=${JSON.stringify(err)}`)
      return defaultValue
    }
  }

  async setValue(key: string, value: PrefScalar, flush: boolean = true): Promise<boolean> {
    let store = await this.store()
    if (!store) {
      return false
    }
    try {
      await store.put(key, value)
      if (flush) {
        await store.flush()
      }
      return true
    } catch (err) {
      LogUtils.error(TAG, `setValue failed: store=${this.storeName}, key=${key}, err=${JSON.stringify(err)}`)
      return false
    }
  }

  async setJson(key: string, value: object | object[], flush: boolean = true): Promise<boolean> {
    return this.setValue(key, JSON.stringify(value), flush)
  }

  async setMany(items: PrefWriteItem[], flush: boolean = true): Promise<boolean> {
    let store = await this.store()
    if (!store) {
      return false
    }
    try {
      for (let item of items) {
        await store.put(item.key, item.value)
      }
      if (flush) {
        await store.flush()
      }
      return true
    } catch (err) {
      LogUtils.error(TAG, `setMany failed: store=${this.storeName}, err=${JSON.stringify(err)}`)
      return false
    }
  }

  async flush(): Promise<boolean> {
    let store = await this.store()
    if (!store) {
      return false
    }
    try {
      await store.flush()
      return true
    } catch (err) {
      LogUtils.error(TAG, `flush failed: store=${this.storeName}, err=${JSON.stringify(err)}`)
      return false
    }
  }
}
