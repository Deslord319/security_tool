import { LogUtils } from '../../../utils/LogUtils'
import { taskpool } from '@kit.ArkTS'
import { AppInfo } from '../../../constants/AppConstants'
import { AdminErrorCodes } from '../../../constants/SystemErrorCodes'
import {
  AdminActivationState,
  EnterpriseAdminType
} from '../../../models/CommonModels'
import { CommonErrorUtils } from '../../../utils/CommonErrorUtils'
import { ErrorLike } from '../../../types/LooseValueTypes'
import { buildAdminActivationErrorMessage } from './EnterpriseAdminActivationMessages'
import { probeActivationTask } from './EnterpriseAdminProbeTask'

const TAG = 'EnterpriseAdminService'

export class EnterpriseAdminService {
  static readonly DEFAULT_ADMIN_TYPE: EnterpriseAdminType = 'byod'

  static buildEnableCommand(adminType: EnterpriseAdminType = EnterpriseAdminService.DEFAULT_ADMIN_TYPE): string {
    return `edm enable-admin -n ${AppInfo.BUNDLE_NAME} -a ${AppInfo.ADMIN_ABILITY_NAME} -t ${adminType}`
  }

  static isAdminMissingError(err: ErrorLike): boolean {
    return CommonErrorUtils.extractErrorCode(err) === AdminErrorCodes.ADMIN_NOT_ACTIVATED
  }

  static buildActivationErrorMessage(code?: number): string {
    return buildAdminActivationErrorMessage(code)
  }

  static probeActivation(adminType: EnterpriseAdminType = EnterpriseAdminService.DEFAULT_ADMIN_TYPE): AdminActivationState {
    return probeActivationTask(adminType)
  }

  static async probeActivationAsync(
    adminType: EnterpriseAdminType = EnterpriseAdminService.DEFAULT_ADMIN_TYPE
  ): Promise<AdminActivationState> {
    try {
      let result = await taskpool.execute(probeActivationTask, adminType) as AdminActivationState | undefined
      if (result && typeof result.activated === 'boolean') {
        return result
      }
      if (adminType === EnterpriseAdminService.DEFAULT_ADMIN_TYPE) {
        return EnterpriseAdminService.probeActivation()
      }
      return EnterpriseAdminService.probeActivation(adminType)
    } catch (err) {
      const error: ErrorLike = err as ErrorLike
      const code: number | undefined = CommonErrorUtils.extractErrorCode(error)
      LogUtils.warn(TAG, `probeActivationAsync failed: ${JSON.stringify(err)}`)
      return {
        activated: false,
        errorCode: code,
        errorMessage: EnterpriseAdminService.buildActivationErrorMessage(code),
        enableCommand: EnterpriseAdminService.buildEnableCommand(adminType),
        adminType: adminType
      } as AdminActivationState
    }
  }
}
