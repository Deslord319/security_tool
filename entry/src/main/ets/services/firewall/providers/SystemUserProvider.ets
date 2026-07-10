import { osAccount } from '@kit.BasicServicesKit'

import { UserFirewallListResult, UserFirewallOption } from '../FirewallModels'
import { FirewallUserStrings, buildFirewallUserLabel } from '../../../constants/modules/FirewallStrings'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'SystemUserProvider'

export class SystemUserProvider {
  static async loadAvailableUserIds(): Promise<UserFirewallListResult> {
    try {
      let accountManager = osAccount.getAccountManager()
      let userIds = await SystemUserProvider.loadAccountLocalIds(accountManager)
      if (userIds.length === 0) {
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

      let userNameMap = await SystemUserProvider.loadUserNameMap(accountManager, userIds)
      let users: UserFirewallOption[] = userIds.map((userId: number): UserFirewallOption => {
        let isForeground = foregroundId === userId
        return {
          userId: userId,
          label: buildFirewallUserLabel(userId, isForeground, userNameMap.get(userId)),
          isForeground: isForeground
        } as UserFirewallOption
      })

      let selectedUserId = foregroundId !== undefined && userIds.includes(foregroundId) ? foregroundId : userIds[0]

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

  private static async loadAccountLocalIds(accountManager: osAccount.AccountManager): Promise<number[]> {
    try {
      let rawUserIds = await accountManager.getOsAccountLocalIds()
      return SystemUserProvider.normalizeUserIds(rawUserIds)
    } catch (err) {
      LogUtils.warn(TAG, 'getOsAccountLocalIds failed: %{public}s', JSON.stringify(err))
      return []
    }
  }

  private static async loadUserNameMap(
    accountManager: osAccount.AccountManager,
    userIds: number[]
  ): Promise<Map<number, string>> {
    let userNameMap = new Map<number, string>()
    for (let i = 0; i < userIds.length; i++) {
      let userId = userIds[i]
      let userName = await SystemUserProvider.loadUserName(accountManager, userId)
      if (userName !== undefined) {
        userNameMap.set(userId, userName)
      }
    }
    return userNameMap
  }

  private static async loadUserName(
    accountManager: osAccount.AccountManager,
    userId: number
  ): Promise<string | undefined> {
    try {
      return SystemUserProvider.normalizeUserName(await accountManager.getOsAccountNameByLocalId(userId))
    } catch (err) {
      LogUtils.warn(TAG, 'getOsAccountNameByLocalId failed: userId=%{public}d, err=%{public}s', userId, JSON.stringify(err))
      return undefined
    }
  }

  private static normalizeUserName(userName?: string): string | undefined {
    let normalizedName = userName?.trim()
    return normalizedName && normalizedName.length > 0 ? normalizedName : undefined
  }

  private static normalizeUserIds(userIds: number[]): number[] {
    let normalizedIds = new Set<number>()
    userIds.forEach((userId: number) => {
      if (Number.isFinite(userId) && userId >= 0) {
        normalizedIds.add(userId)
      }
    })
    return Array.from(normalizedIds).sort((left: number, right: number) => left - right)
  }
}
