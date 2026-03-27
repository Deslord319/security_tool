/**
 * 通用错误处理工具类
 * 提供统一的错误码提取方法
 */
export class CommonErrorUtils {
  /**
   * 从错误对象中提取错误码
   * @param err - 错误对象
   * @returns 错误码（数字）或 undefined
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
}
