import { common } from '@kit.AbilityKit'
import { FirewallDialogStrings, FirewallUserStrings } from '../../../constants/modules/FirewallStrings'
import { LogUtils } from '../../../utils/LogUtils'
import {
  FirewallUserPolicyMode,
  FirewallUserPolicyApplyResult,
  FirewallUserPolicyStateResult,
  UserFirewallOption
} from '../../../services/firewall/FirewallModels'
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

  private readonly modeOptions: FirewallUserPolicyMode[] = ['allowlist', 'denylist']
  private context: common.UIAbilityContext | null = null

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.context = context
    await this.loadUsers()
  }

  async loadUsers(): Promise<void> {
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
      this.selectedIndex = 0
      this.selectedUserId = result.users[0].userId
      this.selectedModeIndex = 0
      await this.loadStateForSelectedUser()
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

  async selectUser(index: number): Promise<void> {
    if (index < 0 || index >= this.users.length) {
      return
    }
    this.selectedIndex = index
    this.selectedUserId = this.users[index].userId
    await this.loadStateForSelectedUser()
  }

  async selectMode(index: number): Promise<void> {
    if (index < 0 || index >= this.modeOptions.length) {
      return
    }
    this.selectedModeIndex = index
  }

  async loadStateForSelectedUser(): Promise<void> {
    if (this.selectedUserId < 0 || this.context === null) {
      return
    }

    this.isLoadingPolicy = true
    this.statusHintText = ''
    try {
      const result = await FirewallService.loadUserPolicyState(this.context, this.selectedUserId)
      this.applyLoadedMode(result)
    } catch (err) {
      this.statusHintText = FirewallDialogStrings.ERROR_CANNOT_GET_STATUS
      LogUtils.error(TAG, `loadStateForSelectedUser failed: ${JSON.stringify(err)}`)
    } finally {
      this.isLoadingPolicy = false
    }
  }

  async applySelectedMode(): Promise<boolean> {
    if (this.context === null || this.selectedUserId < 0) {
      return false
    }

    this.isSubmitting = true
    try {
      const targetMode = this.modeOptions[this.selectedModeIndex]
      const result = await FirewallService.applyUserPolicyMode(this.context, this.selectedUserId, targetMode)
      this.lastApplyResult = result
      if (!result.success) {
        this.statusHintText = result.errorMessage ?? FirewallDialogStrings.APPLY_MODE_FAILED
        return false
      }
      this.statusHintText = ''
      await this.loadStateForSelectedUser()
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

  private applyLoadedMode(result: FirewallUserPolicyStateResult): void {
    if (result.errorCode !== undefined) {
      this.statusHintText = result.message ?? FirewallDialogStrings.ERROR_CANNOT_GET_STATUS
      this.selectedModeIndex = 0
      return
    }

    const selectedMode = result.bindingMode ?? this.modeOptions[0]
    this.selectedModeIndex = this.modeOptions.findIndex((item: FirewallUserPolicyMode): boolean => item === selectedMode)
    if (this.selectedModeIndex < 0) {
      this.selectedModeIndex = 0
    }
  }
}
