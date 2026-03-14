import { userAuth } from '@kit.UserAuthenticationKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { AuthMethod } from '../models/DataModels'

const TAG = 'AuthService'
const DOMAIN = 0x0004

export interface AuthAvailabilityResult {
  available: boolean
  message: string
  errorCode?: number
}

export type AuthExecutionReason = 'failed' | 'cancelled' | 'unavailable'

export interface AuthExecutionResult {
  success: boolean
  reason?: AuthExecutionReason
  errorCode?: number
  message?: string
}

export class AuthService {
  static isAuthAvailable(authType: userAuth.UserAuthType): boolean {
    try {
      userAuth.getAvailableStatus(authType, userAuth.AuthTrustLevel.ATL1)
      return true
    } catch (err) {
      let e = err as BusinessError
      hilog.warn(DOMAIN, TAG, `Auth type ${authType} not available: code=${e.code}, msg=${e.message}`)
      return false
    }
  }

  static checkAuthMethodAvailability(authMethod: AuthMethod): AuthAvailabilityResult {
    let authType = AuthService.convertAuthMethod(authMethod)
    if (authType === null) {
      return {
        available: false,
        message: '\u5f53\u524d\u8bbe\u5907\u4e0d\u652f\u6301\u8be5\u8ba4\u8bc1\u65b9\u5f0f'
      }
    }

    try {
      userAuth.getAvailableStatus(authType, userAuth.AuthTrustLevel.ATL1)
      return {
        available: true,
        message: '\u7cfb\u7edf\u8ba4\u8bc1\u53ef\u7528'
      }
    } catch (err) {
      let e = err as BusinessError
      let mapped = AuthService.mapAuthError(authMethod, e.code, e.message)
      hilog.warn(DOMAIN, TAG, `Auth method ${authMethod} unavailable: code=${mapped.errorCode}, msg=${mapped.message}`)
      return mapped
    }
  }

  static getAuthMethodLabel(method: AuthMethod): string {
    switch (method) {
      case AuthMethod.PIN:
        return 'PIN'
      case AuthMethod.FINGERPRINT:
        return '\u6307\u7eb9'
      default:
        return '\u8ba4\u8bc1\u65b9\u5f0f'
    }
  }

  static async authenticate(authMethod: AuthMethod, challenge?: Uint8Array): Promise<AuthExecutionResult> {
    try {
      let authType = AuthService.convertAuthMethod(authMethod)
      if (authType === null) {
        hilog.error(DOMAIN, TAG, `Unsupported auth method: ${authMethod}`)
        return {
          success: false,
          reason: 'unavailable',
          message: '\u5f53\u524d\u8bbe\u5907\u4e0d\u652f\u6301\u8be5\u8ba4\u8bc1\u65b9\u5f0f'
        }
      }

      let authChallenge: Uint8Array
      if (challenge && challenge.length >= 8) {
        authChallenge = challenge
      } else {
        authChallenge = new Uint8Array(8)
        for (let i = 0; i < 8; i++) {
          authChallenge[i] = Math.floor(Math.random() * 256)
        }
      }

      let authParam: userAuth.AuthParam = {
        challenge: authChallenge,
        authType: [authType],
        authTrustLevel: userAuth.AuthTrustLevel.ATL1
      }

      let widgetParam: userAuth.WidgetParam = {
        title: '\u8eab\u4efd\u9a8c\u8bc1'
      }

      let userAuthInstance = userAuth.getUserAuthInstance(authParam, widgetParam)

      return new Promise<AuthExecutionResult>((resolve) => {
        userAuthInstance.on('result', {
          onResult(result: userAuth.UserAuthResult) {
            hilog.info(DOMAIN, TAG, `Auth result code: ${result.result}, SUCCESS code: ${userAuth.UserAuthResultCode.SUCCESS}`)
            userAuthInstance.off('result')
            if (result.result === userAuth.UserAuthResultCode.SUCCESS) {
              resolve({ success: true })
              return
            }

            if (AuthService.isUnavailableErrorCode(result.result)) {
              let mapped = AuthService.mapAuthError(authMethod, result.result)
              resolve({
                success: false,
                reason: 'unavailable',
                errorCode: mapped.errorCode,
                message: mapped.message
              })
              return
            }

            resolve({
              success: false,
              reason: 'failed',
              errorCode: result.result,
              message: '\u9a8c\u8bc1\u5931\u8d25\u6216\u5df2\u53d6\u6d88'
            })
          }
        })
        userAuthInstance.start()
      })
    } catch (err) {
      let e = err as BusinessError
      hilog.error(DOMAIN, TAG, `authenticate failed: code=${e.code}, message=${e.message}`)
      let mapped = AuthService.mapAuthError(authMethod, e.code, e.message)
      return {
        success: false,
        reason: AuthService.isUnavailableErrorCode(e.code) ? 'unavailable' : 'failed',
        errorCode: mapped.errorCode,
        message: mapped.message
      }
    }
  }

  private static mapAuthError(
    authMethod: AuthMethod,
    errorCode?: number,
    fallbackMessage?: string
  ): AuthAvailabilityResult {
    let authLabel = AuthService.getAuthMethodLabel(authMethod)
    switch (errorCode) {
      case 12500010:
        return {
          available: false,
          errorCode: errorCode,
          message: `\u7cfb\u7edf\u672a\u5f55\u5165${authLabel}\u6216\u51ed\u636e\u4e0d\u6ee1\u8db3\u8981\u6c42`
        }
      case 12500006:
        return {
          available: false,
          errorCode: errorCode,
          message: '\u5f53\u524d\u7cfb\u7edf\u8ba4\u8bc1\u7b49\u7ea7\u4e0d\u6ee1\u8db3\u8981\u6c42'
        }
      case 12500013:
        return {
          available: false,
          errorCode: errorCode,
          message: '\u7cfb\u7edf PIN \u5df2\u8fc7\u671f\uff0c\u8bf7\u5148\u5728\u7cfb\u7edf\u8bbe\u7f6e\u4e2d\u66f4\u65b0'
        }
      case 201:
        return {
          available: false,
          errorCode: errorCode,
          message: '\u8ba4\u8bc1\u6743\u9650\u4e0d\u8db3\uff0c\u65e0\u6cd5\u8c03\u7528\u7cfb\u7edf\u8ba4\u8bc1'
        }
      case 401:
        return {
          available: false,
          errorCode: errorCode,
          message: '\u8ba4\u8bc1\u53c2\u6570\u9519\u8bef'
        }
      default:
        return {
          available: false,
          errorCode: errorCode,
          message: fallbackMessage && fallbackMessage.length > 0 ?
            fallbackMessage :
            `\u7cfb\u7edf${authLabel}\u8ba4\u8bc1\u6682\u4e0d\u53ef\u7528`
        }
    }
  }

  private static isUnavailableErrorCode(errorCode?: number): boolean {
    return errorCode === 12500010 ||
      errorCode === 12500006 ||
      errorCode === 12500013 ||
      errorCode === 201
  }

  private static convertAuthMethod(method: AuthMethod): userAuth.UserAuthType | null {
    switch (method) {
      case AuthMethod.PIN:
        return userAuth.UserAuthType.PIN
      case AuthMethod.FINGERPRINT:
        return userAuth.UserAuthType.FINGERPRINT
      default:
        return null
    }
  }
}
