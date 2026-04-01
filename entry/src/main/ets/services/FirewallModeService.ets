import { LogUtils } from './utils/LogUtils'
import { preferences } from '@kit.ArkData'
import { netFirewall } from '@kit.NetworkKit'

import {
  FirewallModeSwitchResult,
  FirewallPresetMode,
  PREF_KEY_FIREWALL_ACTIVE_MODE,
  PREF_STORE_NAME_FIREWALL_MODE
} from '../models/DataModels'
import { FirewallCustomRuleService } from './FirewallCustomRuleService'
import { FirewallPresetService } from './FirewallPresetService'
import { FirewallService } from './FirewallService'

const TAG = 'FirewallModeService'
const DOMAIN = 0x0013

export class FirewallModeService {
  static async initialize(context: common.UIAbilityContext): Promise<void> {
    let storedModeValue = await FirewallModeService.getStoredModeValue(context)
    if (storedModeValue.length > 0) {
      return
    }
    let currentRules = await FirewallService.getAllRules()
    await FirewallCustomRuleService.initializeFromSystemIfEmpty(context, currentRules)
    await FirewallModeService.saveCurrentMode(context, 'custom')
  }

  static async getCurrentMode(context: common.UIAbilityContext): Promise<FirewallPresetMode> {
    let storedModeValue = await FirewallModeService.getStoredModeValue(context)
    if (storedModeValue === 'public' || storedModeValue === 'private' || storedModeValue === 'custom') {
      return storedModeValue
    }
    return 'custom'
  }

  static async switchMode(
    context: common.UIAbilityContext,
    targetMode: FirewallPresetMode
  ): Promise<FirewallModeSwitchResult> {
    await FirewallModeService.initialize(context)
    let targetRules = targetMode === 'custom'
      ? await FirewallCustomRuleService.buildRulesForApply(context)
      : await FirewallPresetService.buildRules(context, targetMode)
    LogUtils.info(TAG, `switchMode prepared: targetMode=${targetMode}, ruleCount=${targetRules.length}`)
    return FirewallModeService.applyModeRules(context, targetMode, targetRules)
  }

  static async applyCustomRules(
    context: common.UIAbilityContext,
    rules: netFirewall.NetFirewallRule[]
  ): Promise<FirewallModeSwitchResult> {
    await FirewallModeService.initialize(context)
    return FirewallModeService.applyModeRules(context, 'custom', rules)
  }

  private static async getStoredModeValue(context: common.UIAbilityContext): Promise<string> {
    try {
      let store = await preferences.getPreferences(context, PREF_STORE_NAME_FIREWALL_MODE)
      let rawValue = await store.get(PREF_KEY_FIREWALL_ACTIVE_MODE, '')
      return typeof rawValue === 'string' ? rawValue : ''
    } catch (err) {
      LogUtils.error(TAG, `getStoredModeValue failed: ${JSON.stringify(err)}`)
      return ''
    }
  }

  private static async saveCurrentMode(context: common.UIAbilityContext, mode: FirewallPresetMode): Promise<void> {
    try {
      let store = await preferences.getPreferences(context, PREF_STORE_NAME_FIREWALL_MODE)
      await store.put(PREF_KEY_FIREWALL_ACTIVE_MODE, mode)
      await store.flush()
    } catch (err) {
      LogUtils.error(TAG, `saveCurrentMode failed: ${JSON.stringify(err)}`)
    }
  }

  private static async applyModeRules(
    context: common.UIAbilityContext,
    targetMode: FirewallPresetMode,
    targetRules: netFirewall.NetFirewallRule[]
  ): Promise<FirewallModeSwitchResult> {
    LogUtils.info(TAG, `applyModeRules start: targetMode=${targetMode}, ruleCount=${targetRules.length}`)
    let applied = await FirewallService.applyRuleSet(targetRules, targetMode)
    if (!applied) {
      LogUtils.error(TAG,
        `applyModeRules failed: targetMode=${targetMode}, errorCode=${FirewallService.getLastErrorCode() ?? -1}`
      )
      return {
        success: false,
        mode: targetMode,
        appliedRuleCount: 0,
        errorCode: FirewallService.getLastErrorCode(),
        errorMessage: FirewallService.getLastErrorText()
      }
    }
    await FirewallModeService.saveCurrentMode(context, targetMode)
    LogUtils.info(TAG, `applyModeRules success: targetMode=${targetMode}, appliedRuleCount=${targetRules.length}`)
    return {
      success: true,
      mode: targetMode,
      appliedRuleCount: targetRules.length
    }
  }
}
