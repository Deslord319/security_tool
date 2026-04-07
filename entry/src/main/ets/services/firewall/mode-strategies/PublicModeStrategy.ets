import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'

import { FirewallPresetConfig, FirewallPresetMode } from '../../../models/DataModels'
import { FirewallModeRuleBuilder } from './FirewallModeRuleBuilder'
import { FirewallModeStrategy } from './FirewallModeStrategy'
import { FirewallPresetConfigReader } from './FirewallPresetConfigReader'

export class PublicModeStrategy implements FirewallModeStrategy {
  readonly mode: FirewallPresetMode = 'public'

  async buildRules(context: common.UIAbilityContext): Promise<netFirewall.NetFirewallRule[]> {
    let config: FirewallPresetConfig = await FirewallPresetConfigReader.loadConfig(context)
    return FirewallModeRuleBuilder.buildRulesForMode(this.mode, config)
  }
}
