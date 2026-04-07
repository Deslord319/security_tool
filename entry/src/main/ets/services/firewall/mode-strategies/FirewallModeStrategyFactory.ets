import { LogUtils } from '../../../utils/LogUtils'
import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { netFirewall } from '@kit.NetworkKit'

import {
  FirewallModeSwitchResult,
  FirewallPresetMode,
  PREF_KEY_FIREWALL_ACTIVE_MODE,
  PREF_STORE_NAME_FIREWALL_MODE
} from '../../../models/DataModels'
import { FirewallRepository } from '../repositories/FirewallRepository'
import { CustomModeStrategy } from './CustomModeStrategy'
import { FirewallModeStrategy } from './FirewallModeStrategy'
import { PrivateModeStrategy } from './PrivateModeStrategy'
import { PublicModeStrategy } from './PublicModeStrategy'

const TAG = 'FirewallModeStrategyFactory'

class CustomModeStrategyAdapter implements FirewallModeStrategy {
  readonly mode: FirewallPresetMode = 'custom'

  async buildRules(context: common.UIAbilityContext): Promise<netFirewall.NetFirewallRule[]> {
    return CustomModeStrategy.buildRulesForApply(context)
  }
}

export class FirewallModeStrategyFactory {
  private static readonly publicStrategy: FirewallModeStrategy = new PublicModeStrategy()
  private static readonly privateStrategy: FirewallModeStrategy = new PrivateModeStrategy()
  private static readonly customStrategy: FirewallModeStrategy = new CustomModeStrategyAdapter()

  static getStrategy(mode: FirewallPresetMode): FirewallModeStrategy {
    switch (mode) {
      case 'public':
        return FirewallModeStrategyFactory.publicStrategy
      case 'private':
        return FirewallModeStrategyFactory.privateStrategy
      case 'custom':
      default:
        return FirewallModeStrategyFactory.customStrategy
    }
  }

  static async buildRulesForMode(
    context: common.UIAbilityContext,
    mode: FirewallPresetMode
  ): Promise<netFirewall.NetFirewallRule[]> {
    return FirewallModeStrategyFactory.getStrategy(mode).buildRules(context)
  }

  static async initialize(context: common.UIAbilityContext): Promise<void> {
    let storedModeValue = await FirewallModeStrategyFactory.getStoredModeValue(context)
    if (storedModeValue.length > 0) {
      return
    }
    let currentRules = await FirewallRepository.getAllRules()
    await CustomModeStrategy.initializeFromSystemIfEmpty(context, currentRules)
    await FirewallModeStrategyFactory.saveCurrentMode(context, 'custom')
  }

  static async getCurrentMode(context: common.UIAbilityContext): Promise<FirewallPresetMode> {
    let storedModeValue = await FirewallModeStrategyFactory.getStoredModeValue(context)
    if (storedModeValue === 'public' || storedModeValue === 'private' || storedModeValue === 'custom') {
      return storedModeValue
    }
    return 'custom'
  }

  static async switchMode(
    context: common.UIAbilityContext,
    mode: FirewallPresetMode
  ): Promise<FirewallModeSwitchResult> {
    await FirewallModeStrategyFactory.initialize(context)
    let targetRules = await FirewallModeStrategyFactory.buildRulesForMode(context, mode)
    return FirewallModeStrategyFactory.applyModeRules(context, mode, targetRules)
  }

  static async applyCustomRules(
    context: common.UIAbilityContext,
    rules: netFirewall.NetFirewallRule[]
  ): Promise<FirewallModeSwitchResult> {
    await FirewallModeStrategyFactory.initialize(context)
    return FirewallModeStrategyFactory.applyModeRules(context, 'custom', rules)
  }

  static async listCustomRules(context: common.UIAbilityContext): Promise<netFirewall.NetFirewallRule[]> {
    return CustomModeStrategy.listRules(context)
  }

  static async buildCustomRulesForApply(context: common.UIAbilityContext): Promise<netFirewall.NetFirewallRule[]> {
    return CustomModeStrategy.buildRulesForApply(context)
  }

  static async initializeCustomRulesFromSystemIfEmpty(
    context: common.UIAbilityContext,
    systemRules: netFirewall.NetFirewallRule[]
  ): Promise<void> {
    await CustomModeStrategy.initializeFromSystemIfEmpty(context, systemRules)
  }

  static async replaceAllCustomRules(
    context: common.UIAbilityContext,
    rules: netFirewall.NetFirewallRule[]
  ): Promise<boolean> {
    return CustomModeStrategy.replaceAllRules(context, rules)
  }

  static getCustomRuleId(rule: netFirewall.NetFirewallRule): string | undefined {
    return CustomModeStrategy.getCustomRuleId(rule)
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
    let cleared = await FirewallRepository.clearAllRules()
    if (!cleared) {
      return {
        success: false,
        mode: targetMode,
        appliedRuleCount: 0,
        errorCode: undefined,
        errorMessage: undefined
      }
    }
    let applied = await FirewallRepository.addRules(targetRules)
    if (!applied) {
      return {
        success: false,
        mode: targetMode,
        appliedRuleCount: 0,
        errorCode: undefined,
        errorMessage: undefined
      }
    }
    await FirewallModeStrategyFactory.saveCurrentMode(context, targetMode)
    return {
      success: true,
      mode: targetMode,
      appliedRuleCount: targetRules.length
    }
  }
}
