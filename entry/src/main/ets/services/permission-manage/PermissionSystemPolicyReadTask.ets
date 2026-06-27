import {
  ApplicationControlLists,
  ApplicationControlRepository
} from './ApplicationControlRepository'
import { ApplicationNetworkPolicyRepository } from './ApplicationNetworkPolicyRepository'
import { LogUtils } from '../../utils/LogUtils'

export interface PermissionSystemPolicyReadResult {
  controlLists: ApplicationControlLists
  restrictedAppUids: string[]
}

@Concurrent
export function readPermissionSystemPolicyTask(accountId: number): PermissionSystemPolicyReadResult {
  try {
    return {
      controlLists: ApplicationControlRepository.loadControlLists(accountId),
      restrictedAppUids: ApplicationNetworkPolicyRepository.loadRestrictedAppUids()
    } as PermissionSystemPolicyReadResult
  } catch (err) {
    LogUtils.warn('PermissionSystemPolicyReadTask', `read system policies failed: ${JSON.stringify(err)}`)
    return {
      controlLists: ApplicationControlRepository.createEmptyControlLists(),
      restrictedAppUids: []
    } as PermissionSystemPolicyReadResult
  }
}
