import { networkManager } from '@kit.MDMKit'
import { ADMIN_WANT } from '../../constants/AppConstants'
import { ManagedApplicationInfo, PermissionPolicyState } from '../../models/PermissionModels'
const IPV4_FAMILY = 1

export class ApplicationNetworkPolicyRepository {
  static loadRestrictedAppUidsStrict(): string[] {
    return networkManager.getFirewallRules(ADMIN_WANT)
      .filter((rule: networkManager.FirewallRule): boolean => ApplicationNetworkPolicyRepository.isRestrictedRule(rule))
      .map((rule: networkManager.FirewallRule): string => rule.appUid ?? '')
      .filter((appUid: string, index: number, all: string[]): boolean =>
        appUid.length > 0 && all.indexOf(appUid) === index
      )
  }

  static mergeNetworkStates(
    accountId: number,
    applications: ManagedApplicationInfo[],
    restrictedAppUids: string[]
  ): ManagedApplicationInfo[] {
    return applications.map((app: ManagedApplicationInfo): ManagedApplicationInfo => ({
      key: app.key,
      accountId: app.accountId,
      bundleName: app.bundleName,
      appIdentifier: app.appIdentifier,
      appIndex: app.appIndex,
      uid: app.uid,
      label: app.label,
      versionName: app.versionName,
      iconData: app.iconData,
      systemApp: app.systemApp,
      removable: app.removable,
      installSource: app.installSource,
      appDistributionType: app.appDistributionType,
      mainAbilityName: app.mainAbilityName,
      installPolicy: app.installPolicy,
      uninstallProtected: app.uninstallProtected,
      runningPolicy: app.runningPolicy,
      networkPolicy: app.accountId === accountId && restrictedAppUids.includes(`${app.uid}`) ? 'denied' : 'default'
    } as ManagedApplicationInfo))
  }

  static async setNetworkPolicy(app: ManagedApplicationInfo, policy: PermissionPolicyState): Promise<void> {
    if (app.uid <= 0) {
      throw new Error('missing uid')
    }
    await ApplicationNetworkPolicyRepository.removeRestrictedRules(app)
    if (policy === 'denied') {
      await networkManager.addFirewallRule(ADMIN_WANT, ApplicationNetworkPolicyRepository.buildBlockRule(app))
    }
  }

  private static async removeRestrictedRules(app: ManagedApplicationInfo): Promise<void> {
    let rules = networkManager.getFirewallRules(ADMIN_WANT)
      .filter((rule: networkManager.FirewallRule): boolean =>
        rule.appUid === `${app.uid}` && ApplicationNetworkPolicyRepository.isRestrictedRule(rule)
      )
    for (let rule of rules) {
      await networkManager.removeFirewallRule(ADMIN_WANT, rule)
    }
  }

  private static isRestrictedRule(rule: networkManager.FirewallRule): boolean {
    return rule.appUid !== undefined &&
      (rule.action === networkManager.Action.DENY || rule.action === networkManager.Action.REJECT)
  }

  private static buildBlockRule(app: ManagedApplicationInfo): networkManager.FirewallRule {
    return {
      appUid: `${app.uid}`,
      direction: networkManager.Direction.OUTPUT,
      action: networkManager.Action.DENY,
      protocol: networkManager.Protocol.ALL,
      family: IPV4_FAMILY
    } as networkManager.FirewallRule
  }
}
