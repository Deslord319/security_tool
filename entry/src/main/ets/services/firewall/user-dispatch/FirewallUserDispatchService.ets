import { common } from '@kit.AbilityKit'

import {
  FirewallUserApplyMode,
  FirewallUserApplyResult,
  FirewallUserModeStateResult,
  UserFirewallOption,
} from '../../../models/firewall/firewall_service_contracts'
import { FirewallStore } from '../stores/FirewallStore'
import { FirewallAuthService } from '../auth/FirewallAuthService'
import { SystemUserProvider } from '../providers/SystemUserProvider'

export class FirewallUserDispatchService {
  static async loadUserOptions(): Promise<UserFirewallOption[]> {
    let result = await SystemUserProvider.loadAvailableUserIds()
    return result.users
  }

  static async loadUserModeState(
    context: common.UIAbilityContext,
    userId: number
  ): Promise<FirewallUserModeStateResult> {
    return FirewallStore.getUserModeState(context, userId)
  }

  static async applyUserMode(
    context: common.UIAbilityContext,
    userId: number,
    mode: FirewallUserApplyMode
  ): Promise<FirewallUserApplyResult> {
    return FirewallAuthService.executeUserModeApply(
      context,
      userId,
      mode,
      async (): Promise<FirewallUserApplyResult> => {
        return FirewallStore.applyUserMode(context, userId, mode)
      }
    )
  }
}
