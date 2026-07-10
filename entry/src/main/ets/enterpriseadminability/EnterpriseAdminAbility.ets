import { adminManager, applicationManager, EnterpriseAdminExtensionAbility } from '@kit.MDMKit'
import { common } from '@kit.AbilityKit'
import type { Want } from '@kit.AbilityKit'
import { osAccount } from '@kit.BasicServicesKit'
import { ADMIN_WANT, ENTRY_WANT } from '../constants/AppConstants'
import { AccountChangeCoordinator } from '../services/account/AccountChangeCoordinator'
import { registerDefaultAccountChangeHandlers } from '../services/account/AccountChangeHandlers'
import { CommonErrorUtils } from '../utils/CommonErrorUtils'
import { LogUtils } from '../utils/LogUtils'
import { ErrorLike } from '../types/LooseValueTypes'


const TAG = 'EnterpriseAdminAbility'

export default class EnterpriseAdminAbility extends EnterpriseAdminExtensionAbility {
  onStart(): void {
    registerDefaultAccountChangeHandlers()
    this.ensureAutoStartAppRegistered('onStart')
  }

  onAdminEnabled(): void {
    LogUtils.info(TAG, 'Enterprise admin enabled')
    registerDefaultAccountChangeHandlers()
    this.ensureAutoStartAppRegistered('onAdminEnabled')
    this.ensureKeepAliveAppsForCurrentAccounts('onAdminEnabled')
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
    this.ensureKeepAliveAppRegistered('onAccountAdded', accountId)
    this.scheduleAccountReconcile('account-added', accountId)
  }

  onAccountRemoved(accountId: number): void {
    LogUtils.info(TAG, 'Account removed: %{public}d', accountId)
    this.removeKeepAliveAppRegistration('onAccountRemoved', accountId)
    this.scheduleAccountReconcile('account-removed', accountId)
  }

  private scheduleAccountReconcile(source: 'account-added' | 'account-removed', accountId: number): void {
    try {
      registerDefaultAccountChangeHandlers()
      AccountChangeCoordinator.schedule(this.context as common.Context, source, accountId)
    } catch (err) {
      LogUtils.warn(TAG, `scheduleAccountReconcile failed: ${JSON.stringify(err)}`)
    }
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
        LogUtils.info(TAG, 'ensureAutoStartAppRegistered skipped | source=%{public}s, alreadyRegistered=true', source)
        return
      }
      applicationManager.addAutoStartApps(ADMIN_WANT, [ENTRY_WANT])
      LogUtils.info(TAG, 'ensureAutoStartAppRegistered success | source=%{public}s, bundle=%{public}s, ability=%{public}s',
        source, ENTRY_WANT.bundleName ?? '-', ENTRY_WANT.abilityName ?? '-')
    } catch (err) {
      let error: ErrorLike = err as ErrorLike
      let code = CommonErrorUtils.extractErrorCode(error)
      LogUtils.warn(TAG, 'ensureAutoStartAppRegistered failed | source=%{public}s, code=%{public}s, err=%{public}s',
        source, `${code ?? 'unknown'}`, JSON.stringify(err))
    }
  }

  private async ensureKeepAliveAppsForCurrentAccounts(source: string): Promise<void> {
    try {
      let accountIds = await osAccount.getAccountManager().getActivatedOsAccountLocalIds()
      if (accountIds.length === 0) {
        LogUtils.warn(TAG, 'ensureKeepAliveAppsForCurrentAccounts skipped | source=%{public}s, accountCount=0', source)
        return
      }
      for (let accountId of accountIds) {
        this.ensureKeepAliveAppRegistered(source, accountId)
      }
    } catch (err) {
      let error: ErrorLike = err as ErrorLike
      let code = CommonErrorUtils.extractErrorCode(error)
      LogUtils.warn(TAG, 'ensureKeepAliveAppsForCurrentAccounts failed | source=%{public}s, code=%{public}s, err=%{public}s',
        source, `${code ?? 'unknown'}`, JSON.stringify(err))
    }
  }

  private ensureKeepAliveAppRegistered(source: string, accountId: number): void {
    this.reconcileKeepAliveAppRegistration(source, accountId, true)
  }

  private removeKeepAliveAppRegistration(source: string, accountId: number): void {
    this.reconcileKeepAliveAppRegistration(source, accountId, false)
  }

  private reconcileKeepAliveAppRegistration(source: string, accountId: number, shouldRegister: boolean): void {
    let bundleName = ENTRY_WANT.bundleName
    if (!bundleName) {
      LogUtils.warn(TAG,
        'reconcileKeepAliveAppRegistration skipped | source=%{public}s, accountId=%{public}d, bundleName=empty',
        source, accountId)
      return
    }
    try {
      let currentBundles = applicationManager.getKeepAliveApps(ADMIN_WANT, accountId)
      let alreadyRegistered = currentBundles.includes(bundleName)
      if (alreadyRegistered === shouldRegister) {
        LogUtils.info(TAG,
          'reconcileKeepAliveAppRegistration skipped | source=%{public}s, accountId=%{public}d, targetRegistered=%{public}s',
          source, accountId, String(shouldRegister))
        return
      }
      if (shouldRegister) {
        applicationManager.addKeepAliveApps(ADMIN_WANT, [bundleName], accountId)
      } else {
        applicationManager.removeKeepAliveApps(ADMIN_WANT, [bundleName], accountId)
      }
      LogUtils.info(TAG,
        'reconcileKeepAliveAppRegistration success | source=%{public}s, accountId=%{public}d, targetRegistered=%{public}s, bundle=%{public}s',
        source, accountId, String(shouldRegister), bundleName)
    } catch (err) {
      let error: ErrorLike = err as ErrorLike
      let code = CommonErrorUtils.extractErrorCode(error)
      LogUtils.warn(TAG,
        'reconcileKeepAliveAppRegistration failed | source=%{public}s, accountId=%{public}d, targetRegistered=%{public}s, code=%{public}s, err=%{public}s',
        source, accountId, String(shouldRegister), `${code ?? 'unknown'}`, JSON.stringify(err))
    }
  }
}
