import { common } from '@kit.AbilityKit'

import {
  FirewallPresetMode,
  PREF_KEY_FIREWALL_ACTIVE_MODE,
  PREF_STORE_NAME_FIREWALL_MODE
} from '../../../models/DataModels'
import { LogUtils } from '../../../utils/LogUtils'
import { PreferencesAccessor } from '../../../storage/preferences/PreferencesAccessor'

const TAG = 'FirewallModeRepository'

export class FirewallModeRepository {
  static async getStoredModeValue(context: common.UIAbilityContext): Promise<string> {
    try {
      let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_FIREWALL_MODE)
      return await pref.getString(PREF_KEY_FIREWALL_ACTIVE_MODE, '')
    } catch (err) {
      LogUtils.error(TAG, `getStoredModeValue failed: ${JSON.stringify(err)}`)
      return ''
    }
  }

  static async getCurrentMode(context: common.UIAbilityContext): Promise<FirewallPresetMode> {
    let storedModeValue = await FirewallModeRepository.getStoredModeValue(context)
    if (storedModeValue === 'public' || storedModeValue === 'private' || storedModeValue === 'custom') {
      return storedModeValue
    }
    return 'custom'
  }

  static async saveCurrentMode(context: common.UIAbilityContext, mode: FirewallPresetMode): Promise<void> {
    try {
      let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_FIREWALL_MODE)
      let saved = await pref.setValue(PREF_KEY_FIREWALL_ACTIVE_MODE, mode)
      if (!saved) {
        LogUtils.error(TAG, `saveCurrentMode failed: preferences_write_failed, mode=${mode}`)
      }
    } catch (err) {
      LogUtils.error(TAG, `saveCurrentMode failed: ${JSON.stringify(err)}`)
    }
  }
}
