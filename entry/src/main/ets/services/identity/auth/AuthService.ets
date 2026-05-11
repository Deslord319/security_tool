import { LogUtils } from '../../../utils/LogUtils'
import { userAuth } from '@kit.UserAuthenticationKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'

import { BusinessError } from '@kit.BasicServicesKit'
import { LabelText } from '../../../constants/StringCatalog'
import { AuthErrorCodes, CommonSystemErrorCodes } from '../../../constants/SystemErrorCodes'
import { AuthMethod } from '../../../models/DataModels'
import { IdentityAuthStrings } from '../../../constants/modules/IdentityStrings'
import { UserAuthAdapter, UserAuthInstanceResult, UserAuthStatusResult } from './UserAuthAdapter'

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
        message: IdentityAuthStrings.METHOD_UNSUPPORTED
      }
    }

    try {
      let availableResult = UserAuthAdapter.getAvailableStatus(authType)
      if (availableResult === undefined) {
        return {
          available: true,
          message: IdentityAuthStrings.SYSTEM_AVAILABLE
        }
      }
      let resolvedAvailableResult = availableResult as UserAuthStatusResult
      if (resolvedAvailableResult.success) {
        return {
          available: true,
          message: IdentityAuthStrings.SYSTEM_AVAILABLE
        }
      }
      let mapped = AuthService.mapAuthError(
        authMethod,
        resolvedAvailableResult.errorCode,
        resolvedAvailableResult.errorMessage
      )
      LogUtils.warn(TAG, `Auth method ${authMethod} unavailable: code=${mapped.errorCode}, msg=${mapped.message}`)
      return mapped
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
        return IdentityAuthStrings.METHOD_PIN
      case AuthMethod.FINGERPRINT:
        return IdentityAuthStrings.METHOD_FINGERPRINT
      default:
        return LabelText.AUTH_METHOD
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
          message: IdentityAuthStrings.METHOD_UNSUPPORTED
        }
      }

      let authChallenge: Uint8Array
      if (challenge && challenge.length >= 8) {
        authChallenge = challenge
      } else {
        let generatedChallenge = AuthService.generateAuthChallenge()
        if (generatedChallenge === null) {
          return {
            success: false,
            reason: 'unavailable',
            message: IdentityAuthStrings.buildUnavailable(AuthService.getAuthMethodLabel(authMethod))
          }
        }
        authChallenge = generatedChallenge
      }

      let authParam: userAuth.AuthParam = {
        challenge: authChallenge,
        authType: [authType],
        authTrustLevel: userAuth.AuthTrustLevel.ATL1
      }

      let widgetParam: userAuth.WidgetParam = {
        title: IdentityAuthStrings.DIALOG_TITLE
      }

      let userAuthInstanceValue = UserAuthAdapter.getUserAuthInstance({
        authParam: authParam,
        widgetParam: widgetParam
      })
      let userAuthInstance: userAuth.UserAuthInstance
      let structuredResult = userAuthInstanceValue as UserAuthInstanceResult
      if (typeof structuredResult.success === 'boolean') {
        if (!structuredResult.success || !structuredResult.instance) {
          let mapped = AuthService.mapAuthError(
            authMethod,
            structuredResult.errorCode,
            structuredResult.errorMessage
          )
          return {
            success: false,
            reason: AuthService.isUnavailableErrorCode(structuredResult.errorCode) ? 'unavailable' : 'failed',
            errorCode: mapped.errorCode,
            message: mapped.message
          }
        }
        userAuthInstance = structuredResult.instance as userAuth.UserAuthInstance
      } else {
        userAuthInstance = userAuthInstanceValue as userAuth.UserAuthInstance
      }

      return new Promise<AuthExecutionResult>((resolve) => {
        try {
          userAuthInstance.on('result', {
            onResult(result: userAuth.UserAuthResult) {
              LogUtils.info(TAG, `Auth result code: ${result.result}, SUCCESS code: ${userAuth.UserAuthResultCode.SUCCESS}`)
              try {
                userAuthInstance.off('result')
              } catch (offErr) {
                LogUtils.warn(TAG, `userAuthInstance.off failed: ${JSON.stringify(offErr)}`)
              }
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
                message: IdentityAuthStrings.FAILED_OR_CANCELED
              })
            }
          })
          userAuthInstance.start()
        } catch (err) {
          let e = err as BusinessError
          LogUtils.error(TAG, `userAuthInstance.start failed: code=${e.code}, message=${e.message}`)
          let mapped = AuthService.mapAuthError(authMethod, e.code, e.message)
          resolve({
            success: false,
            reason: AuthService.isUnavailableErrorCode(e.code) ? 'unavailable' : 'failed',
            errorCode: mapped.errorCode,
            message: mapped.message
          })
        }
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
      case AuthErrorCodes.METHOD_NOT_ENROLLED:
        return {
          available: false,
          errorCode: errorCode,
          message: IdentityAuthStrings.buildNotEnrolled(authLabel)
        }
      case AuthErrorCodes.TRUST_LEVEL_INSUFFICIENT:
        return {
          available: false,
          errorCode: errorCode,
          message: IdentityAuthStrings.TRUST_LEVEL_INSUFFICIENT
        }
      case AuthErrorCodes.PIN_EXPIRED:
        return {
          available: false,
          errorCode: errorCode,
          message: IdentityAuthStrings.PIN_EXPIRED
        }
      case CommonSystemErrorCodes.PERMISSION_DENIED:
        return {
          available: false,
          errorCode: errorCode,
          message: IdentityAuthStrings.PERMISSION_DENIED
        }
      case CommonSystemErrorCodes.INVALID_PARAMS:
        return {
          available: false,
          errorCode: errorCode,
          message: IdentityAuthStrings.INVALID_PARAMS
        }
      default:
        return {
          available: false,
          errorCode: errorCode,
          message: fallbackMessage && fallbackMessage.length > 0 ?
            fallbackMessage :
            IdentityAuthStrings.buildUnavailable(authLabel)
        }
    }
  }

  private static isUnavailableErrorCode(errorCode?: number): boolean {
    return errorCode !== undefined && AuthErrorCodes.getUnavailableCodes().includes(errorCode)
  }

  private static generateAuthChallenge(): Uint8Array | null {
    try {
      return cryptoFramework.createRandom().generateRandomSync(8).data
    } catch (err) {
      LogUtils.error(TAG, `generateAuthChallenge failed: ${JSON.stringify(err)}`)
      return null
    }
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
