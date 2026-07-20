import { PermissionAccountListResult, PermissionManagedAccount } from '../../models/PermissionModels'
import { PermissionAccountStrings } from '../../constants/modules/PermissionStrings'
import { UserFirewallOption } from '../../models/firewall/FirewallModels'
import { SystemUserProvider } from '../firewall/providers/SystemUserProvider'

export class PermissionAccountProvider {
  static async loadAccounts(): Promise<PermissionAccountListResult> {
    let result = await SystemUserProvider.loadAvailableUserIds()
    let accounts = result.users.map((user: UserFirewallOption): PermissionManagedAccount => ({
      accountId: user.userId,
      displayName: user.label,
      isForeground: user.isForeground ?? false,
      isAvailable: true
    } as PermissionManagedAccount))
    let selectedAccountId = result.selectedUserId ?? (accounts[0]?.accountId ?? 0)
    return {
      accounts: accounts,
      selectedAccountId: selectedAccountId,
      message: accounts.length === 0 ? (result.message ?? PermissionAccountStrings.NO_ACCOUNTS) : undefined
    } as PermissionAccountListResult
  }
}
