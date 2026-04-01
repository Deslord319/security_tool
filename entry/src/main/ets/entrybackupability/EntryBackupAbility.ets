import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit'

export default class EntryBackupAbility extends BackupExtensionAbility {
  async onBackup(): Promise<void> {
    await Promise.resolve()
  }

  async onRestore(bundleVersion: BundleVersion): Promise<void> {
    void bundleVersion
    await Promise.resolve()
  }
}
