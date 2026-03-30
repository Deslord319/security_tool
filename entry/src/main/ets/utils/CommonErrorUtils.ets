/**
 * 通用错误处理工具类
 * 提供统一的错误处理相关方法
 */
import { PermissionErrors, SystemServiceErrors, ErrorTemplates } from '../constants/modules/ErrorStrings'

export interface ErrorRecorder {
  lastErrorCode: number | undefined
  lastErrorMessage: string
}

export class CommonErrorUtils {
  /**
   * 从错误对象中提取错误码
   */
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

  /**
   * 从错误对象中提取错误消息
   */
  static extractErrorMessage(err: Object): string {
    let messageValue = (err as Record<string, Object>)['message']
    if (typeof messageValue === 'string') {
      return messageValue
    }
    let dataValue = (err as Record<string, Object>)['data']
    if (typeof dataValue === 'string') {
      return dataValue
    }
    return ''
  }

  /**
   * 清除错误状态
   */
  static clearLastError(recorder: ErrorRecorder): void {
    recorder.lastErrorCode = undefined
    recorder.lastErrorMessage = ''
  }

  /**
   * 根据操作和错误码解析错误消息
   */
  static resolveErrorMessage(action: string, code: number | undefined): string {
    if (action === PermissionErrors.READ_USER_LIST) {
      switch (code) {
        case 201:
          return PermissionErrors.MISSING_USER_LIST_PERMISSION
        case 12300001:
        case 2100002:
          return SystemServiceErrors.ACCOUNT_SERVICE_CONNECTION_FAILED
        default:
          return ErrorTemplates.ACTION_FAILED_TEMPLATE.replace('${action}', action)
      }
    }
    switch (code) {
      case 201:
        return PermissionErrors.MISSING_ACCOUNT_OR_FIREWALL_PERMISSION
      case 401:
      case 2100001:
        return PermissionErrors.INVALID_USER_ID_PARAM
      case 2100002:
        return SystemServiceErrors.SERVICE_CONNECTION_FAILED
      case 2100003:
        return SystemServiceErrors.INTERNAL_ERROR
      case 29400000:
        return SystemServiceErrors.USER_NOT_EXIST_OR_INVALID
      default:
        return ErrorTemplates.ACTION_FAILED_TEMPLATE.replace('${action}', action)
    }
  }
}
