import { common } from '@kit.AbilityKit'

import {
  FirewallUserApplyMode,
  PREF_KEY_FIREWALL_USER_BINDINGS,
  PREF_STORE_NAME_FIREWALL_USER_BINDINGS,
  UserFirewallModeBinding
} from '../../../models/DataModels'
import { LogUtils } from '../../../utils/LogUtils'
import { PreferencesAccessor } from '../../../storage/preferences/PreferencesAccessor'

const TAG = 'FirewallUserBindingsRepository'

export class FirewallUserBindingsRepository {
  // 仅保存用户历史模式记录：userId -> allowlist / denylist。
  // 不承载规则 binding、模板联动或规则重放语义。
  static async loadBindings(context: common.UIAbilityContext): Promise<UserFirewallModeBinding[]> {
    try {
      let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_FIREWALL_USER_BINDINGS)
      let parsed = await pref.getJsonArray<UserFirewallModeBinding>(PREF_KEY_FIREWALL_USER_BINDINGS, [])
      return parsed.filter((item: UserFirewallModeBinding): boolean => {
        return typeof item.userId === 'number' &&
          (item.mode === 'allowlist' || item.mode === 'denylist')
      })
    } catch (err) {
      LogUtils.error(TAG, `loadBindings failed: ${JSON.stringify(err)}`)
      return []
    }
  }

  static async saveBindings(
    context: common.UIAbilityContext,
    bindings: UserFirewallModeBinding[]
  ): Promise<boolean> {
    try {
      let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_FIREWALL_USER_BINDINGS)
      return await pref.setJson(PREF_KEY_FIREWALL_USER_BINDINGS, bindings)
    } catch (err) {
      LogUtils.error(TAG, `saveBindings failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static async getBindingMode(
    context: common.UIAbilityContext,
    userId: number
  ): Promise<FirewallUserApplyMode | undefined> {
    // 读取用户历史模式记录，用于后续恢复完整 policy。
    let bindings = await FirewallUserBindingsRepository.loadBindings(context)
    let matched = bindings.find((item: UserFirewallModeBinding): boolean => item.userId === userId)
    return matched?.mode
  }

  static async saveBindingMode(
    context: common.UIAbilityContext,
    userId: number,
    mode: FirewallUserApplyMode
  ): Promise<boolean> {
    // 只更新该用户的历史模式记录，不触发任何规则联动。
    let bindings = await FirewallUserBindingsRepository.loadBindings(context)
    let nextBindings = bindings.filter((item: UserFirewallModeBinding): boolean => item.userId !== userId)
    nextBindings.push({
      userId: userId,
      mode: mode
    })
    return FirewallUserBindingsRepository.saveBindings(context, nextBindings)
  }
}
