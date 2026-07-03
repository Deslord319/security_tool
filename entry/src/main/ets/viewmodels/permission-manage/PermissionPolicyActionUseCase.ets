import {
  ApplicationInventoryResult,
  PermissionActionResult,
  PermissionAppSnapshot,
  PermissionManagedAccount,
  PermissionPageState,
  PermissionPolicyRecord
} from '../../models/PermissionModels'
import { MessageText } from '../../constants/StringCatalog'
import {
  PermissionAccountStrings,
  PermissionApplicationStrings,
  PermissionEmptyStrings
} from '../../constants/modules/PermissionStrings'
import { PermissionService } from '../../services/permission-manage/PermissionService'
import { LogUtils } from '../../utils/LogUtils'
import { PermissionAccountRefreshUseCase } from './PermissionAccountRefreshUseCase'
import { PermissionStateReducer, PermissionStateUpdate } from './PermissionStateReducer'

const TAG = 'PermissionPolicyActionUseCase'

export interface PreparedSelectedAppContext extends PermissionActionResult {
  snapshot?: PermissionAppSnapshot
}

export interface PreparedPolicyRecordContext extends PermissionActionResult {
  record?: PermissionPolicyRecord
}

export class PermissionPolicyActionUseCase {
  static async prepareAccountContextForAction(
    state: PermissionPageState,
    clearSelectedApplication: () => void,
    applyApplicationList: (inventory: ApplicationInventoryResult) => void,
    commitState: (update: PermissionStateUpdate) => void
  ): Promise<PermissionActionResult> {
    try {
      let accountResult = await PermissionService.loadAccounts()
      let currentExists = accountResult.accounts.some((account: PermissionManagedAccount): boolean =>
        account.accountId === state.selectedAccountId
      )
      state.accounts = accountResult.accounts
      if (currentExists) {
        return { success: true, message: '' } as PermissionActionResult
      }

      let nextAccountId = PermissionAccountRefreshUseCase.resolveRefreshedAccountId(state, accountResult)
      state.selectedAccountId = nextAccountId
      clearSelectedApplication()
      if (accountResult.accounts.length === 0) {
        commitState({
          appSnapshots: [],
          installPolicies: [],
          inventoryMessage: accountResult.message ?? PermissionAccountStrings.NO_ACCOUNTS
        })
        return {
          success: false,
          message: PermissionApplicationStrings.ACCOUNT_CONTEXT_CHANGED
        } as PermissionActionResult
      }

      let inventory = await PermissionService.loadApplications(nextAccountId)
      applyApplicationList(inventory)
      return {
        success: false,
        message: PermissionApplicationStrings.ACCOUNT_CONTEXT_CHANGED
      } as PermissionActionResult
    } catch (err) {
      LogUtils.warn(TAG, `prepareAccountContextForAction failed: ${JSON.stringify(err)}`)
      return { success: false, message: MessageText.RETRY_LATER } as PermissionActionResult
    }
  }

