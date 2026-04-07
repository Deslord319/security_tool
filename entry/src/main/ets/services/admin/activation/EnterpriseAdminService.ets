import { LogUtils } from '../../../utils/LogUtils'
import restrictions from '@ohos.enterprise.restrictions'
import { Want } from '@kit.AbilityKit'
import { AppInfo } from '../../../constants/AppConstants'
import { AdminActivationState, EnterpriseAdminType } from '../../../models/DataModels'
import { CommonErrorUtils } from '../../../utils/CommonErrorUtils'
import { AdminErrorStrings } from '../../../constants/modules/ErrorStrings'

const TAG = 'EnterpriseAdminService'
const ADMIN_ABILITY_NAME = 'EnterpriseAdminAbility'
const ADMIN_MISSING_ERROR_CODE = 9200001

const ADMIN_WANT: Want = {
  bundleName: AppInfo.BUNDLE_NAME,
  abilityName: ADMIN_ABILITY_NAME
}

export class EnterpriseAdminService {
  static readonly DEFAULT_ADMIN_TYPE: EnterpriseAdminType = 'byod'

  static buildEnableCommand(adminType: EnterpriseAdminType = EnterpriseAdminService.DEFAULT_ADMIN_TYPE): string {
    return `edm enable-admin -n ${AppInfo.BUNDLE_NAME} -a ${ADMIN_ABILITY_NAME} -t ${adminType}`
  }

  static isAdminMissingError(err: Object): boolean {
    return CommonErrorUtils.extractErrorCode(err) === ADMIN_MISSING_ERROR_CODE
  }

  static probeActivation(adminType: EnterpriseAdminType = EnterpriseAdminService.DEFAULT_ADMIN_TYPE): AdminActivationState {
    const command: string = EnterpriseAdminService.buildEnableCommand(adminType)
    try {
      restrictions.getDisallowedPolicy(ADMIN_WANT, 'usb')
      return {
        activated: true,
        enableCommand: command,
        adminType: adminType
      } as AdminActivationState
    } catch (err) {
      const error: Object = err as Object
      const code: number | undefined = CommonErrorUtils.extractErrorCode(error)
      const message: string = EnterpriseAdminService.isAdminMissingError(error)
        ? AdminErrorStrings.notActivated
        : AdminErrorStrings.buildCheckFailed(code)
      LogUtils.warn(TAG, `probeActivation failed: ${JSON.stringify(err)}`)
      return {
        activated: false,
        errorCode: code,
        errorMessage: message,
        enableCommand: command,
        adminType: adminType
      } as AdminActivationState
    }
  }
}
