import relationalStore from '@ohos.data.relationalStore'

export class DatabaseVersionManager {
  private static versions: Map<string, number> = new Map([
    ['security_tool.db', 1]
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
