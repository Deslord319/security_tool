import { BusinessError, commonEventManager } from '@kit.BasicServicesKit'
import { AppInfo } from '../../constants/AppConstants'
import { LogUtils } from '../../utils/LogUtils'

const TAG = 'AppInventoryEventBus'

export const APPLICATION_INVENTORY_CHANGE_COMMON_EVENT: string =
  'com.huawei.securitytool.APPLICATION_INVENTORY_CHANGE'
const PARAM_SOURCE: string = 'applicationInventoryChangeSource'
const PARAM_BUNDLE_NAME: string = 'applicationInventoryBundleName'
const PARAM_ACCOUNT_ID: string = 'applicationInventoryAccountId'
const PARAM_TIMESTAMP: string = 'applicationInventoryTimestamp'

export type ApplicationInventoryChangeSource = 'bundle-added' | 'bundle-removed' | 'bundle-updated'

export interface ApplicationInventoryChangePayload {
  source: ApplicationInventoryChangeSource
  bundleName: string
  accountId?: number
  timestamp: number
}

export interface ApplicationInventoryChangeSubscription {
  subscriber: commonEventManager.CommonEventSubscriber
}

type ApplicationInventoryChangeRecord = Record<string, Object | string | number>
type ApplicationInventoryChangeListener = (payload: ApplicationInventoryChangePayload) => Promise<void>

export class ApplicationInventoryEventBus {
  static publish(source: ApplicationInventoryChangeSource, bundleName: string, accountId?: number): void {
    let normalizedBundleName = bundleName.trim()
    if (normalizedBundleName.length === 0) {
      LogUtils.warn(TAG, 'skip application inventory change publish: bundleName is empty')
      return
    }
    let parameters: Record<string, Object> = {}
    parameters[PARAM_SOURCE] = source
    parameters[PARAM_BUNDLE_NAME] = normalizedBundleName
    parameters[PARAM_TIMESTAMP] = Date.now()
    if (accountId !== undefined && Number.isFinite(accountId)) {
      parameters[PARAM_ACCOUNT_ID] = accountId
    }
    let publishData: commonEventManager.CommonEventPublishData = {
      bundleName: AppInfo.BUNDLE_NAME,
      parameters: parameters
    }
    try {
      commonEventManager.publish(APPLICATION_INVENTORY_CHANGE_COMMON_EVENT, publishData, (err?: BusinessError) => {
        if (err) {
          LogUtils.warn(TAG, 'publish application inventory change failed: source=%{public}s, err=%{public}s',
            source, JSON.stringify(err))
        }
      })
    } catch (err) {
      LogUtils.warn(TAG, 'publish application inventory change threw: source=%{public}s, err=%{public}s',
        source, JSON.stringify(err))
    }
  }

  static async subscribe(
    listener: ApplicationInventoryChangeListener
  ): Promise<ApplicationInventoryChangeSubscription | null> {
    return await new Promise<ApplicationInventoryChangeSubscription | null>((resolve) => {
      let subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
        events: [APPLICATION_INVENTORY_CHANGE_COMMON_EVENT],
        publisherBundleName: AppInfo.BUNDLE_NAME
      }
      commonEventManager.createSubscriber(subscribeInfo, (err: BusinessError, subscriber) => {
        if (err) {
          LogUtils.warn(TAG, 'create application inventory subscriber failed: %{public}s', JSON.stringify(err))
          resolve(null)
          return
        }
        commonEventManager.subscribe(subscriber, (callbackErr: BusinessError, data: commonEventManager.CommonEventData) => {
          if (callbackErr) {
            LogUtils.warn(TAG, 'application inventory event callback failed: %{public}s', JSON.stringify(callbackErr))
            return
          }
          let payload = ApplicationInventoryEventBus.parsePayload(data)
          if (!payload) {
            LogUtils.warn(TAG, 'application inventory event skipped: invalid payload')
            return
          }
          listener(payload).catch((listenerErr: Error) => {
            LogUtils.warn(TAG, 'application inventory listener failed: %{public}s', JSON.stringify(listenerErr))
          })
        })
        resolve({ subscriber: subscriber } as ApplicationInventoryChangeSubscription)
      })
    })
  }

  static unsubscribe(subscription: ApplicationInventoryChangeSubscription | null): void {
    if (!subscription) {
      return
    }
    commonEventManager.unsubscribe(subscription.subscriber, (err?: BusinessError) => {
      if (err) {
        LogUtils.warn(TAG, 'unsubscribe application inventory event failed: %{public}s', JSON.stringify(err))
      }
    })
  }

  private static parsePayload(data: commonEventManager.CommonEventData): ApplicationInventoryChangePayload | null {
    let source = data.parameters as ApplicationInventoryChangeRecord | undefined
    if (!source) {
      return null
    }
    let rawSource = source[PARAM_SOURCE]
    let rawBundleName = source[PARAM_BUNDLE_NAME]
    let rawAccountId = source[PARAM_ACCOUNT_ID]
    let rawTimestamp = source[PARAM_TIMESTAMP]
    if (rawSource !== 'bundle-added' && rawSource !== 'bundle-removed' && rawSource !== 'bundle-updated') {
      return null
    }
    if (typeof rawBundleName !== 'string' || rawBundleName.trim().length === 0) {
      return null
    }
    if (typeof rawTimestamp !== 'number' || !Number.isFinite(rawTimestamp)) {
      return null
    }
    if (rawAccountId !== undefined &&
      (typeof rawAccountId !== 'number' || !Number.isFinite(rawAccountId))) {
      return null
    }
    return {
      source: rawSource,
      bundleName: rawBundleName.trim(),
      accountId: rawAccountId as number | undefined,
      timestamp: rawTimestamp
    } as ApplicationInventoryChangePayload
  }
}
