export class CommonSystemErrorCodes {
  static readonly PERMISSION_DENIED: number = 201
  static readonly INVALID_PARAMS: number = 401
}

export class AdminErrorCodes {
  static readonly ADMIN_NOT_ACTIVATED: number = 9200001
}

export class PeripheralErrorCodes {
  static readonly POLICY_CONFLICT: number = 9200010
}

export class AuthErrorCodes {
  static readonly METHOD_NOT_ENROLLED: number = 12500010
  static readonly TRUST_LEVEL_INSUFFICIENT: number = 12500006
  static readonly PIN_EXPIRED: number = 12500013

  static getUnavailableCodes(): number[] {
    return [
      AuthErrorCodes.METHOD_NOT_ENROLLED,
      AuthErrorCodes.TRUST_LEVEL_INSUFFICIENT,
      AuthErrorCodes.PIN_EXPIRED,
      CommonSystemErrorCodes.PERMISSION_DENIED
    ]
  }
}

export class AuditErrorCodes {
  static readonly FILE_FILTER_UNSUPPORTED: number = 1012000005
}
