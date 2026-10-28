import { OperationResult } from '../../models/CommonModels'
import { EnterpriseAdminService } from '../admin/activation/EnterpriseAdminService'
import { ErrorLike } from '../../types/LooseValueTypes'
import { CommonErrorUtils } from '../../utils/CommonErrorUtils'
import { AppStrings } from '../../constants/AppStrings'

/**
 * 通用失败结果构造。
 *
 * message/suggestion 为用户可见文案，经 AppStrings 按当前 locale 解析，仅可在
 * 主线程调用；@Concurrent 任务线程不得调用本方法（静态文案门面在 worker 中
 * 不可见），任务内失败结果应返回空 errorMessage，由页面 displayReason 走
 * 本地化兜底文案。
 */
export class OperationResultUtils {
  static buildFailureResult<T>(action: string, err: ErrorLike, fallbackData?: T): OperationResult<T> {
    const code = CommonErrorUtils.extractErrorCode(err)
    const isAdminMissing = EnterpriseAdminService.isAdminMissingError(err)
    const message = isAdminMissing
      ? AppStrings.get('common_admin_not_activated')
      : AppStrings.format('common_operation_failed', action)
    const suggestion = isAdminMissing
      ? AppStrings.format('common_operation_enable_admin_hint', EnterpriseAdminService.buildEnableCommand())
      : AppStrings.get('common_operation_check_hint')
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
