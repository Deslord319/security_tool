import { asset } from '@kit.AssetStoreKit'
import { util } from '@kit.ArkTS'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { ASSET_KEY_TOOL_PASSWORD } from '../models/DataModels'

const TAG = 'SecureStorageService'
const DOMAIN = 0x0005

export class SecureStorageService {

  // 保存工具密码
  static async savePassword(password: string): Promise<boolean> {
    try {
      let encoder = new util.TextEncoder()
      let passwordData = encoder.encodeInto(password)
      let aliasData = encoder.encodeInto(ASSET_KEY_TOOL_PASSWORD)

      // 先尝试查询是否已存在
      let exists = await SecureStorageService.hasPassword()

      if (exists) {
        // 更新已有密码
        let query: asset.AssetMap = new Map()
        query.set(asset.Tag.ALIAS, aliasData)

        let attrsToUpdate: asset.AssetMap = new Map()
        attrsToUpdate.set(asset.Tag.SECRET, passwordData)

        await asset.update(query, attrsToUpdate)
      } else {
        // 新增密码
        let attrs: asset.AssetMap = new Map()
        attrs.set(asset.Tag.ALIAS, aliasData)
        attrs.set(asset.Tag.SECRET, passwordData)
        attrs.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_UNLOCKED)
        attrs.set(asset.Tag.AUTH_TYPE, asset.AuthType.NONE)

        await asset.add(attrs)
      }

      hilog.info(DOMAIN, TAG, 'Password saved successfully')
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, `savePassword failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // 验证密码
  static async verifyPassword(inputPassword: string): Promise<boolean> {
    try {
      let encoder = new util.TextEncoder()
      let decoder = new util.TextDecoder()
      let aliasData = encoder.encodeInto(ASSET_KEY_TOOL_PASSWORD)

      let query: asset.AssetMap = new Map()
      query.set(asset.Tag.ALIAS, aliasData)
      query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL)

      let result = await asset.query(query)
      if (result.length === 0) {
        return false
      }

      let storedData = result[0].get(asset.Tag.SECRET) as Uint8Array
      let storedPassword = decoder.decodeToString(storedData)

      return storedPassword === inputPassword
    } catch (err) {
      hilog.error(DOMAIN, TAG, `verifyPassword failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // 检查密码是否已设置
  static async hasPassword(): Promise<boolean> {
    try {
      let encoder = new util.TextEncoder()
      let aliasData = encoder.encodeInto(ASSET_KEY_TOOL_PASSWORD)

      let query: asset.AssetMap = new Map()
      query.set(asset.Tag.ALIAS, aliasData)
      query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ATTRIBUTES)

      let result = await asset.query(query)
      return result.length > 0
    } catch (err) {
      return false
    }
  }

  // 删除密码
  static async removePassword(): Promise<boolean> {
    try {
      let encoder = new util.TextEncoder()
      let aliasData = encoder.encodeInto(ASSET_KEY_TOOL_PASSWORD)

      let query: asset.AssetMap = new Map()
      query.set(asset.Tag.ALIAS, aliasData)

      await asset.remove(query)
      hilog.info(DOMAIN, TAG, 'Password removed successfully')
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, `removePassword failed: ${JSON.stringify(err)}`)
      return false
    }
  }
}
