import { BusinessError } from '@kit.BasicServicesKit'

export interface BusinessErrorInfo {
  code: number
  message: string
}

export class ErrorUtils {
  static toBusinessErrorInfo(err: Error | BusinessError | Object): BusinessErrorInfo {
    let code = typeof (err as BusinessError)?.code === 'number' ? (err as BusinessError).code : -1
    let message = typeof (err as Error)?.message === 'string' && (err as Error).message.length > 0 ?
      (err as Error).message : 'unknown'
    return { code: code, message: message }
  }
}
