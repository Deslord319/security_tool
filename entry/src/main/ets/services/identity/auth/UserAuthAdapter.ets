import { userAuth } from '@kit.UserAuthenticationKit'

export interface UserAuthInstanceRequest {
  authParam: userAuth.AuthParam
  widgetParam: userAuth.WidgetParam
}

export class UserAuthAdapter {
  static getAvailableStatus(authType: userAuth.UserAuthType): void {
    userAuth.getAvailableStatus(authType, userAuth.AuthTrustLevel.ATL1)
  }

  static getUserAuthInstance(request: UserAuthInstanceRequest): userAuth.UserAuthInstance {
    return userAuth.getUserAuthInstance(request.authParam, request.widgetParam)
  }
}
