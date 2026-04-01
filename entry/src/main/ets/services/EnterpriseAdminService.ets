import { LogUtils } from './utils/LogUtils'
import restrictions from '@ohos.enterprise.restrictions'
import common from '@ohos.app.ability.common'
import { Want } from '@kit.AbilityKit'
import { adminManager } from '@kit.MDMKit'

import { AppInfo } from '../constants/AppConstants'
import { AdminActivationState, EnterpriseAdminType, OperationResult } from '../models/DataModels'
import { CommonErrorUtils } from '../utils/CommonErrorUtils'

const TAG = 'EnterpriseAdminService'
const DOMAIN = 0x0007
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

  static activateAdminWithResult(
    context: common.Context,
    adminType: EnterpriseAdminType = EnterpriseAdminService.DEFAULT_ADMIN_TYPE
  ): OperationResult<void> {
    if (adminType !== 'byod') {
      return {
        success: false,
        errorMessage: '当前仅支持 BYOD 模式应用内激活',
        suggestion: `请执行：${EnterpriseAdminService.buildEnableCommand(adminType)}`
      } as OperationResult<void>
    }

    try {
      adminManager.startAdminProvision(ADMIN_WANT, adminManager.AdminType.ADMIN_TYPE_BYOD, context, {})
      return {
        success: true
      } as OperationResult<void>
    } catch (err) {
      let code = CommonErrorUtils.extractErrorCode(err as Object)
      let message = code !== undefined ? `管理员激活拉起失败（错误码 ${code}）` : '管理员激活拉起失败'
      LogUtils.error(TAG, `activateAdminWithResult failed: ${JSON.stringify(err)}`)
      return {
        success: false,
        errorCode: code,
        errorMessage: message
      } as OperationResult<void>
    }
  }

  static isAdminMissingError(err: Object): boolean {
    return CommonErrorUtils.extractErrorCode(err) === ADMIN_MISSING_ERROR_CODE
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
      let code = CommonErrorUtils.extractErrorCode(err as Object)
      let message = EnterpriseAdminService.isAdminMissingError(err as Object) ?
        '企业管理员未激活' :
        (code !== undefined ? `管理员状态检查失败（错误码 ${code}）` : '管理员状态检查失败')
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
