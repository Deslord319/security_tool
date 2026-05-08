import { securityManager } from '@kit.MDMKit'
import { taskpool } from '@kit.ArkTS'
import { OperationResult, PasswordComplexityConfig } from '../../../models/DataModels'
import { OperationResultUtils } from '../../common/OperationResultUtils'
import { IdentityActionStrings } from '../../../constants/modules/IdentityStrings'
import { ErrorLike } from '../../../types/LooseValueTypes'
import {
  getPasswordPolicyWithResultTask,
  setPasswordPolicyWithResultTask
} from './IdentityPasswordPolicyTasks'

export class IdentityService {
  static setPasswordPolicyWithResult(config: PasswordComplexityConfig): OperationResult<void> {
    return setPasswordPolicyWithResultTask(config)
  }

  static getPasswordPolicyWithResult(): OperationResult<securityManager.PasswordPolicy | null> {
    return getPasswordPolicyWithResultTask()
  }

  static async getPasswordPolicyWithResultAsync(): Promise<OperationResult<securityManager.PasswordPolicy | null>> {
    try {
      let result = await taskpool.execute(getPasswordPolicyWithResultTask) as OperationResult<securityManager.PasswordPolicy | null> | undefined
      if (result && typeof result.success === 'boolean') {
        return result
      }
      return IdentityService.getPasswordPolicyWithResult()
    } catch (err) {
      return OperationResultUtils.buildFailureResult<securityManager.PasswordPolicy | null>(
        IdentityActionStrings.READ_PASSWORD_POLICY,
        err as ErrorLike,
        null
      )
    }
  }
}
