import { Want } from '@kit.AbilityKit'
import { adminManager, EnterpriseAdminExtensionAbility } from '@kit.MDMKit'

import { AppInfo } from '../constants/AppConstants'
import { SystemUserProvider } from '../services/firewall/providers/SystemUserProvider'
import { LogUtils } from '../utils/LogUtils'


const TAG = 'EnterpriseAdminAbility'
const ADMIN_WANT: Want = {
  bundleName: AppInfo.BUNDLE_NAME,
  abilityName: 'EnterpriseAdminAbility'
}

export default class EnterpriseAdminAbility extends EnterpriseAdminExtensionAbility {
  onAdminEnabled(): void {
    LogUtils.info(TAG, 'Enterprise admin enabled')
    this.subscribeAccountManagedEvents()
  }

  onAdminDisabled(): void {
    LogUtils.info(TAG, 'Enterprise admin disabled')
    this.unsubscribeAccountManagedEvents()
  }

  onBundleAdded(bundleName: string): void {
    LogUtils.info(TAG, `Bundle added: ${bundleName}`)
  }

  onBundleRemoved(bundleName: string): void {
    LogUtils.info(TAG, `Bundle removed: ${bundleName}`)
  }

  onAccountAdded(accountId: number): void {
    LogUtils.info(TAG, 'Account added: %{public}d', accountId)
    void SystemUserProvider.trackAddedUser(accountId)
  }

  onAccountRemoved(accountId: number): void {
    LogUtils.info(TAG, 'Account removed: %{public}d', accountId)
    void SystemUserProvider.trackRemovedUser(accountId)
  }

  private subscribeAccountManagedEvents(): void {
    try {
      let events: Array<adminManager.ManagedEvent> = [
        adminManager.ManagedEvent.MANAGED_EVENT_ACCOUNT_ADDED,
        adminManager.ManagedEvent.MANAGED_EVENT_ACCOUNT_REMOVED
      ]
      adminManager.subscribeManagedEventSync(ADMIN_WANT, events)
      LogUtils.info(TAG, 'subscribeAccountManagedEvents success: count=%{public}d', events.length)
    } catch (err) {
      LogUtils.error(TAG, `subscribeAccountManagedEvents failed: ${JSON.stringify(err)}`)
    }
  }

  private unsubscribeAccountManagedEvents(): void {
    try {
      let events: Array<adminManager.ManagedEvent> = [
        adminManager.ManagedEvent.MANAGED_EVENT_ACCOUNT_ADDED,
        adminManager.ManagedEvent.MANAGED_EVENT_ACCOUNT_REMOVED
      ]
      adminManager.unsubscribeManagedEventSync(ADMIN_WANT, events)
      LogUtils.info(TAG, 'unsubscribeAccountManagedEvents success: count=%{public}d', events.length)
    } catch (err) {
      LogUtils.warn(TAG, `unsubscribeAccountManagedEvents failed: ${JSON.stringify(err)}`)
    }
  }
}
