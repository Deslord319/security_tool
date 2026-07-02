import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'

import { AccountChangeEventBus } from '../../main/ets/services/account/AccountChangeEventBus'
import { AccountChangeHandler } from '../../main/ets/services/account/AccountChangeHandler'
import { AccountChangeCoordinator } from '../../main/ets/services/account/AccountChangeCoordinator'
import { AccountSnapshotChange } from '../../main/ets/services/account/AccountSnapshotModels'
import { UserFirewallListResult, UserFirewallOption } from '../../main/ets/services/firewall/FirewallModels'
import { SystemUserProvider } from '../../main/ets/services/firewall/providers/SystemUserProvider'

class CaptureAccountChangeHandler implements AccountChangeHandler {
  name: string = 'test-account-change-coordinator'
  snapshots: AccountSnapshotChange[] = []

  async handle(_context: common.Context, snapshot: AccountSnapshotChange): Promise<boolean> {
    this.snapshots.push(snapshot)
    return true
  }
}

function buildUsers(userIds: number[]): UserFirewallOption[] {
  return userIds.map((userId: number): UserFirewallOption => {
    return {
      userId: userId,
      label: `User ${userId}`
    }
  })
}

function buildUserResult(userIds: number[]): UserFirewallListResult {
  return {
    users: buildUsers(userIds),
    selectedUserId: userIds[0]
  }
}

export default function firewallAccountChangeCoordinatorTest() {
  describe('AccountChangeCoordinator', () => {
    let mockKit: MockKit
    let context: common.Context

    beforeEach(() => {
      mockKit = new MockKit()
      context = {} as common.Context
    })

    afterEach(() => {
      AccountChangeCoordinator.unregisterHandler('test-account-change-coordinator')
      mockKit.clearAll()
    })

    it('should debounce account changes with the default delay', 0, () => {
      expect(AccountChangeCoordinator.resolveDebounceMs()).assertEqual(400)
    })

    it('should bound account-added stable snapshot retry to about one second', 0, () => {
      expect(AccountChangeCoordinator.resolveAccountAddedStableRetryIntervalMs()).assertEqual(200)
      expect(AccountChangeCoordinator.resolveAccountAddedStableMaxRetries()).assertEqual(5)
    })

    it('should wait until added account appears before dispatching handlers', 0, async (done: Function) => {
      let queryCount = 0
      let publishCount = 0
      let publishedSignature = ''
      let handler = new CaptureAccountChangeHandler()
      let userMock = mockKit.mockFunc(SystemUserProvider, SystemUserProvider.loadAvailableUserIds)
      let publishMock = mockKit.mockFunc(AccountChangeEventBus, AccountChangeEventBus.publishSnapshot)
      when(userMock)().afterAction((): UserFirewallListResult => {
        queryCount++
        return queryCount === 1 ? buildUserResult([100, 122]) : buildUserResult([100, 122, 123])
      })
      when(publishMock)(ArgumentMatchers.any).afterAction((snapshot: AccountSnapshotChange): void => {
        publishCount++
        publishedSignature = snapshot.signature
      })
      AccountChangeCoordinator.registerHandler(handler)

      let success = await AccountChangeCoordinator.reconcileNow(context, 'account-added', 123)

      expect(success).assertTrue()
      expect(queryCount).assertEqual(2)
      expect(handler.snapshots.length).assertEqual(1)
      expect(handler.snapshots[0].signature).assertEqual('100,122,123')
      expect(handler.snapshots[0].currentUserIds.includes(123)).assertTrue()
      expect(publishCount).assertEqual(1)
      expect(publishedSignature).assertEqual('100,122,123')
      done()
    })

    it('should not dispatch stale snapshot when added account never appears', 0, async (done: Function) => {
      let queryCount = 0
      let publishCount = 0
      let handler = new CaptureAccountChangeHandler()
      let userMock = mockKit.mockFunc(SystemUserProvider, SystemUserProvider.loadAvailableUserIds)
      let publishMock = mockKit.mockFunc(AccountChangeEventBus, AccountChangeEventBus.publishSnapshot)
      when(userMock)().afterAction((): UserFirewallListResult => {
        queryCount++
        return buildUserResult([100, 122])
      })
      when(publishMock)(ArgumentMatchers.any).afterAction((_snapshot: AccountSnapshotChange): void => {
        publishCount++
      })
      AccountChangeCoordinator.registerHandler(handler)

      let success = await AccountChangeCoordinator.reconcileNow(context, 'account-added', 123)

      expect(success).assertFalse()
      expect(queryCount).assertEqual(AccountChangeCoordinator.resolveAccountAddedStableMaxRetries() + 1)
      expect(handler.snapshots.length).assertEqual(0)
      expect(publishCount).assertEqual(0)
      done()
    })

    it('should not wait for account-removed snapshots', 0, async (done: Function) => {
      let queryCount = 0
      let publishCount = 0
      let handler = new CaptureAccountChangeHandler()
      let userMock = mockKit.mockFunc(SystemUserProvider, SystemUserProvider.loadAvailableUserIds)
      let publishMock = mockKit.mockFunc(AccountChangeEventBus, AccountChangeEventBus.publishSnapshot)
      when(userMock)().afterAction((): UserFirewallListResult => {
        queryCount++
        return buildUserResult([100, 122])
      })
      when(publishMock)(ArgumentMatchers.any).afterAction((_snapshot: AccountSnapshotChange): void => {
        publishCount++
      })
      AccountChangeCoordinator.registerHandler(handler)

      let success = await AccountChangeCoordinator.reconcileNow(context, 'account-removed', 123)

      expect(success).assertTrue()
      expect(queryCount).assertEqual(1)
      expect(handler.snapshots.length).assertEqual(1)
      expect(publishCount).assertEqual(1)
      done()
    })
  })
}
