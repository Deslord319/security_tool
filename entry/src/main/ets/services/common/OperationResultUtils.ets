import { OperationResult } from '../../models/CommonModels'
import { EnterpriseAdminService } from '../admin/activation/EnterpriseAdminService'
import { ErrorLike } from '../../types/LooseValueTypes'
import { CommonErrorUtils } from '../../utils/CommonErrorUtils'

export class OperationResultUtils {
  static buildFailureResult<T>(action: string, err: ErrorLike, fallbackData?: T): OperationResult<T> {
    const code = CommonErrorUtils.extractErrorCode(err)
    const isAdminMissing = EnterpriseAdminService.isAdminMissingError(err)
    const message = isAdminMissing
      ? 'enterprise admin is not enabled'
      : `${action} failed`
    const suggestion = isAdminMissing
      ? `please enable admin first: ${EnterpriseAdminService.buildEnableCommand()}`
      : 'please check permissions, signature and device policy state before retrying'
    return {
      success: false,
      data: fallbackData,
      errorCode: code,
      errorMessage: message,
      isAdminMissing: isAdminMissing,
      suggestion: suggestion
    } as OperationResult<T>
  }
}
