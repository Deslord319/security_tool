import { userAuth } from '@kit.UserAuthenticationKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { AuthMethod } from '../models/DataModels'

const TAG = 'AuthService'
const DOMAIN = 0x0004

export interface AuthAvailabilityResult {
  available: boolean
  message: string
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
      return { available: false, message: '认证方式不受支持' }
    }

    if (AuthService.isAuthAvailable(authType)) {
      return { available: true, message: '认证方式可用' }
    }

    return {
      available: false,
      message: `认证方式不可用：${AuthService.getAuthMethodLabel(authMethod)}。保存后启动校验可能无法执行。`
    }
  }

  static getAuthMethodLabel(method: AuthMethod): string {
    switch (method) {
      case AuthMethod.PIN:
        return 'PIN 码'
      case AuthMethod.FINGERPRINT:
        return '指纹'
      default:
        return '未知认证方式'
    }
  }

  static async authenticate(authMethod: AuthMethod, challenge?: Uint8Array): Promise<boolean> {
    try {
      let authType = AuthService.convertAuthMethod(authMethod)
      if (authType === null) {
        hilog.error(DOMAIN, TAG, `Unsupported auth method: ${authMethod}`)
        return false
      }

      if (!AuthService.isAuthAvailable(authType)) {
        hilog.error(DOMAIN, TAG, `Auth type ${authType} is not available on this device, aborting authenticate`)
        return false
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
        title: '身份认证'
      }

      let userAuthInstance = userAuth.getUserAuthInstance(authParam, widgetParam)

      return new Promise<boolean>((resolve) => {
        userAuthInstance.on('result', {
          onResult(result: userAuth.UserAuthResult) {
            hilog.info(DOMAIN, TAG, `Auth result code: ${result.result}, SUCCESS code: ${userAuth.UserAuthResultCode.SUCCESS}`)
            userAuthInstance.off('result')
            resolve(result.result === userAuth.UserAuthResultCode.SUCCESS)
          }
        })
        userAuthInstance.start()
      })
    } catch (err) {
      let e = err as BusinessError
      hilog.error(DOMAIN, TAG, `authenticate failed: code=${e.code}, message=${e.message}`)
      return false
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
