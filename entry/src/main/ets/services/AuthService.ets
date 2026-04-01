import { LogUtils } from '../utils/LogUtils'
import { userAuth } from '@kit.UserAuthenticationKit'

import { BusinessError } from '@kit.BasicServicesKit'
import { AuthMethod } from '../models/DataModels'

const TAG = 'AuthService'

export interface AuthAvailabilityResult {
  available: boolean
  message: string
  errorCode?: number
}

export type AuthExecutionReason = 'failed' | 'unavailable'

export interface AuthExecutionResult {
  success: boolean
  reason?: AuthExecutionReason
  errorCode?: number
  message?: string
}

export class AuthService {
  static checkAuthMethodAvailability(authMethod: AuthMethod): AuthAvailabilityResult {
    let authType = AuthService.convertAuthMethod(authMethod)
    if (authType === null) {
      return {
        available: false,
        message: '当前设备不支持该认证方式'
      }
    }

    try {
      userAuth.getAvailableStatus(authType, userAuth.AuthTrustLevel.ATL1)
      return {
        available: true,
        message: '系统认证可用'
      }
    } catch (err) {
      let e = err as BusinessError
      let mapped = AuthService.mapAuthError(authMethod, e.code, e.message)
      LogUtils.warn(TAG, `Auth method ${authMethod} unavailable: code=${mapped.errorCode}, msg=${mapped.message}`)
      return mapped
    }
  }

  static getAuthMethodLabel(method: AuthMethod): string {
    switch (method) {
      case AuthMethod.PIN:
        return 'PIN'
      case AuthMethod.FINGERPRINT:
        return '指纹'
      default:
        return '认证方式'
    }
  }

  static async authenticate(authMethod: AuthMethod, challenge?: Uint8Array): Promise<AuthExecutionResult> {
    try {
      let authType = AuthService.convertAuthMethod(authMethod)
      if (authType === null) {
        LogUtils.error(TAG, `Unsupported auth method: ${authMethod}`)
        return {
          success: false,
          reason: 'unavailable',
          message: '当前设备不支持该认证方式'
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
        title: '身份验证'
      }

      let userAuthInstance = userAuth.getUserAuthInstance(authParam, widgetParam)

      return new Promise<AuthExecutionResult>((resolve) => {
        userAuthInstance.on('result', {
          onResult(result: userAuth.UserAuthResult) {
            LogUtils.info(TAG, `Auth result code: ${result.result}, SUCCESS code: ${userAuth.UserAuthResultCode.SUCCESS}`)
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
              message: '验证失败或已取消'
            })
          }
        })
        userAuthInstance.start()
      })
    } catch (err) {
      let e = err as BusinessError
      LogUtils.error(TAG, `authenticate failed: code=${e.code}, message=${e.message}`)
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
          message: `系统未录入${authLabel}或凭据不满足要求`
        }
      case 12500006:
        return {
          available: false,
          errorCode: errorCode,
          message: '当前系统认证等级不满足要求'
        }
      case 12500013:
        return {
          available: false,
          errorCode: errorCode,
          message: '系统 PIN 已过期，请先在系统设置中更新'
        }
      case 201:
        return {
          available: false,
          errorCode: errorCode,
          message: '认证权限不足，无法调用系统认证'
        }
      case 401:
        return {
          available: false,
          errorCode: errorCode,
          message: '认证参数错误'
        }
      default:
        return {
          available: false,
          errorCode: errorCode,
          message: fallbackMessage && fallbackMessage.length > 0 ?
            fallbackMessage :
            `系统${authLabel}认证暂不可用`
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
