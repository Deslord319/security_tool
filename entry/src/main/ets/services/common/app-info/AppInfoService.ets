import { bundleManager } from '@kit.AbilityKit'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'AppInfoService'

export interface AppVersionProvider {
  getVersionName(): string
}

class BundleManagerAppVersionProvider implements AppVersionProvider {
  getVersionName(): string {
    const bundleInfo = bundleManager.getBundleInfoForSelfSync(
      bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
    )
    return bundleInfo.versionName
  }
}

export class AppInfoService {
  static getVersionName(provider: AppVersionProvider = new BundleManagerAppVersionProvider()): string {
    try {
      return provider.getVersionName()
    } catch (err) {
      LogUtils.warn(TAG, `getVersionName failed: ${JSON.stringify(err)}`)
      return ''
    }
  }
}
