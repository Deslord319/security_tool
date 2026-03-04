import restrictions from '@ohos.enterprise.restrictions'
import { Want } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { AppInfo } from '../constants/AppConstants'
import { AdminActivationState, EnterpriseAdminType } from '../models/DataModels'

const TAG = 'EnterpriseAdminService'
const DOMAIN = 0x0007
const ADMIN_ABILITY_NAME = 'EnterpriseAdminAbility'
const ADMIN_MISSING_ERROR_CODE = 9200001

const ADMIN_WANT: Want = {
  bundleName: AppInfo.BUNDLE_NAME,
  abilityName: ADMIN_ABILITY_NAME
}

export class EnterpriseAdminService {
  static readonly DEFAULT_ADMIN_TYPE: EnterpriseAdminType = 'super'

  static buildEnableCommand(adminType: EnterpriseAdminType = EnterpriseAdminService.DEFAULT_ADMIN_TYPE): string {
    return `edm enable-admin -n ${AppInfo.BUNDLE_NAME} -a ${ADMIN_ABILITY_NAME} -t ${adminType}`
  }

  static isAdminMissingError(err: Object): boolean {
    return EnterpriseAdminService.extractErrorCode(err) === ADMIN_MISSING_ERROR_CODE
  }

  static probeActivation(adminType: EnterpriseAdminType = EnterpriseAdminService.DEFAULT_ADMIN_TYPE): AdminActivationState {
    let command = EnterpriseAdminService.buildEnableCommand(adminType)
    try {
      // Non-mutating probe: a harmless policy read that requires activated admin context.
      restrictions.getDisallowedPolicy(ADMIN_WANT, 'usb')
      return {
        activated: true,
        enableCommand: command,
        adminType: adminType
      } as AdminActivationState
    } catch (err) {
      let code = EnterpriseAdminService.extractErrorCode(err as Object)
      let message = EnterpriseAdminService.isAdminMissingError(err as Object) ?
        '企业管理员未激活' :
        (code !== undefined ? `管理员状态检查失败（错误码 ${code}）` : '管理员状态检查失败')
      hilog.warn(DOMAIN, TAG, `probeActivation failed: ${JSON.stringify(err)}`)
      return {
        activated: false,
        errorCode: code,
        errorMessage: message,
        enableCommand: command,
        adminType: adminType
      } as AdminActivationState
    }
  }

  static extractErrorCode(err: Object): number | undefined {
    let codeValue = (err as Record<string, Object>)['code']
    if (typeof codeValue === 'number') {
      return codeValue
    }
    if (typeof codeValue === 'string') {
      let parsed = Number(codeValue)
      return Number.isNaN(parsed) ? undefined : parsed
    }
    return undefined
  }
}
