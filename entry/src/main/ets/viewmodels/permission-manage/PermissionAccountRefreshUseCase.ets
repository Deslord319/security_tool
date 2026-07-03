import {
  ApplicationInventoryResult,
  PermissionAccountListResult,
  PermissionAppSnapshot,
  PermissionInitialData,
  PermissionManagedAccount,
  PermissionPageState
} from '../../models/PermissionModels'
import { PermissionStateReducer } from './PermissionStateReducer'

export class PermissionAccountRefreshUseCase {
  static applyInitialData(state: PermissionPageState, initialData: PermissionInitialData): boolean {
    state.selectedAccountId = initialData.selectedAccountId
    state.accounts = initialData.accounts
    return PermissionStateReducer.commit(state, {
      appSnapshots: initialData.appSnapshots,
      installPolicies: initialData.installPolicies,
      selectedAppKey: initialData.selectedAppKey,
      inventoryMessage: initialData.inventoryMessage
    })
  }

  static resolveRefreshedAccountId(state: PermissionPageState, accountResult: PermissionAccountListResult): number {
    let currentExists = accountResult.accounts.some((account: PermissionManagedAccount): boolean =>
      account.accountId === state.selectedAccountId
    )
    if (currentExists) {
      return state.selectedAccountId
    }
    let fallbackExists = accountResult.accounts.some((account: PermissionManagedAccount): boolean =>
      account.accountId === accountResult.selectedAccountId
    )
    if (fallbackExists || accountResult.accounts.length === 0) {
      return accountResult.selectedAccountId
    }
    return accountResult.accounts[0].accountId
  }

  static applyInventory(state: PermissionPageState, inventory: ApplicationInventoryResult): boolean {
    let appSnapshots = inventory.appSnapshots.length > 0
      ? PermissionStateReducer.mergePolicySnapshots(state, inventory.appSnapshots)
      : []
    return PermissionStateReducer.commit(state, {
      appSnapshots: appSnapshots,
      installPolicies: inventory.installPolicies,
      inventoryMessage: inventory.message ?? ''
    })
  }

  static applyApplicationList(state: PermissionPageState, inventory: ApplicationInventoryResult): boolean {
    return PermissionStateReducer.commit(state, {
      appSnapshots: PermissionStateReducer.mergePolicySnapshots(state, inventory.appSnapshots),
      installPolicies: inventory.installPolicies,
      inventoryMessage: inventory.message ?? ''
    })
  }

  static reconcileSelectedApplicationAfterRefresh(
    state: PermissionPageState,
    previousSelectedSnapshot: PermissionAppSnapshot | undefined
  ): boolean {
    return PermissionStateReducer.reconcileSelectedApplicationAfterRefresh(state, previousSelectedSnapshot)
  }
}
