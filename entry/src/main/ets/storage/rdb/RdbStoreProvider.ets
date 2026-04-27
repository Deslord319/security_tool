import relationalStore from '@ohos.data.relationalStore'
import { common } from '@kit.AbilityKit'
import { LogUtils } from '../../utils/LogUtils'
import { DatabaseVersionManager } from './DatabaseVersionManager'

const TAG = 'RdbStoreProvider'

export class RdbStoreProvider {
  private static stores: Map<string, relationalStore.RdbStore> = new Map()
  private static pendingPromises: Map<string, Promise<relationalStore.RdbStore | null>> = new Map()

  static async getStore(
    context: common.UIAbilityContext,
    name: string
  ): Promise<relationalStore.RdbStore | null> {
    let version = DatabaseVersionManager.getVersion(name)
    let key = `${context.filesDir || ''}::${name}::v${version}`
    let cached = RdbStoreProvider.stores.get(key)
    if (cached) {
      return cached
    }
    let pending = RdbStoreProvider.pendingPromises.get(key)
    if (pending) {
      return pending
    }
    let promise = RdbStoreProvider.createStore(context, name, key)
    RdbStoreProvider.pendingPromises.set(key, promise)
    let result = await promise
    RdbStoreProvider.pendingPromises.delete(key)
    return result
  }

  private static async createStore(
    context: common.UIAbilityContext,
    name: string,
    key: string
  ): Promise<relationalStore.RdbStore | null> {
    try {
      let config: relationalStore.StoreConfig = DatabaseVersionManager.buildConfig(name)
      let store = await relationalStore.getRdbStore(context, config)
      RdbStoreProvider.stores.set(key, store)
      return store
    } catch (err) {
      LogUtils.error(TAG, `getStore failed: name=${name}, err=${JSON.stringify(err)}`)
      return null
    }
  }
}
