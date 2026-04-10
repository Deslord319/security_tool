import { application, common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'
import osAccount from '@ohos.account.osAccount'

import { UserFirewallListResult, UserFirewallOption, UserFirewallPolicyResult } from '../../../models/DataModels'
import { FirewallUserStrings, buildFirewallUserLabel } from '../../../constants/modules/FirewallStrings'
import { LogUtils } from '../../../utils/LogUtils'
import { PreferencesAccessor } from '../../../storage/preferences/PreferencesAccessor'

const TAG = 'SystemUserProvider'
const TRACKED_USERS_STORE = 'firewall_tracked_users'
const TRACKED_USERS_KEY = 'firewall_tracked_user_ids'

interface TrackedUserRecord {
  userId: number
  updatedAt: number
}

export class SystemUserProvider {
  static async trackAddedUser(userId: number): Promise<void> {
    if (!Number.isFinite(userId) || userId < 0) {
      LogUtils.warn(TAG, 'trackAddedUser ignored invalid userId=%{public}s', String(userId))
      return
    }
    let trackedUsers = await SystemUserProvider.loadTrackedUsers()
    let nextTrackedUsers = trackedUsers.filter((item: TrackedUserRecord): boolean => item.userId !== userId)
    nextTrackedUsers.push({
      userId: userId,
      updatedAt: Date.now()
    } as TrackedUserRecord)
    await SystemUserProvider.saveTrackedUsers(nextTrackedUsers)
    LogUtils.info(TAG, 'trackAddedUser success: userId=%{public}d, trackedCount=%{public}d', userId, nextTrackedUsers.length)
  }

  static async trackRemovedUser(userId: number): Promise<void> {
    if (!Number.isFinite(userId) || userId < 0) {
      LogUtils.warn(TAG, 'trackRemovedUser ignored invalid userId=%{public}s', String(userId))
      return
    }
    let trackedUsers = await SystemUserProvider.loadTrackedUsers()
    let nextTrackedUsers = trackedUsers.filter((item: TrackedUserRecord): boolean => item.userId !== userId)
    await SystemUserProvider.saveTrackedUsers(nextTrackedUsers)
    LogUtils.info(TAG, 'trackRemovedUser success: userId=%{public}d, trackedCount=%{public}d', userId, nextTrackedUsers.length)
  }

  static async loadAvailableUserIds(): Promise<UserFirewallListResult> {
    try {
      let accountManager = osAccount.getAccountManager()
      let ids = await accountManager.getActivatedOsAccountLocalIds()
      let trackedUserIds = await SystemUserProvider.loadTrackedUserIds()
      let mergedIds = SystemUserProvider.mergeUserIds(ids, trackedUserIds)
      if (mergedIds.length === 0) {
        return {
          users: [],
          message: FirewallUserStrings.NO_ACTIVATED_USERS
        } as UserFirewallListResult
      }

      let foregroundId: number | undefined = undefined
      try {
        foregroundId = await accountManager.getForegroundOsAccountLocalId()
      } catch (err) {
        LogUtils.warn(TAG, 'getForegroundOsAccountLocalId failed: %{public}s', JSON.stringify(err))
      }

      let users: UserFirewallOption[] = mergedIds.map((userId: number): UserFirewallOption => {
        let isForeground = foregroundId === userId
        return {
          userId: userId,
          label: buildFirewallUserLabel(userId, isForeground),
          isForeground: isForeground
        } as UserFirewallOption
      })

      let selectedUserId = foregroundId !== undefined && mergedIds.includes(foregroundId) ? foregroundId : mergedIds[0]
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

  private static async loadTrackedUserIds(): Promise<number[]> {
    let trackedUsers = await SystemUserProvider.loadTrackedUsers()
    return trackedUsers.map((item: TrackedUserRecord): number => item.userId)
  }

  private static async loadTrackedUsers(): Promise<TrackedUserRecord[]> {
    let context = SystemUserProvider.getPreferencesContext()
    if (context === null) {
      return []
    }
    let pref = PreferencesAccessor.of(context, TRACKED_USERS_STORE)
    let items = await pref.getJsonArray<TrackedUserRecord>(TRACKED_USERS_KEY, [])
    return items.filter((item: TrackedUserRecord): boolean =>
      item !== undefined &&
      typeof item.userId === 'number' &&
      Number.isFinite(item.userId) &&
      item.userId >= 0
    )
  }

  private static async saveTrackedUsers(items: TrackedUserRecord[]): Promise<void> {
    let context = SystemUserProvider.getPreferencesContext()
    if (context === null) {
      LogUtils.warn(TAG, 'saveTrackedUsers skipped: application context unavailable')
      return
    }
    let pref = PreferencesAccessor.of(context, TRACKED_USERS_STORE)
    let normalizedItems = items
      .filter((item: TrackedUserRecord): boolean => Number.isFinite(item.userId) && item.userId >= 0)
      .sort((left: TrackedUserRecord, right: TrackedUserRecord): number => left.userId - right.userId)
    let saved = await pref.setJson(TRACKED_USERS_KEY, normalizedItems)
    if (!saved) {
      LogUtils.error(TAG, 'saveTrackedUsers failed: count=%{public}d', normalizedItems.length)
    }
  }

  private static mergeUserIds(baseIds: number[], trackedUserIds: number[]): number[] {
    let merged = new Set<number>()
    baseIds.forEach((userId: number) => {
      if (Number.isFinite(userId) && userId >= 0) {
        merged.add(userId)
      }
    })
    trackedUserIds.forEach((userId: number) => {
      if (Number.isFinite(userId) && userId >= 0) {
        merged.add(userId)
      }
    })
    return Array.from(merged).sort((left: number, right: number) => left - right)
  }

  private static getPreferencesContext(): common.Context | null {
    try {
      return application.getApplicationContext()
    } catch (err) {
      LogUtils.warn(TAG, 'getPreferencesContext failed: %{public}s', JSON.stringify(err))
      return null
    }
  }
}
