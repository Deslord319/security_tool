import { LogUtils } from '../utils/LogUtils'
import { userAuth } from '@kit.UserAuthenticationKit'

import { BusinessError } from '@kit.BasicServicesKit'
import { AuthMethod } from '../models/DataModels'
import { IdentityStrings } from '../constants/modules/IdentityStrings'

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
        message: IdentityStrings.authMethodUnsupported
      }
    }

    try {
      userAuth.getAvailableStatus(authType, userAuth.AuthTrustLevel.ATL1)
      return {
        available: true,
        message: IdentityStrings.authSystemAvailable
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
        return IdentityStrings.authMethodFingerprint
      default:
        return IdentityStrings.authMethodGeneric
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
          message: IdentityStrings.authMethodUnsupported
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
        title: IdentityStrings.authDialogTitle
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
              message: IdentityStrings.authFailedOrCanceled
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
          message: IdentityStrings.buildAuthNotEnrolled(authLabel)
        }
      case 12500006:
        return {
          available: false,
          errorCode: errorCode,
          message: IdentityStrings.authTrustLevelInsufficient
        }
      case 12500013:
        return {
          available: false,
          errorCode: errorCode,
          message: IdentityStrings.authPinExpired
        }
      case 201:
        return {
          available: false,
          errorCode: errorCode,
          message: IdentityStrings.authPermissionDenied
        }
      case 401:
        return {
          available: false,
          errorCode: errorCode,
          message: IdentityStrings.authInvalidParams
        }
      default:
        return {
          available: false,
          errorCode: errorCode,
          message: fallbackMessage && fallbackMessage.length > 0 ?
            fallbackMessage :
            IdentityStrings.buildAuthUnavailable(authLabel)
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
