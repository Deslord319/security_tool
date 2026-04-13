import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'

import {
  FirewallModeSwitchResult,
  FirewallPresetMode
} from '../../../models/DataModels'
import { FirewallModeRepository } from '../repositories/FirewallModeRepository'
import { FirewallRepository } from '../repositories/FirewallRepository'
import { CustomModeStrategy } from './CustomModeStrategy'
import { FirewallModeStrategy } from './FirewallModeStrategy'
import { PresetModeStrategy } from './PresetModeStrategy'

class CustomModeStrategyAdapter implements FirewallModeStrategy {
  readonly mode: FirewallPresetMode = 'custom'

  async buildRules(context: common.UIAbilityContext): Promise<netFirewall.NetFirewallRule[]> {
    return CustomModeStrategy.buildRulesForApply(context)
  }
}

export class FirewallModeStrategyFactory {
  private static readonly publicStrategy: FirewallModeStrategy = new PresetModeStrategy('public')
  private static readonly privateStrategy: FirewallModeStrategy = new PresetModeStrategy('private')
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
    let storedModeValue = await FirewallModeRepository.getStoredModeValue(context)
    if (storedModeValue.length > 0) {
      return
    }
    let currentRules = await FirewallRepository.getAllRules()
    await CustomModeStrategy.initializeFromSystemIfEmpty(context, currentRules)
    await FirewallModeRepository.saveCurrentMode(context, 'custom')
  }

  static async getCurrentMode(context: common.UIAbilityContext): Promise<FirewallPresetMode> {
    return FirewallModeRepository.getCurrentMode(context)
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

  private static buildFailedSwitchResult(targetMode: FirewallPresetMode): FirewallModeSwitchResult {
    return {
      success: false,
      mode: targetMode,
      appliedRuleCount: 0,
      errorCode: undefined,
      errorMessage: undefined
    }
  }

  private static async applyModeRules(
    context: common.UIAbilityContext,
    targetMode: FirewallPresetMode,
    targetRules: netFirewall.NetFirewallRule[]
  ): Promise<FirewallModeSwitchResult> {
    let cleared = await FirewallRepository.clearAllRules()
    if (!cleared) {
      return FirewallModeStrategyFactory.buildFailedSwitchResult(targetMode)
    }
    let applied = await FirewallRepository.addRules(targetRules)
    if (!applied) {
      return FirewallModeStrategyFactory.buildFailedSwitchResult(targetMode)
    }
    await FirewallModeRepository.saveCurrentMode(context, targetMode)
    return {
      success: true,
      mode: targetMode,
      appliedRuleCount: targetRules.length
    }
  }
}
