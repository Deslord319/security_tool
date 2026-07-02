import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'
import { FirewallPolicyErrorStrings } from '../../constants/modules/FirewallErrorStrings'
import { AuthMethod } from '../../models/AuthModels'
import { LogUtils } from '../../utils/LogUtils'
import { AuthService } from '../identity/auth/AuthService'
import { FirewallLocalRepository } from './FirewallLocalRepository'
import {
  FirewallFailedItem,
  FirewallOverviewState,
  FirewallPresetMode,
  FirewallToggleOperationResult,
  FirewallUserPolicyApplyResult,
  FirewallUserPolicyMode,
  FirewallUserPolicyModeRecord,
  FirewallUserPolicyStateResult,
  UserFirewallOption
} from './FirewallModels'
import { FirewallSystemRepository } from './FirewallSystemRepository'
import { SystemUserProvider } from './providers/SystemUserProvider'

const TAG = 'FirewallPolicyService'

export class FirewallPolicyService {
  static async loadOverviewState(context: common.UIAbilityContext): Promise<FirewallOverviewState> {
    let availableUsers = await SystemUserProvider.loadAvailableUserIds()
    if (availableUsers.users.length === 0) {
      LogUtils.warn(TAG, 'loadOverviewState fallback to default state because no available users')
      return {
        enabled: false,
        currentMode: await FirewallLocalRepository.getCurrentMode(context)
      }
    }

    let currentUserId = availableUsers.selectedUserId ?? availableUsers.users[0].userId
    let currentPolicy = await FirewallSystemRepository.getPolicy(currentUserId)
    let enabled = currentPolicy !== null && currentPolicy.isOpen

    return {
      enabled: enabled,
      currentMode: await FirewallLocalRepository.getCurrentMode(context)
    }
  }

  static async setFirewallEnabledForAllUsers(
    context: common.Context,
    enabled: boolean
  ): Promise<FirewallToggleOperationResult> {
    let authResult = await AuthService.authenticate(AuthMethod.PIN)
    if (!authResult.success) {
      return {
        success: false,
        targetEnabled: enabled,
        reason: authResult.reason === 'unavailable' ? 'pin_unavailable' : 'pin_failed',
        errorCode: authResult.errorCode,
        errorMessage: authResult.message
      }
    }

    let usersResult = await SystemUserProvider.loadAvailableUserIds()
    let users = usersResult.users
    if (users.length === 0) {
      return {
        success: false,
        targetEnabled: enabled,
        reason: 'no_available_users',
        errorMessage: usersResult.message ?? 'no available users'
      }
    }

    let failedItems: FirewallFailedItem[] = []
    for (let i = 0; i < users.length; i++) {
      let userId = users[i].userId
      let existingPolicy = await FirewallSystemRepository.getPolicy(userId)
      if (existingPolicy === null) {
        failedItems.push({ userId: userId, errorMessage: FirewallPolicyErrorStrings.READ_POLICY_FAILED })
        continue
      }
      let nextPolicy: netFirewall.NetFirewallPolicy = {
        isOpen: enabled,
        inAction: existingPolicy.inAction,
        outAction: existingPolicy.outAction
      }
      let applied = await FirewallSystemRepository.setPolicy(userId, nextPolicy)
      if (!applied) {
        failedItems.push({ userId: userId, errorMessage: FirewallPolicyErrorStrings.SET_POLICY_FAILED })
      }
    }

    let success = failedItems.length === 0
    if (success) {
      let desiredSaved = await FirewallLocalRepository.saveDesiredEnabled(context, enabled)
      if (!desiredSaved) {
        failedItems.push({ errorMessage: FirewallPolicyErrorStrings.POLICY_APPLY_FAILED })
        success = false
      }
    }

    return {
      success: success,
      targetEnabled: enabled,
      reason: success ? undefined : 'policy_apply_failed',
      failedItems: failedItems,
      errorMessage: success ? undefined : FirewallPolicyErrorStrings.POLICY_APPLY_FAILED
    }
  }

