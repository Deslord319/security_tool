import { BusinessError, commonEventManager } from '@kit.BasicServicesKit'
import { AccountChangeSource, AccountSnapshotChange } from './AccountSnapshotModels'
import { LogUtils } from '../../utils/LogUtils'

const TAG = 'AccountChangeEventBus'

export const ACCOUNT_CHANGE_COMMON_EVENT: string = 'com.huawei.securitytool.ACCOUNT_CHANGE'
export const ACCOUNT_CHANGE_PARAM_SOURCE: string = 'accountChangeSource'
export const ACCOUNT_CHANGE_PARAM_TRIGGER_USER_ID: string = 'accountChangeTriggerUserId'
export const ACCOUNT_CHANGE_PARAM_SIGNATURE: string = 'accountChangeSignature'
export const ACCOUNT_CHANGE_PARAM_TIMESTAMP: string = 'accountChangeTimestamp'

export interface AccountChangeEventPayload {
  source: AccountChangeSource
  triggerAccountId: number
  signature: string
  timestamp: number
}

export interface AccountChangeSubscription {
  subscriber: commonEventManager.CommonEventSubscriber
}

type AccountChangeRecord = Record<string, Object | string | number>
type AccountChangeListener = (payload: AccountChangeEventPayload) => Promise<void>

export class AccountChangeEventBus {
  static publishSnapshot(snapshot: AccountSnapshotChange): void {
    if (snapshot.source !== 'account-added' && snapshot.source !== 'account-removed') {
      return
    }

    let parameters: Record<string, Object> = {}
    parameters[ACCOUNT_CHANGE_PARAM_SOURCE] = snapshot.source
    if (snapshot.triggerAccountId === undefined) {
      return
    }
    parameters[ACCOUNT_CHANGE_PARAM_TRIGGER_USER_ID] = snapshot.triggerAccountId
    parameters[ACCOUNT_CHANGE_PARAM_SIGNATURE] = snapshot.signature
    parameters[ACCOUNT_CHANGE_PARAM_TIMESTAMP] = Date.now()

    let publishData: commonEventManager.CommonEventPublishData = {
      parameters: parameters
    }
    commonEventManager.publish(ACCOUNT_CHANGE_COMMON_EVENT, publishData, (err?: BusinessError) => {
      if (err) {
        LogUtils.warn(TAG, 'publish account change failed: source=%{public}s, err=%{public}s',
          snapshot.source, JSON.stringify(err))
      }
    })
  }

  static async subscribe(listener: AccountChangeListener): Promise<AccountChangeSubscription | null> {
    return await new Promise<AccountChangeSubscription | null>((resolve) => {
      let subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
        events: [ACCOUNT_CHANGE_COMMON_EVENT]
      }
      commonEventManager.createSubscriber(subscribeInfo, (err: BusinessError, subscriber) => {
        if (err) {
          LogUtils.warn(TAG, 'create account change subscriber failed: %{public}s', JSON.stringify(err))
          resolve(null)
          return
        }
        commonEventManager.subscribe(subscriber, (callbackErr: BusinessError, data: commonEventManager.CommonEventData) => {
          if (callbackErr) {
            LogUtils.warn(TAG, 'account change event callback failed: %{public}s', JSON.stringify(callbackErr))
            return
          }
          let payload = AccountChangeEventBus.parsePayload(data)
          if (!payload) {
            LogUtils.warn(TAG, 'account change event skipped: invalid payload')
            return
          }
          listener(payload).catch((listenerErr: Error) => {
            LogUtils.warn(TAG, 'account change listener failed: %{public}s', JSON.stringify(listenerErr))
          })
        })
        resolve({ subscriber: subscriber } as AccountChangeSubscription)
      })
    })
  }

  static unsubscribe(subscription: AccountChangeSubscription | null): void {
    if (!subscription) {
      return
    }
    commonEventManager.unsubscribe(subscription.subscriber, (err?: BusinessError) => {
      if (err) {
        LogUtils.warn(TAG, 'unsubscribe account change event failed: %{public}s', JSON.stringify(err))
      }
    })
  }

  private static parsePayload(data: commonEventManager.CommonEventData): AccountChangeEventPayload | null {
    return AccountChangeEventBus.parseRecord(data.parameters as AccountChangeRecord | undefined)
  }

  private static parseRecord(source: AccountChangeRecord | undefined): AccountChangeEventPayload | null {
    if (!source) {
      return null
    }
    let rawSource = source[ACCOUNT_CHANGE_PARAM_SOURCE]
    let rawTriggerAccountId = source[ACCOUNT_CHANGE_PARAM_TRIGGER_USER_ID]
    let rawSignature = source[ACCOUNT_CHANGE_PARAM_SIGNATURE]
    let rawTimestamp = source[ACCOUNT_CHANGE_PARAM_TIMESTAMP]
    if (rawSource !== 'account-added' && rawSource !== 'account-removed') {
      return null
    }
    if (typeof rawSignature !== 'string') {
      return null
    }
    if (typeof rawTriggerAccountId !== 'number' || !Number.isFinite(rawTriggerAccountId)) {
      return null
    }
    if (typeof rawTimestamp !== 'number' || !Number.isFinite(rawTimestamp)) {
      return null
    }
    return {
      source: rawSource,
      triggerAccountId: rawTriggerAccountId,
      signature: rawSignature,
      timestamp: rawTimestamp
    } as AccountChangeEventPayload
  }
}