  static async prepareSelectedAppContextForAction(
    state: PermissionPageState,
    clearSelectedApplication: () => void,
    applyApplicationList: (inventory: ApplicationInventoryResult) => void,
    commitState: (update: PermissionStateUpdate) => void
  ): Promise<PreparedSelectedAppContext> {
    let selectedAppKey = state.selectedAppKey
    if (selectedAppKey.length === 0) {
      return {
        success: false,
        message: PermissionEmptyStrings.SELECT_APPLICATION_FIRST
      } as PreparedSelectedAppContext
    }
    let previousSnapshot = PermissionStateReducer.findAppSnapshot(state, selectedAppKey)
    let accountPrepared = await PermissionPolicyActionUseCase.prepareAccountContextForAction(
      state,
      clearSelectedApplication,
      applyApplicationList,
      commitState
    )
    if (!accountPrepared.success) {
      return {
        success: false,
        message: accountPrepared.message
      } as PreparedSelectedAppContext
    }

    try {
      let inventory = await PermissionService.loadApplications(state.selectedAccountId)
      if (PermissionPolicyActionUseCase.isInventoryLoadFailed(inventory)) {
        return { success: false, message: MessageText.RETRY_LATER } as PreparedSelectedAppContext
      }
      applyApplicationList(inventory)
      let refreshedSnapshot = PermissionStateReducer.findAppSnapshot(state, selectedAppKey)
      if (refreshedSnapshot === undefined) {
        clearSelectedApplication()
        return {
          success: false,
          message: PermissionApplicationStrings.APPLICATION_CONTEXT_CHANGED
        } as PreparedSelectedAppContext
      }
      if (previousSnapshot === undefined ||
        !PermissionStateReducer.isSameApplicationIdentity(previousSnapshot, refreshedSnapshot)) {
        clearSelectedApplication()
        return {
          success: false,
          message: PermissionApplicationStrings.APPLICATION_CONTEXT_CHANGED
        } as PreparedSelectedAppContext
      }
      return {
        success: true,
        message: '',
        snapshot: refreshedSnapshot
      } as PreparedSelectedAppContext
    } catch (err) {
      LogUtils.warn(TAG, `prepareSelectedAppContextForAction failed: ${JSON.stringify(err)}`)
      return { success: false, message: MessageText.RETRY_LATER } as PreparedSelectedAppContext
    }
  }

  static async preparePolicyRecordForDelete(
    state: PermissionPageState,
    record: PermissionPolicyRecord,
    clearSelectedApplication: () => void,
    applyApplicationList: (inventory: ApplicationInventoryResult) => void,
    commitState: (update: PermissionStateUpdate) => void
  ): Promise<PreparedPolicyRecordContext> {
    let previousApp = PermissionStateReducer.isApplicationPolicyRecord(record.actionKind)
      ? PermissionStateReducer.findAppSnapshot(state, record.appKey)
      : undefined
    let accountPrepared = await PermissionPolicyActionUseCase.prepareAccountContextForAction(
      state,
      clearSelectedApplication,
      applyApplicationList,
      commitState
    )
    if (!accountPrepared.success) {
      return {
        success: false,
        message: accountPrepared.message
      } as PreparedPolicyRecordContext
    }
    try {
      let inventory = await PermissionService.loadApplications(state.selectedAccountId)
      if (PermissionPolicyActionUseCase.isInventoryLoadFailed(inventory)) {
        return { success: false, message: MessageText.RETRY_LATER } as PreparedPolicyRecordContext
      }
      applyApplicationList(inventory)
      let refreshedRecord = state.policyRecords.find((item: PermissionPolicyRecord): boolean => item.key === record.key)
      if (refreshedRecord === undefined) {
        return {
          success: false,
          message: PermissionApplicationStrings.POLICY_CONTEXT_CHANGED
        } as PreparedPolicyRecordContext
      }
      let refreshedApp = previousApp === undefined ? undefined : PermissionStateReducer.findAppSnapshot(state, record.appKey)
      if (previousApp !== undefined &&
        (refreshedApp === undefined || !PermissionStateReducer.isSameApplicationIdentity(previousApp, refreshedApp))) {
        if (state.selectedAppKey === record.appKey) {
          clearSelectedApplication()
        }
        return {
          success: false,
          message: PermissionApplicationStrings.POLICY_CONTEXT_CHANGED
        } as PreparedPolicyRecordContext
      }
      return {
        success: true,
        message: '',
        record: refreshedRecord
      } as PreparedPolicyRecordContext
    } catch (err) {
      LogUtils.warn(TAG, `preparePolicyRecordForDelete failed: ${JSON.stringify(err)}`)
      return { success: false, message: MessageText.RETRY_LATER } as PreparedPolicyRecordContext
    }
  }

  private static isInventoryLoadFailed(inventory: ApplicationInventoryResult): boolean {
    return inventory.message === PermissionEmptyStrings.INVENTORY_LOAD_FAILED
  }
}
