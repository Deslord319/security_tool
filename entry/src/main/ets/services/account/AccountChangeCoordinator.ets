import { common } from '@kit.AbilityKit'
import { AccountChangeSource, AccountSnapshotChange, buildAccountUserIdsSignature, normalizeAccountUserIds } from './AccountSnapshotModels'
import { AccountChangeHandler } from './AccountChangeHandler'
import { AccountChangeEventBus } from './AccountChangeEventBus'
import { UserFirewallOption } from '../firewall/FirewallModels'
import { SystemUserProvider } from '../firewall/providers/SystemUserProvider'
import { LogUtils } from '../../utils/LogUtils'

const TAG = 'AccountChangeCoordinator'
const ACCOUNT_CHANGE_DEBOUNCE_MS = 400

interface AccountChangeRequest {
  context: common.Context
  source: AccountChangeSource
  triggerAccountId?: number
}

export class AccountChangeCoordinator {
  private static timerId: number = -1
  private static running: boolean = false
  private static pendingRequest: AccountChangeRequest | null = null
  private static previousUserIds: number[] = []
  private static handlers: AccountChangeHandler[] = []

  static registerHandler(handler: AccountChangeHandler): void {
    AccountChangeCoordinator.handlers = AccountChangeCoordinator.handlers
      .filter((item: AccountChangeHandler): boolean => item.name !== handler.name)
    AccountChangeCoordinator.handlers.push(handler)
  }

  static unregisterHandler(name: string): void {
    AccountChangeCoordinator.handlers = AccountChangeCoordinator.handlers
      .filter((item: AccountChangeHandler): boolean => item.name !== name)
  }

  static schedule(
    context: common.Context,
    source: AccountChangeSource,
    triggerAccountId?: number
  ): void {
    AccountChangeCoordinator.pendingRequest = {
      context: context,
      source: source,
      triggerAccountId: triggerAccountId
    } as AccountChangeRequest
    if (AccountChangeCoordinator.timerId >= 0) {
      clearTimeout(AccountChangeCoordinator.timerId)
    }
    AccountChangeCoordinator.timerId = setTimeout(() => {
      AccountChangeCoordinator.timerId = -1
      AccountChangeCoordinator.runPending().catch((err: Error) => {
        LogUtils.error(TAG, `runPending failed: ${JSON.stringify(err)}`)
      })
    }, AccountChangeCoordinator.resolveDebounceMs())
  }

  static async reconcileNow(
    context: common.Context,
    source: AccountChangeSource = 'manual',
    triggerAccountId?: number
  ): Promise<boolean> {
    AccountChangeCoordinator.pendingRequest = {
      context: context,
      source: source,
      triggerAccountId: triggerAccountId
    } as AccountChangeRequest
    return await AccountChangeCoordinator.runPending()
  }

  private static async runPending(): Promise<boolean> {
    if (AccountChangeCoordinator.running) {
      return true
    }

    AccountChangeCoordinator.running = true
    let allSuccess = true
    try {
      while (AccountChangeCoordinator.pendingRequest !== null) {
        let request = AccountChangeCoordinator.pendingRequest
        AccountChangeCoordinator.pendingRequest = null
        let success = await AccountChangeCoordinator.runOnce(request)
        allSuccess = allSuccess && success
      }
    } finally {
      AccountChangeCoordinator.running = false
    }
    return allSuccess
  }

  private static async runOnce(request: AccountChangeRequest): Promise<boolean> {
    let result = await SystemUserProvider.loadAvailableUserIds()
    let currentUserIds = normalizeAccountUserIds(result.users.map((user: UserFirewallOption): number => user.userId))
    let snapshot = AccountChangeCoordinator.buildSnapshot(
      request,
      result.users,
      currentUserIds,
      result.message
    )
    AccountChangeCoordinator.previousUserIds = currentUserIds
    let success = await AccountChangeCoordinator.dispatchHandlers(request.context, snapshot)
    if (success) {
      AccountChangeEventBus.publishSnapshot(snapshot)
    }
    return success
  }

  static resolveDebounceMs(): number {
    return ACCOUNT_CHANGE_DEBOUNCE_MS
  }

  private static async dispatchHandlers(context: common.Context, snapshot: AccountSnapshotChange): Promise<boolean> {
    if (AccountChangeCoordinator.handlers.length === 0) {
      LogUtils.warn(TAG, 'skip account snapshot because no account change handler is registered')
      return true
    }
    let allSuccess = true
    for (let i = 0; i < AccountChangeCoordinator.handlers.length; i++) {
      let handler = AccountChangeCoordinator.handlers[i]
      try {
        let success = await handler.handle(context, snapshot)
        allSuccess = allSuccess && success
        if (!success) {
          LogUtils.warn(TAG, 'account change handler failed | name=%{public}s', handler.name)
        }
      } catch (err) {
        allSuccess = false
        LogUtils.error(TAG, `account change handler threw: name=${handler.name}, err=${JSON.stringify(err)}`)
      }
    }
    return allSuccess
  }

  private static buildSnapshot(
    request: AccountChangeRequest,
    users: UserFirewallOption[],
    currentUserIds: number[],
    message?: string
  ): AccountSnapshotChange {
    let previousUserIds = AccountChangeCoordinator.previousUserIds
    let currentUserIdSet = new Set<number>(currentUserIds)
    let previousUserIdSet = new Set<number>(previousUserIds)
    let addedUserIds = currentUserIds.filter((userId: number): boolean => !previousUserIdSet.has(userId))
    let removedUserIds = previousUserIds.filter((userId: number): boolean => !currentUserIdSet.has(userId))
    return {
      source: request.source,
      triggerAccountId: request.triggerAccountId,
      users: users,
      currentUserIds: currentUserIds,
      addedUserIds: addedUserIds,
      removedUserIds: removedUserIds,
      signature: buildAccountUserIdsSignature(currentUserIds),
      previousSignature: buildAccountUserIdsSignature(previousUserIds),
      message: message
    } as AccountSnapshotChange
  }
}
