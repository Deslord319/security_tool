import { LogUtils } from '../utils/LogUtils'
;
import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit';


export default class EntryBackupAbility extends BackupExtensionAbility {
  async onBackup() {
    LogUtils.info('testTag', 'onBackup ok');
    await Promise.resolve();
  }

  async onRestore(bundleVersion: BundleVersion) {
    LogUtils.info('testTag', 'onRestore ok %{public}s', JSON.stringify(bundleVersion));
    await Promise.resolve();
  }
}
