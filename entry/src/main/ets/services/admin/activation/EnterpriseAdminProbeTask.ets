import { LogUtils } from '../../../utils/LogUtils'
import restrictions from '@ohos.enterprise.restrictions'
import { AppInfo, ADMIN_WANT } from '../../../constants/AppConstants'
import { AdminText } from '../../../constants/StringCatalog'
import { AdminActivationState, EnterpriseAdminType } from '../../../models/DataModels'
import { CommonErrorUtils } from '../../../utils/CommonErrorUtils'
import { ErrorLike } from '../../../types/LooseValueTypes'

@Concurrent
export function probeActivationTask(adminType: EnterpriseAdminType): AdminActivationState {
  const command: string = `edm enable-admin -n ${AppInfo.BUNDLE_NAME} -a ${AppInfo.ADMIN_ABILITY_NAME} -t ${adminType}`
  try {
    restrictions.getDisallowedPolicy(ADMIN_WANT, 'usb')
    return {
      activated: true,
      enableCommand: command,
      adminType: adminType
    } as AdminActivationState
  } catch (err) {
    const error: ErrorLike = err as ErrorLike
    const code: number | undefined = CommonErrorUtils.extractErrorCode(error)
    const message: string = code === 9200001
      ? AdminText.NOT_ACTIVATED
      : AdminText.buildCheckFailed(code)
    LogUtils.warn('EnterpriseAdminService', `probeActivation failed: ${JSON.stringify(err)}`)
    return {
      activated: false,
      errorCode: code,
      errorMessage: message,
      enableCommand: command,
      adminType: adminType
    } as AdminActivationState
  }
}
