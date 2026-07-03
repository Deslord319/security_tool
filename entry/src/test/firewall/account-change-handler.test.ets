import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'

import { AccountSnapshotChange } from '../../main/ets/services/account/AccountSnapshotModels'
import { FirewallAccountChangeHandler } from '../../main/ets/services/firewall/FirewallAccountChangeHandler'
import { FirewallLocalRepository } from '../../main/ets/services/firewall/FirewallLocalRepository'
import { FirewallModeSwitchService } from '../../main/ets/services/firewall/FirewallModeSwitchService'
import { FirewallPolicyService } from '../../main/ets/services/firewall/FirewallPolicyService'
import {
  FirewallFailedItem,
  FirewallOperationResult,
  FirewallPresetMode,
  UserFirewallOption
} from '../../main/ets/services/firewall/FirewallModels'

function buildUsers(userIds: number[] = [100, 101]): UserFirewallOption[] {
  return userIds.map((userId: number): UserFirewallOption => {
    return {
      userId: userId,
      label: `User ${userId}`
    }
  })
}

function buildSnapshot(userIds: number[] = [100, 101]): AccountSnapshotChange {
  return {
    source: 'account-added',
    users: buildUsers(userIds),
    currentUserIds: userIds,
    addedUserIds: [101],
    removedUserIds: [],
    signature: userIds.join(','),
    previousSignature: '100'
  }
}

function successResult(): FirewallOperationResult {
  return {
    success: true,
    failedItems: []
  }
}

