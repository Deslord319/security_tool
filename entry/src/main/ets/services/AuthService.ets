import { userAuth } from '@kit.UserAuthenticationKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { AuthMethod } from '../models/DataModels'

const TAG = 'AuthService'
const DOMAIN = 0x0004

export class AuthService {

  // 检查认证方式是否可用
  static isAuthAvailable(authType: userAuth.UserAuthType): boolean {
    try {
      userAuth.getAvailableStatus(authType, userAuth.AuthTrustLevel.ATL1)
      return true
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `Auth type ${authType} not available: ${JSON.stringify(err)}`)
      return false
    }
  }

  // 获取所有可用的认证方式
  static getAvailableAuthMethods(): AuthMethod[] {
    let available: AuthMethod[] = []

    if (AuthService.isAuthAvailable(userAuth.UserAuthType.PIN)) {
      available.push(AuthMethod.PIN)
    }
    if (AuthService.isAuthAvailable(userAuth.UserAuthType.FINGERPRINT)) {
      available.push(AuthMethod.FINGERPRINT)
    }
    if (AuthService.isAuthAvailable(userAuth.UserAuthType.FACE)) {
      available.push(AuthMethod.FACE)
    }
    // PIN + FINGERPRINT 组合需要两者都可用
    if (AuthService.isAuthAvailable(userAuth.UserAuthType.PIN) &&
      AuthService.isAuthAvailable(userAuth.UserAuthType.FINGERPRINT)) {
      available.push(AuthMethod.PIN_FINGERPRINT)
    }

    return available
  }

  // 执行用户认证
  static async authenticate(authMethod: AuthMethod, challenge?: Uint8Array): Promise<boolean> {
    try {
      // 转换认证方式为 userAuth 类型数组
      let authTypes: userAuth.UserAuthType[] = AuthService.convertAuthMethod(authMethod)

      // 构建认证参数
      let authParam: userAuth.AuthParam = {
        challenge: challenge ?? new Uint8Array([0]),
        authType: authTypes,
        authTrustLevel: userAuth.AuthTrustLevel.ATL1
      }

      // 构建认证界面参数
      let widgetParam: userAuth.WidgetParam = {
        title: '身份验证',
        navigationButtonText: '取消'
      }

      // 获取认证实例
      let userAuthInstance = userAuth.getUserAuthInstance(authParam, widgetParam)

      // 执行认证（Promise 封装）
      return new Promise<boolean>((resolve) => {
        userAuthInstance.on('result', {
          onResult(result: userAuth.UserAuthResult) {
            hilog.info(DOMAIN, TAG, `Auth result: ${result.result}`)
            userAuthInstance.off('result')
            resolve(result.result === userAuth.UserAuthResultCode.SUCCESS)
          }
        })
        userAuthInstance.start()
      })
    } catch (err) {
      hilog.error(DOMAIN, TAG, `authenticate failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // AuthMethod 转换为 userAuth.UserAuthType 数组
  private static convertAuthMethod(method: AuthMethod): userAuth.UserAuthType[] {
    switch (method) {
      case AuthMethod.PIN:
        return [userAuth.UserAuthType.PIN]
      case AuthMethod.FINGERPRINT:
        return [userAuth.UserAuthType.FINGERPRINT]
      case AuthMethod.FACE:
        return [userAuth.UserAuthType.FACE]
      case AuthMethod.PIN_FINGERPRINT:
        return [userAuth.UserAuthType.PIN, userAuth.UserAuthType.FINGERPRINT]
      default:
        return [userAuth.UserAuthType.PIN]
    }
  }
}
