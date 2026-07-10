import { taskpool } from '@kit.ArkTS'
import { ApplicationControlLists, ApplicationControlRepository } from './ApplicationControlRepository'
import { ApplicationNetworkPolicyRepository } from './ApplicationNetworkPolicyRepository'
import { LogUtils } from '../../utils/LogUtils'

const TAG = 'PermissionAccountPolicyTasks'

export interface PermissionAccountPolicySnapshotTaskData {
  controlLists: ApplicationControlLists
  restrictedAppUids: string[]
}

export interface PermissionAccountPolicySnapshotTaskResult {
  success: boolean
  data?: PermissionAccountPolicySnapshotTaskData
  message?: string
}

@Concurrent
export function loadAccountPolicySnapshotTask(accountId: number): PermissionAccountPolicySnapshotTaskResult {
  try {
    return {
      success: true,
      data: {
        controlLists: ApplicationControlRepository.loadControlListsStrict(accountId),
        restrictedAppUids: ApplicationNetworkPolicyRepository.loadRestrictedAppUidsStrict()
      } as PermissionAccountPolicySnapshotTaskData
    } as PermissionAccountPolicySnapshotTaskResult
  } catch (err) {
    LogUtils.warn('PermissionAccountPolicyTasks', `loadAccountPolicySnapshotTask failed: ${JSON.stringify(err)}`)
    return {
      success: false,
      message: `${err}`
    } as PermissionAccountPolicySnapshotTaskResult
  }
}

export class PermissionAccountPolicyTaskRunner {
  static async loadSnapshot(accountId: number): Promise<PermissionAccountPolicySnapshotTaskData> {
    let result: PermissionAccountPolicySnapshotTaskResult | undefined
    try {
      result = await taskpool.execute(loadAccountPolicySnapshotTask, accountId) as
        PermissionAccountPolicySnapshotTaskResult | undefined
    } catch (err) {
      LogUtils.warn(TAG, `taskpool loadSnapshot failed: ${JSON.stringify(err)}`)
      throw new Error('Failed to load account policy snapshot in taskpool')
    }
    if (result?.success && result.data !== undefined) {
      return result.data
    }
    let message = result?.message ?? 'empty result'
    LogUtils.warn(TAG, `taskpool loadSnapshot returned failure: ${message}`)
    throw new Error(`Failed to load account policy snapshot: ${message}`)
  }
}
