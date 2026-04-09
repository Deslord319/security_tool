import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'
import osAccount from '@ohos.account.osAccount'

import { UserFirewallListResult, UserFirewallOption, UserFirewallPolicyResult } from '../../../models/DataModels'
import { FirewallUserStrings, buildFirewallUserLabel } from '../../../constants/modules/FirewallStrings'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'SystemUserProvider'

export class SystemUserProvider {
  static async loadAvailableUserIds(): Promise<UserFirewallListResult> {
    try {
      let accountManager = osAccount.getAccountManager()
      let ids = await accountManager.getActivatedOsAccountLocalIds()
      if (ids.length === 0) {
        return {
          users: [],
          message: FirewallUserStrings.NO_ACTIVATED_USERS
        } as UserFirewallListResult
      }

      let sortedIds = [...ids].sort((left: number, right: number) => left - right)
      let foregroundId: number | undefined = undefined
      try {
        foregroundId = await accountManager.getForegroundOsAccountLocalId()
      } catch (err) {
        LogUtils.warn(TAG, 'getForegroundOsAccountLocalId failed: %{public}s', JSON.stringify(err))
      }

      let users: UserFirewallOption[] = sortedIds.map((userId: number): UserFirewallOption => {
        let isForeground = foregroundId === userId
        return {
          userId: userId,
          label: buildFirewallUserLabel(userId, isForeground),
          isForeground: isForeground
        } as UserFirewallOption
      })

      let selectedUserId = foregroundId !== undefined && sortedIds.includes(foregroundId) ? foregroundId : sortedIds[0]
      LogUtils.info(TAG, 'loadAvailableUserIds success: count=%{public}d, selectedUserId=%{public}d', users.length, selectedUserId)

      return {
        users: users,
        selectedUserId: selectedUserId
      } as UserFirewallListResult
    } catch (err) {
      LogUtils.error(TAG, `loadAvailableUserIds failed: ${JSON.stringify(err)}`)
      return {
        users: [],
        message: FirewallUserStrings.NO_ACTIVATED_USERS
      } as UserFirewallListResult
    }
  }

  static async getPolicy(userId: number): Promise<UserFirewallPolicyResult> {
    try {
      let policy = await netFirewall.getNetFirewallPolicy(userId)
      LogUtils.info(TAG,
        'getPolicy success: userId=%{public}d, isOpen=%{public}s, inAction=%{public}d, outAction=%{public}d',
        userId,
        String(policy.isOpen),
        policy.inAction,
        policy.outAction
      )
      return {
        userId: userId,
        isOpen: policy.isOpen,
        inAction: policy.inAction,
        outAction: policy.outAction
      } as UserFirewallPolicyResult
    } catch (err) {
      LogUtils.error(TAG, `getPolicy failed, userId=${userId}, err=${JSON.stringify(err)}`)
      return {
        userId: userId,
        isOpen: false,
        inAction: netFirewall.FirewallRuleAction.RULE_ALLOW,
        outAction: netFirewall.FirewallRuleAction.RULE_ALLOW
      } as UserFirewallPolicyResult
    }
  }
}
