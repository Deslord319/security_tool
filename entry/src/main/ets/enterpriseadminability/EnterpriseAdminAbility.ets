import { EnterpriseAdminExtensionAbility } from '@kit.MDMKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'EnterpriseAdminAbility'
const DOMAIN = 0x0003

export default class EnterpriseAdminAbility extends EnterpriseAdminExtensionAbility {
  onAdminEnabled(): void {
    hilog.info(DOMAIN, TAG, 'Enterprise admin enabled')
  }

  onAdminDisabled(): void {
    hilog.info(DOMAIN, TAG, 'Enterprise admin disabled')
  }

  onBundleAdded(bundleName: string): void {
    hilog.info(DOMAIN, TAG, `Bundle added: ${bundleName}`)
  }

  onBundleRemoved(bundleName: string): void {
    hilog.info(DOMAIN, TAG, `Bundle removed: ${bundleName}`)
  }
}
