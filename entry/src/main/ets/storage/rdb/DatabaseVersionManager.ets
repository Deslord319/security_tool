import relationalStore from '@ohos.data.relationalStore'
import { AppInfo } from '../../constants/AppConstants'

export class DatabaseVersionManager {
  private static versions: Map<string, number> = new Map([
    [AppInfo.DB_NAME, 1]
  ])

  static getVersion(name: string): number {
    return DatabaseVersionManager.versions.get(name) ?? 1
  }

  static buildConfig(name: string): relationalStore.StoreConfig {
    return {
      name,
      securityLevel: relationalStore.SecurityLevel.S1
    }
  }
}
