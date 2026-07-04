import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit'
import { LogUtils } from '../utils/LogUtils'

const TAG = 'EntryBackupAbility'

export default class EntryBackupAbility extends BackupExtensionAbility {
  async onBackup() {
    LogUtils.info(TAG, 'onBackup ok')
  }

  async onRestore(bundleVersion: BundleVersion) {
    LogUtils.info(TAG, `onRestore ok ${JSON.stringify(bundleVersion)}`)
  }
}
