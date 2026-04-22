export const ACCOUNT_EVENT_COMMON_EVENT: string = 'com.huawei.securitytool.ACCOUNT_EVENT_CHANGED'

export const ACCOUNT_EVENT_PARAM_TYPE: string = 'accountEventType'
export const ACCOUNT_EVENT_PARAM_USER_ID: string = 'accountEventUserId'
export const ACCOUNT_EVENT_PARAM_TIMESTAMP: string = 'accountEventTimestamp'

export enum AccountEventType {
  ADDED = 'account_added',
  REMOVED = 'account_removed'
}

export interface AccountEventPayload {
  type: AccountEventType
  userId: number
  timestamp: number
}