export default function firewallAccountChangeHandlerTest() {
  describe('FirewallAccountChangeHandler', () => {
    let mockKit: MockKit
    let context: common.UIAbilityContext

    beforeEach(() => {
      mockKit = new MockKit()
      context = {} as common.UIAbilityContext
    })

    afterEach(() => {
      mockKit.clearAll()
    })

    it('should replay public mode when account signature changes', 0, async (done: Function) => {
      let appliedMode: FirewallPresetMode | undefined = undefined
      let appliedUserCount = 0
      let appliedDesiredEnabled: boolean | undefined = undefined
      let pruneMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.pruneUnavailableUsers)
      let currentModeMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getCurrentMode)
      let lastModeMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getLastAppliedMode)
      let lastSignatureMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getLastAppliedUserIdsSignature)
      let desiredEnabledMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getDesiredEnabled)
      let applyModeMock = mockKit.mockFunc(FirewallModeSwitchService, FirewallModeSwitchService.applyModeToUsers)

      when(pruneMock)(ArgumentMatchers.any).afterReturn(true)
      when(currentModeMock)(ArgumentMatchers.any).afterReturn('public')
      when(lastModeMock)(ArgumentMatchers.any).afterReturn('public')
      when(lastSignatureMock)(ArgumentMatchers.any).afterReturn('100')
      when(desiredEnabledMock)(ArgumentMatchers.any).afterReturn(false)
      when(applyModeMock)(ArgumentMatchers.any).afterAction((
        _context: common.UIAbilityContext,
        mode: FirewallPresetMode,
        users: UserFirewallOption[],
        desiredEnabled?: boolean
      ): FirewallOperationResult => {
        appliedMode = mode
        appliedUserCount = users.length
        appliedDesiredEnabled = desiredEnabled
        return successResult()
      })

      let handled = await FirewallAccountChangeHandler.handle(context, buildSnapshot())

      expect(handled).assertTrue()
      expect(appliedMode).assertEqual('public')
      expect(appliedUserCount).assertEqual(2)
      expect(appliedDesiredEnabled).assertFalse()
      done()
    })

    it('should skip replay when mode and account signature are unchanged', 0, async (done: Function) => {
      let applyCount = 0
      let pruneMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.pruneUnavailableUsers)
      let currentModeMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getCurrentMode)
      let lastModeMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getLastAppliedMode)
      let lastSignatureMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getLastAppliedUserIdsSignature)
      let desiredEnabledMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getDesiredEnabled)
      let applyModeMock = mockKit.mockFunc(FirewallModeSwitchService, FirewallModeSwitchService.applyModeToUsers)

      when(pruneMock)(ArgumentMatchers.any).afterReturn(true)
      when(currentModeMock)(ArgumentMatchers.any).afterReturn('private')
      when(lastModeMock)(ArgumentMatchers.any).afterReturn('private')
      when(lastSignatureMock)(ArgumentMatchers.any).afterReturn('100,101')
      when(desiredEnabledMock)(ArgumentMatchers.any).afterReturn(true)
      when(applyModeMock)(ArgumentMatchers.any).afterAction((): FirewallOperationResult => {
        applyCount++
        return successResult()
      })

      let handled = await FirewallAccountChangeHandler.handle(context, buildSnapshot())

      expect(handled).assertTrue()
      expect(applyCount).assertEqual(0)
      done()
    })

    it('should sync custom mode policy without replaying all-account rules', 0, async (done: Function) => {
      let replayCount = 0
      let policyMode: FirewallPresetMode | undefined = undefined
      let policyUserCount = 0
      let policyDesiredEnabled: boolean | undefined = undefined
      let pruneMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.pruneUnavailableUsers)
      let currentModeMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getCurrentMode)
      let desiredEnabledMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getDesiredEnabled)
      let saveModeApplyStateMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.saveModeApplyState)
      let policyMock = mockKit.mockFunc(FirewallPolicyService, FirewallPolicyService.applyPolicyForMode)
      let applyModeMock = mockKit.mockFunc(FirewallModeSwitchService, FirewallModeSwitchService.applyModeToUsers)
      let savedMode: FirewallPresetMode | undefined = undefined
      let savedSignature = ''

      when(pruneMock)(ArgumentMatchers.any).afterReturn(true)
      when(currentModeMock)(ArgumentMatchers.any).afterReturn('custom')
      when(desiredEnabledMock)(ArgumentMatchers.any).afterReturn(true)
      when(saveModeApplyStateMock)(ArgumentMatchers.any).afterAction((
        _context: common.Context,
        mode: FirewallPresetMode,
        signature: string
      ): boolean => {
        savedMode = mode
        savedSignature = signature
        return true
      })
      when(policyMock)(ArgumentMatchers.any).afterAction((
        _context: common.UIAbilityContext,
        mode: FirewallPresetMode,
        users: UserFirewallOption[],
        desiredEnabled?: boolean
      ): FirewallFailedItem[] => {
        policyMode = mode
        policyUserCount = users.length
        policyDesiredEnabled = desiredEnabled
        return []
      })
      when(applyModeMock)(ArgumentMatchers.any).afterAction((): FirewallOperationResult => {
        replayCount++
        return successResult()
      })

      let handled = await FirewallAccountChangeHandler.handle(context, buildSnapshot())

      expect(handled).assertTrue()
      expect(policyMode).assertEqual('custom')
      expect(policyUserCount).assertEqual(2)
      expect(policyDesiredEnabled).assertTrue()
      expect(replayCount).assertEqual(0)
      expect(savedMode).assertEqual('custom')
      expect(savedSignature).assertEqual('100,101')
      done()
    })

    it('should report failure when custom mode apply state save fails', 0, async (done: Function) => {
      let pruneMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.pruneUnavailableUsers)
      let currentModeMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getCurrentMode)
      let desiredEnabledMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getDesiredEnabled)
      let saveModeApplyStateMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.saveModeApplyState)
      let policyMock = mockKit.mockFunc(FirewallPolicyService, FirewallPolicyService.applyPolicyForMode)

      when(pruneMock)(ArgumentMatchers.any).afterReturn(true)
      when(currentModeMock)(ArgumentMatchers.any).afterReturn('custom')
      when(desiredEnabledMock)(ArgumentMatchers.any).afterReturn(true)
      when(policyMock)(ArgumentMatchers.any).afterReturn([])
      when(saveModeApplyStateMock)(ArgumentMatchers.any).afterReturn(false)

      let handled = await FirewallAccountChangeHandler.handle(context, buildSnapshot())

      expect(handled).assertFalse()
      done()
    })

    it('should report failure when pruning local data fails', 0, async (done: Function) => {
      let pruneMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.pruneUnavailableUsers)
      let currentModeMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getCurrentMode)

      when(pruneMock)(ArgumentMatchers.any).afterReturn(false)
      when(currentModeMock)(ArgumentMatchers.any).afterReturn('public')

      let handled = await FirewallAccountChangeHandler.handle(context, buildSnapshot())

      expect(handled).assertFalse()
      done()
    })
  })
}
