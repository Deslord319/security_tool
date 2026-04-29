import { LogUtils } from '../../../utils/LogUtils'
import restrictions from '@ohos.enterprise.restrictions'
import { taskpool } from '@kit.ArkTS'
import { AppInfo, ADMIN_WANT } from '../../../constants/AppConstants'
import { AdminText } from '../../../constants/StringCatalog'
import { AdminActivationState, EnterpriseAdminType } from '../../../models/DataModels'
import { CommonErrorUtils } from '../../../utils/CommonErrorUtils'
import { AdminErrorStrings } from '../../../constants/modules/ErrorStrings'
import { ErrorLike } from '../../../types/LooseValueTypes'
import { probeActivationTask } from './EnterpriseAdminProbeTask'

const TAG = 'EnterpriseAdminService'
const ADMIN_MISSING_ERROR_CODE = 9200001

export class EnterpriseAdminService {
  static readonly DEFAULT_ADMIN_TYPE: EnterpriseAdminType = 'byod'

  static buildEnableCommand(adminType: EnterpriseAdminType = EnterpriseAdminService.DEFAULT_ADMIN_TYPE): string {
    return `edm enable-admin -n ${AppInfo.BUNDLE_NAME} -a ${AppInfo.ADMIN_ABILITY_NAME} -t ${adminType}`
  }

  static isAdminMissingError(err: ErrorLike): boolean {
    return CommonErrorUtils.extractErrorCode(err) === ADMIN_MISSING_ERROR_CODE
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
        errorMessage: AdminErrorStrings.buildCheckFailed(code),
        enableCommand: EnterpriseAdminService.buildEnableCommand(adminType),
        adminType: adminType
      } as AdminActivationState
    }
  }
}
