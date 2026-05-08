/**
 * 通用错误处理工具类
 * 提供统一的错误处理相关方法
 */
import { ErrorLike, LooseValue } from '../types/LooseValueTypes'

export class CommonErrorUtils {
  private static getField(err: ErrorLike, key: string): LooseValue {
    return (err as Record<string, LooseValue>)[key]
  }
  /**
   * 从错误对象中提取错误码
   */
  static extractErrorCode(err: ErrorLike): number | undefined {
    let codeValue = CommonErrorUtils.getField(err, 'code')
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
  static extractErrorMessage(err: ErrorLike): string {
    let messageValue = CommonErrorUtils.getField(err, 'message')
    if (typeof messageValue === 'string') {
      return messageValue
    }
    let dataValue = CommonErrorUtils.getField(err, 'data')
    if (typeof dataValue === 'string') {
      return dataValue
    }
    return ''
  }

}