  static async applyPolicyForMode(
    context: common.UIAbilityContext,
    targetMode: FirewallPresetMode,
    users: UserFirewallOption[],
    desiredEnabled?: boolean
  ): Promise<FirewallFailedItem[]> {
    let failedItems: FirewallFailedItem[] = []
    let modeRecords = targetMode === 'custom'
      ? await FirewallLocalRepository.listUserPolicyModes(context)
      : []

    for (let i = 0; i < users.length; i++) {
      let userId = users[i].userId
      let existingPolicy = await FirewallSystemRepository.getPolicy(userId)
      if (existingPolicy === null) {
        failedItems.push({ userId: userId, errorMessage: FirewallPolicyErrorStrings.READ_MODE_POLICY_FAILED })
        continue
      }
      let userMode = FirewallPolicyService.resolveUserPolicyModeForSwitch(targetMode, userId, modeRecords)
      let policy = FirewallPolicyService.buildPolicyForUserMode(
        userMode,
        desiredEnabled === undefined ? existingPolicy.isOpen : desiredEnabled
      )
      let applied = await FirewallSystemRepository.setPolicy(userId, policy)
      if (!applied) {
        failedItems.push({ userId: userId, errorMessage: FirewallPolicyErrorStrings.SET_MODE_POLICY_FAILED })
      }
    }
    return failedItems
  }

  static async applyUserPolicyMode(
    context: common.UIAbilityContext,
    userId: number,
    mode: FirewallUserPolicyMode
  ): Promise<FirewallUserPolicyApplyResult> {
    let authResult = await AuthService.authenticate(AuthMethod.PIN)
    if (!authResult.success) {
      return {
        success: false,
        userId: userId,
        mode: mode,
        errorCode: authResult.errorCode,
        errorMessage: authResult.message
      }
    }

    let policy = FirewallPolicyService.buildPolicyForUserMode(mode)
    let applied = await FirewallSystemRepository.setPolicy(userId, policy)
    if (!applied) {
      return {
        success: false,
        userId: userId,
        mode: mode,
        errorMessage: FirewallPolicyErrorStrings.SET_POLICY_FAILED
      }
    }

    let saved = await FirewallLocalRepository.saveUserPolicyMode(context, userId, mode)
    return {
      success: saved,
      userId: userId,
      mode: mode,
      errorMessage: saved ? undefined : FirewallPolicyErrorStrings.SAVE_USER_POLICY_MODE_FAILED
    }
  }

  static async loadUserPolicyState(
    context: common.UIAbilityContext,
    userId: number
  ): Promise<FirewallUserPolicyStateResult> {
    let policy = await FirewallSystemRepository.getPolicy(userId)
    if (policy === null) {
      return {
        userId: userId,
        isManaged: false,
        isOpen: false,
        inAction: netFirewall.FirewallRuleAction.RULE_ALLOW,
        outAction: netFirewall.FirewallRuleAction.RULE_ALLOW,
        message: FirewallPolicyErrorStrings.READ_POLICY_FAILED
      }
    }
    return {
      userId: userId,
      bindingMode: await FirewallLocalRepository.getUserPolicyMode(context, userId),
      isManaged: true,
      isOpen: policy.isOpen,
      inAction: policy.inAction,
      outAction: policy.outAction
    }
  }

  private static resolveUserPolicyModeForSwitch(
    targetMode: FirewallPresetMode,
    userId: number,
    modeRecords: FirewallUserPolicyModeRecord[]
  ): FirewallUserPolicyMode | undefined {
    if (targetMode !== 'custom') {
      return undefined
    }
    return modeRecords.find((item: FirewallUserPolicyModeRecord): boolean => item.userId === userId)?.mode
  }

  private static buildPolicyForUserMode(mode?: FirewallUserPolicyMode, isOpen: boolean = true): netFirewall.NetFirewallPolicy {
    if (mode === 'allowlist') {
      return {
        isOpen: isOpen,
        inAction: netFirewall.FirewallRuleAction.RULE_DENY,
        outAction: netFirewall.FirewallRuleAction.RULE_DENY
      }
    }
    return {
      isOpen: isOpen,
      inAction: netFirewall.FirewallRuleAction.RULE_ALLOW,
      outAction: netFirewall.FirewallRuleAction.RULE_ALLOW
    }
  }
}
