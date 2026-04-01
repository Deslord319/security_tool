import { LogUtils } from './utils/LogUtils'
import { bundleManager, common, Want } from '@kit.AbilityKit'


const TAG = 'SystemSettingsService'

interface SystemSettingsLoggableError {
  code?: number
  message?: string
}

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
      let error = err as SystemSettingsLoggableError
      LogUtils.error(TAG, `openPasswordSettings failed: code=${error?.code ?? 'unknown'}, message=${error?.message ?? 'unknown'}`)
      return false
    }
  }
}
