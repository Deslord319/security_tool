import { LogUtils } from '../utils/LogUtils'
import { EnterpriseAdminExtensionAbility } from '@kit.MDMKit'


const TAG = 'EnterpriseAdminAbility'

export default class EnterpriseAdminAbility extends EnterpriseAdminExtensionAbility {
  onAdminEnabled(): void {
    LogUtils.info(TAG, 'Enterprise admin enabled')
  }

  onAdminDisabled(): void {
    LogUtils.info(TAG, 'Enterprise admin disabled')
  }

  onBundleAdded(bundleName: string): void {
    LogUtils.info(TAG, `Bundle added: ${bundleName}`)
  }

  onBundleRemoved(bundleName: string): void {
    LogUtils.info(TAG, `Bundle removed: ${bundleName}`)
  }
}
