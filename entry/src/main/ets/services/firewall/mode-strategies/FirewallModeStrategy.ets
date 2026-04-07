import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'
import { FirewallPresetMode } from '../../../models/DataModels'

export interface FirewallModeStrategy {
  readonly mode: FirewallPresetMode

  buildRules(context: common.UIAbilityContext): Promise<netFirewall.NetFirewallRule[]>
}
