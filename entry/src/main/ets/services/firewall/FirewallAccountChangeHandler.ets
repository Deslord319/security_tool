import { common } from '@kit.AbilityKit'
import { AccountSnapshotChange } from '../account/AccountSnapshotModels'
import { FirewallLocalRepository } from './FirewallLocalRepository'
import { FirewallModeSwitchService } from './FirewallModeSwitchService'
import { FirewallPolicyService } from './FirewallPolicyService'
import { LogUtils } from '../../utils/LogUtils'

const TAG = 'FirewallAccountChangeHandler'

export class FirewallAccountChangeHandler {
  static async handle(context: common.Context, snapshot: AccountSnapshotChange): Promise<boolean> {
    if (snapshot.currentUserIds.length === 0) {
      LogUtils.warn(TAG, 'skip account reconcile because account list is empty | source=%{public}s', snapshot.source)
      return true
    }

    let pruned = await FirewallLocalRepository.pruneUnavailableUsers(context, snapshot.currentUserIds)
    if (!pruned) {
      LogUtils.warn(TAG, 'pruneUnavailableUsers failed | source=%{public}s', snapshot.source)
      return false
    }

    let currentMode = await FirewallLocalRepository.getCurrentMode(context)
    let desiredEnabled = await FirewallLocalRepository.getDesiredEnabled(context)
    if (currentMode === 'custom') {
      let failedItems = await FirewallPolicyService.applyPolicyForMode(
        context as common.UIAbilityContext,
        currentMode,
        snapshot.users,
        desiredEnabled
      )
      if (failedItems.length > 0) {
        LogUtils.warn(TAG, `apply custom policy failed: ${JSON.stringify(failedItems)}`)
        return false
      }
      return true
    }

    let lastAppliedMode = await FirewallLocalRepository.getLastAppliedMode(context)
    let lastAppliedSignature = await FirewallLocalRepository.getLastAppliedUserIdsSignature(context)
    if (lastAppliedMode === currentMode && lastAppliedSignature === snapshot.signature) {
      LogUtils.info(TAG, 'skip mode replay because account signature is unchanged | mode=%{public}s', currentMode)
      return true
    }

    let result = await FirewallModeSwitchService.applyModeToUsers(
      context as common.UIAbilityContext,
      currentMode,
      snapshot.users,
      desiredEnabled
    )
    if (!result.success) {
      LogUtils.warn(TAG, `applyModeToUsers failed: ${JSON.stringify(result.failedItems ?? [])}`)
      return false
    }
    return true
  }
}
