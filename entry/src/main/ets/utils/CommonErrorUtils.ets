/**
 * 通用错误处理工具类
 * 提供统一的错误处理相关方法
 */
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
    if (action === '读取用户列表') {
      switch (code) {
        case 201:
          return '缺少系统用户列表读取权限'
        case 12300001:
        case 2100002:
          return '系统账号服务连接失败'
        default:
          return `${action}失败`
      }
    }
    switch (code) {
      case 201:
        return '缺少账户或防火墙管理权限'
      case 401:
      case 2100001:
        return '用户 ID 参数不合法'
      case 2100002:
        return '系统服务连接失败'
      case 2100003:
        return '系统内部错误'
      case 29400000:
        return '目标用户不存在或已失效'
      default:
        return `${action}失败`
    }
  }
}
