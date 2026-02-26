import { userAuth } from '@kit.UserAuthenticationKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { AuthMethod } from '../models/DataModels'

const TAG = 'AuthService'
const DOMAIN = 0x0004

// 认证可用性检查结果
export interface AuthAvailabilityResult {
  available: boolean
  message: string
}

export class AuthService {

  // 检查认证方式是否可用
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

  // 检查指定认证方式的可用性，返回详细结果
  static checkAuthMethodAvailability(authMethod: AuthMethod): AuthAvailabilityResult {
    let authTypes: userAuth.UserAuthType[] = AuthService.convertAuthMethod(authMethod)
    let unavailableNames: string[] = []

    for (let authType of authTypes) {
      if (!AuthService.isAuthAvailable(authType)) {
        if (authType === userAuth.UserAuthType.PIN) {
          unavailableNames.push('PIN 码')
        } else if (authType === userAuth.UserAuthType.FINGERPRINT) {
          unavailableNames.push('指纹')
        } else if (authType === userAuth.UserAuthType.FACE) {
          unavailableNames.push('人脸识别')
        }
      }
    }

    if (unavailableNames.length === 0) {
      return { available: true, message: '认证方式可用' }
    }

    let message = `设备未注册${unavailableNames.join('和')}，请在系统设置中配置后重试`
    return { available: false, message: message }
  }

  // 获取认证方式的中文标签
  static getAuthMethodLabel(method: AuthMethod): string {
    switch (method) {
      case AuthMethod.PIN:
        return 'PIN 码'
      case AuthMethod.FINGERPRINT:
        return '指纹'
      case AuthMethod.FACE:
        return '人脸识别'
      case AuthMethod.PIN_FINGERPRINT:
        return 'PIN + 指纹'
      default:
        return '未知认证方式'
    }
  }

  // 执行用户认证
  static async authenticate(authMethod: AuthMethod, challenge?: Uint8Array): Promise<boolean> {
    try {
      // 转换认证方式为 userAuth 类型数组
      let authTypes: userAuth.UserAuthType[] = AuthService.convertAuthMethod(authMethod)

      // 前置检查：验证所有必需的认证类型是否可用
      for (let authType of authTypes) {
        if (!AuthService.isAuthAvailable(authType)) {
          hilog.error(DOMAIN, TAG, `Auth type ${authType} is not available on this device, aborting authenticate`)
          return false
        }
      }

      // 生成 challenge（HarmonyOS 要求至少 8 字节）
      let authChallenge: Uint8Array
      if (challenge && challenge.length >= 8) {
        authChallenge = challenge
      } else {
        authChallenge = new Uint8Array(8)
        for (let i = 0; i < 8; i++) {
          authChallenge[i] = Math.floor(Math.random() * 256)
        }
      }

      hilog.info(DOMAIN, TAG, `Starting auth with types: ${JSON.stringify(authTypes)}, challenge length: ${authChallenge.length}`)

      // 构建认证参数
      let authParam: userAuth.AuthParam = {
        challenge: authChallenge,
        authType: authTypes,
        authTrustLevel: userAuth.AuthTrustLevel.ATL1
      }

      // 构建认证界面参数
      let widgetParam: userAuth.WidgetParam = {
        title: '身份验证'
      }

      // 获取认证实例
      let userAuthInstance = userAuth.getUserAuthInstance(authParam, widgetParam)

      // 执行认证（Promise 封装）
      return new Promise<boolean>((resolve) => {
        userAuthInstance.on('result', {
          onResult(result: userAuth.UserAuthResult) {
            hilog.info(DOMAIN, TAG, `Auth result code: ${result.result}, SUCCESS code: ${userAuth.UserAuthResultCode.SUCCESS}`)
            userAuthInstance.off('result')
            // 12500000 是 SUCCESS
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
