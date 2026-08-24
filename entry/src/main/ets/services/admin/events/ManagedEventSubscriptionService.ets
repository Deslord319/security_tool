import { adminManager } from '@kit.MDMKit'
import { ADMIN_WANT } from '../../../constants/AppConstants'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'ManagedEventSubscription'

export class ManagedEventSubscriptionService {
  private static readonly EVENTS: Array<adminManager.ManagedEvent> = [
    adminManager.ManagedEvent.MANAGED_EVENT_BUNDLE_ADDED,
    adminManager.ManagedEvent.MANAGED_EVENT_BUNDLE_REMOVED,
    adminManager.ManagedEvent.MANAGED_EVENT_BUNDLE_UPDATED,
    adminManager.ManagedEvent.MANAGED_EVENT_ACCOUNT_ADDED,
    adminManager.ManagedEvent.MANAGED_EVENT_ACCOUNT_REMOVED
  ]

  static ensureSubscribed(source: string): boolean {
    try {
      adminManager.subscribeManagedEventSync(ADMIN_WANT, ManagedEventSubscriptionService.EVENTS)
      LogUtils.info(TAG, 'ensure subscribed success: source=%{public}s, count=%{public}d',
        source, ManagedEventSubscriptionService.EVENTS.length)
      return true
    } catch (err) {
      LogUtils.warn(TAG, 'ensure subscribed failed: source=%{public}s, err=%{public}s', source, JSON.stringify(err))
      return false
    }
  }

  static unsubscribe(source: string): boolean {
    try {
      adminManager.unsubscribeManagedEventSync(ADMIN_WANT, ManagedEventSubscriptionService.EVENTS)
      LogUtils.info(TAG, 'unsubscribe success: source=%{public}s, count=%{public}d',
        source, ManagedEventSubscriptionService.EVENTS.length)
      return true
    } catch (err) {
      LogUtils.warn(TAG, 'unsubscribe failed: source=%{public}s, err=%{public}s', source, JSON.stringify(err))
      return false
    }
  }
}
