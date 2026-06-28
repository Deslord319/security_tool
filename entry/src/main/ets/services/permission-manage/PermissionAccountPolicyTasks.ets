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
    try {
      let result = await taskpool.execute(loadAccountPolicySnapshotTask, accountId) as
        PermissionAccountPolicySnapshotTaskResult | undefined
      if (result?.success && result.data !== undefined) {
        return result.data
      }
      LogUtils.warn(TAG, `taskpool loadSnapshot returned failure: ${result?.message ?? 'empty result'}`)
    } catch (err) {
      LogUtils.warn(TAG, `taskpool loadSnapshot failed, fallback to sync read: ${JSON.stringify(err)}`)
    }
    return PermissionAccountPolicyTaskRunner.loadSnapshotSync(accountId)
  }

  static loadSnapshotSync(accountId: number): PermissionAccountPolicySnapshotTaskData {
    return {
      controlLists: ApplicationControlRepository.loadControlListsStrict(accountId),
      restrictedAppUids: ApplicationNetworkPolicyRepository.loadRestrictedAppUidsStrict()
    } as PermissionAccountPolicySnapshotTaskData
  }
}
