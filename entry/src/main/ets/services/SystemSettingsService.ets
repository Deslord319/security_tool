import { bundleManager, common, Want } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'SystemSettingsService'

export class SystemSettingsService {
  static async openPasswordSettings(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const bundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      )

      const want: Want = {
        bundleName: 'com.huawei.hmos.settings',
        abilityName: 'com.huawei.hmos.settings.MainAbility',
        uri: 'biometrics_and_password_settings',
        parameters: {
          pushParams: bundleInfo.name
        }
      }

      await context.startAbility(want)
      return true
    } catch (err) {
      hilog.error(0x0004, TAG, `openPasswordSettings failed: ${JSON.stringify(err)}`)
      return false
    }
  }
}
