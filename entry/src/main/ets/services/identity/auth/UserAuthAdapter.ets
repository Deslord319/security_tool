import { userAuth } from '@kit.UserAuthenticationKit'
import { BusinessError } from '@kit.BasicServicesKit'

export interface UserAuthInstanceRequest {
  authParam: userAuth.AuthParam
  widgetParam: userAuth.WidgetParam
}

export interface UserAuthStatusResult {
  success: boolean
  errorCode?: number
  errorMessage?: string
}

export interface UserAuthInstanceResult {
  success: boolean
  instance?: userAuth.UserAuthInstance
  errorCode?: number
  errorMessage?: string
}

export class UserAuthAdapter {
  static getAvailableStatus(authType: userAuth.UserAuthType): UserAuthStatusResult | void {
    try {
      userAuth.getAvailableStatus(authType, userAuth.AuthTrustLevel.ATL1)
      return { success: true }
    } catch (err) {
      const error = err as BusinessError
      return {
        success: false,
        errorCode: error.code,
        errorMessage: error.message
      }
    }
  }

  static getUserAuthInstance(request: UserAuthInstanceRequest): UserAuthInstanceResult | userAuth.UserAuthInstance {
    try {
      return {
        success: true,
        instance: userAuth.getUserAuthInstance(request.authParam, request.widgetParam)
      }
    } catch (err) {
      const error = err as BusinessError
      return {
        success: false,
        errorCode: error.code,
        errorMessage: error.message
      }
    }
  }
}
