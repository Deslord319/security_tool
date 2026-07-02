import { common } from '@kit.AbilityKit'
import { FirewallDialogStrings, FirewallRuleStrings, FirewallUserStrings } from '../../../constants/modules/FirewallStrings'
import { LogUtils } from '../../../utils/LogUtils'
import {
  FIREWALL_USER_POLICY_MODE_OPTIONS,
  FirewallUserPolicyMode,
  FirewallUserPolicyApplyResult,
  FirewallUserPolicyStateResult,
  resolveFirewallUserPolicyModeFromActions,
  UserFirewallOption
} from '../../../services/firewall/FirewallModels'
import { FirewallLocalRepository } from '../../../services/firewall/FirewallLocalRepository'
import { FirewallService } from '../../../services/firewall/FirewallService'
import { SystemUserProvider } from '../../../services/firewall/providers/SystemUserProvider'

const TAG = 'FirewallUserDispatchViewModel'

@ObservedV2
export class FirewallUserDispatchViewModel {
  @Trace users: UserFirewallOption[] = []
  @Trace selectedIndex: number = 0
  @Trace selectedUserId: number = -1
  @Trace selectedModeIndex: number = 0
  @Trace isLoadingUsers: boolean = false
  @Trace isLoadingPolicy: boolean = false
  @Trace isSubmitting: boolean = false
  @Trace statusHintText: string = ''
  @Trace lastApplyResult: FirewallUserPolicyApplyResult | null = null

  private readonly modeOptions: FirewallUserPolicyMode[] = FIREWALL_USER_POLICY_MODE_OPTIONS

  async initialize(context: common.UIAbilityContext): Promise<void> {
    await this.loadUsers(context)
  }

  async loadUsers(context: common.UIAbilityContext): Promise<void> {
    this.isLoadingUsers = true
    this.statusHintText = ''
    try {
      const result = await SystemUserProvider.loadAvailableUserIds()
      if (result.users.length === 0) {
        this.users = []
        this.selectedIndex = 0
        this.selectedUserId = -1
        this.selectedModeIndex = 0
        this.statusHintText = FirewallUserStrings.NO_ACTIVATED_USERS
        return
      }

      this.users = result.users
      await this.pruneUnavailableLocalUsers(context, this.users)
      this.selectedIndex = 0
      this.selectedUserId = result.users[0].userId
      this.selectedModeIndex = 0
      await this.loadStateForSelectedUser(context)
    } catch (err) {
      this.users = []
      this.selectedIndex = 0
      this.selectedUserId = -1
      this.selectedModeIndex = 0
      this.statusHintText = FirewallUserStrings.NO_ACTIVATED_USERS
      LogUtils.error(TAG, `loadUsers failed: ${JSON.stringify(err)}`)
    } finally {
      this.isLoadingUsers = false
    }
  }

  async selectUser(context: common.UIAbilityContext, index: number): Promise<void> {
    if (index < 0 || index >= this.users.length) {
      return
    }
    this.selectedIndex = index
    this.selectedUserId = this.users[index].userId
    await this.loadStateForSelectedUser(context)
  }

  async selectMode(index: number): Promise<void> {
    if (index < 0 || index >= this.modeOptions.length) {
      return
    }
    this.selectedModeIndex = index
  }

  async loadStateForSelectedUser(context: common.UIAbilityContext): Promise<void> {
    if (this.selectedUserId < 0) {
      return
    }

    this.isLoadingPolicy = true
    this.statusHintText = ''
    try {
      const result = await FirewallService.loadUserPolicyState(context, this.selectedUserId)
      this.applyLoadedMode(result)
    } catch (err) {
      this.statusHintText = FirewallDialogStrings.ERROR_CANNOT_GET_STATUS
      LogUtils.error(TAG, `loadStateForSelectedUser failed: ${JSON.stringify(err)}`)
    } finally {
      this.isLoadingPolicy = false
    }
  }

  async applySelectedMode(context: common.UIAbilityContext): Promise<boolean> {
    if (this.selectedUserId < 0) {
      return false
    }

    this.isSubmitting = true
    try {
      let accountReady = await this.refreshUsersForSubmit(context)
      if (!accountReady) {
        return false
      }
      const targetMode = this.modeOptions[this.selectedModeIndex]
      const result = await FirewallService.applyUserPolicyMode(context, this.selectedUserId, targetMode)
      this.lastApplyResult = result
      if (!result.success) {
        this.statusHintText = result.errorMessage ?? FirewallDialogStrings.APPLY_MODE_FAILED
        return false
      }
      this.statusHintText = ''
      await this.loadStateForSelectedUser(context)
      return true
    } catch (err) {
      this.statusHintText = FirewallDialogStrings.APPLY_MODE_FAILED
      this.lastApplyResult = null
      LogUtils.error(TAG, `applySelectedMode failed: ${JSON.stringify(err)}`)
      return false
    } finally {
      this.isSubmitting = false
    }
  }

  getSelectedMode(): FirewallUserPolicyMode {
    return this.modeOptions[this.selectedModeIndex]
  }

  getSelectedUser(): UserFirewallOption | undefined {
    return this.users[this.selectedIndex]
  }

  private async refreshUsersForSubmit(context: common.UIAbilityContext): Promise<boolean> {
    let result = await SystemUserProvider.loadAvailableUserIds()
    if (result.users.length === 0) {
      this.users = []
      this.selectedIndex = 0
      this.selectedUserId = -1
      this.statusHintText = FirewallUserStrings.NO_ACTIVATED_USERS
      return false
    }
    let pruned = await this.pruneUnavailableLocalUsers(context, result.users)
    if (!pruned) {
      this.statusHintText = FirewallDialogStrings.APPLY_MODE_FAILED
      return false
    }
    this.users = result.users
    let refreshedIndex = this.users.findIndex((user: UserFirewallOption): boolean => user.userId === this.selectedUserId)
    if (refreshedIndex < 0) {
      this.selectedIndex = 0
      this.selectedUserId = this.users[0].userId
      this.statusHintText = FirewallRuleStrings.USER_SCOPE_CHANGED
      return false
    }
    this.selectedIndex = refreshedIndex
    return true
  }

  private async pruneUnavailableLocalUsers(
    context: common.UIAbilityContext,
    users: UserFirewallOption[]
  ): Promise<boolean> {
    if (users.length === 0) {
      return true
    }
    let pruned = await FirewallLocalRepository.pruneUnavailableUsers(
      context,
      users.map((user: UserFirewallOption): number => user.userId)
    )
    if (!pruned) {
      LogUtils.warn(TAG, 'pruneUnavailableUsers failed')
    }
    return pruned
  }

  private applyLoadedMode(result: FirewallUserPolicyStateResult): void {
    if (!result.isManaged || result.errorCode !== undefined) {
      this.statusHintText = result.message ?? FirewallDialogStrings.ERROR_CANNOT_GET_STATUS
      this.selectedModeIndex = 0
      return
    }

    const selectedMode = result.bindingMode ??
      resolveFirewallUserPolicyModeFromActions(result.inAction, result.outAction) ??
      this.modeOptions[0]
    this.selectedModeIndex = this.modeOptions.findIndex((item: FirewallUserPolicyMode): boolean => item === selectedMode)
    if (this.selectedModeIndex < 0) {
      this.selectedModeIndex = 0
    }
  }
}
