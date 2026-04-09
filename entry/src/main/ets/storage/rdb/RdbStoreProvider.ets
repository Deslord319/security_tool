import relationalStore from '@ohos.data.relationalStore'
import { common } from '@kit.AbilityKit'
import { LogUtils } from '../../utils/LogUtils'
import { DatabaseVersionManager } from './DatabaseVersionManager'

const TAG = 'RdbStoreProvider'

export class RdbStoreProvider {
  private static stores: Map<string, relationalStore.RdbStore> = new Map()

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
