import { adminManager, applicationManager, EnterpriseAdminExtensionAbility } from '@kit.MDMKit'

import type { Want } from '@kit.AbilityKit'

import { ADMIN_WANT, ENTRY_WANT } from '../constants/AppConstants'
import { CommonErrorUtils } from '../utils/CommonErrorUtils'
import { SystemUserProvider } from '../services/firewall/providers/SystemUserProvider'
import { LogUtils } from '../utils/LogUtils'
import { ErrorLike } from '../types/LooseValueTypes'


const TAG = 'EnterpriseAdminAbility'

export default class EnterpriseAdminAbility extends EnterpriseAdminExtensionAbility {
  onStart(): void {
    this.ensureAutoStartAppRegistered('onStart')
  }

  onAdminEnabled(): void {
    LogUtils.info(TAG, 'Enterprise admin enabled')
    this.ensureAutoStartAppRegistered('onAdminEnabled')
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

  private ensureAutoStartAppRegistered(source: string): void {
    try {
      let currentApps: Array<Want> = applicationManager.getAutoStartApps(ADMIN_WANT)
      let alreadyRegistered = currentApps.some((item: Want) =>
        item.bundleName === ENTRY_WANT.bundleName && item.abilityName === ENTRY_WANT.abilityName
      )
      if (alreadyRegistered) {
        return
      }
      applicationManager.addAutoStartApps(ADMIN_WANT, [ENTRY_WANT])
    } catch (err) {
      let error: ErrorLike = err as ErrorLike
      let code = CommonErrorUtils.extractErrorCode(error)
      LogUtils.warn(TAG, 'ensureAutoStartAppRegistered failed | source=%{public}s, code=%{public}s, err=%{public}s',
        source, `${code ?? 'unknown'}`, JSON.stringify(err))
    }
  }
}
