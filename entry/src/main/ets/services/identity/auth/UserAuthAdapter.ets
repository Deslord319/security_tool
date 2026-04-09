import { userAuth } from '@kit.UserAuthenticationKit'

export interface UserAuthInstanceRequest {
  authParam: userAuth.AuthParam
  widgetParam: userAuth.WidgetParam
}

export class UserAuthAdapter {
  static getAvailableStatus(authType: userAuth.UserAuthType): void {
    try {
      userAuth.getAvailableStatus(authType, userAuth.AuthTrustLevel.ATL1)
    } catch (err) {
      throw err as Error
    }
  }

  static getUserAuthInstance(request: UserAuthInstanceRequest): userAuth.UserAuthInstance {
    try {
      return userAuth.getUserAuthInstance(request.authParam, request.widgetParam)
    } catch (err) {
      throw err as Error
    }
  }
}
