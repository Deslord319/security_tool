import { networkManager } from '@kit.MDMKit'
import { ADMIN_WANT } from '../../constants/AppConstants'
import { PermissionAppSnapshot, PermissionPolicyState } from '../../models/PermissionModels'
const IPV4_FAMILY = 1
const IPV6_FAMILY = 2

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
    applications: PermissionAppSnapshot[],
    restrictedAppUids: string[]
  ): PermissionAppSnapshot[] {
    return applications.map((app: PermissionAppSnapshot): PermissionAppSnapshot => ({
      appKey: app.appKey,
      accountId: app.accountId,
      bundleName: app.bundleName,
      appId: app.appId,
      appIndex: app.appIndex,
      uid: app.uid,
      label: app.label,
      uninstallProtected: app.uninstallProtected,
      runningBlocked: app.runningBlocked,
      networkBlocked: app.accountId === accountId && restrictedAppUids.includes(`${app.uid}`),
      threeDGroups: app.threeDGroups,
      threeDPolicies: app.threeDPolicies,
      threeDLoadState: app.threeDLoadState,
      threeDMessage: app.threeDMessage
    } as PermissionAppSnapshot))
  }

  static async setNetworkPolicy(app: PermissionAppSnapshot, policy: PermissionPolicyState): Promise<void> {
    if (app.uid <= 0) {
      throw new Error('missing uid')
    }
    await ApplicationNetworkPolicyRepository.removeRestrictedRules(app)
    if (policy === 'denied') {
      try {
        await networkManager.addFirewallRule(ADMIN_WANT, ApplicationNetworkPolicyRepository.buildBlockRule(app, IPV4_FAMILY))
        await networkManager.addFirewallRule(ADMIN_WANT, ApplicationNetworkPolicyRepository.buildBlockRule(app, IPV6_FAMILY))
      } catch (err) {
        await ApplicationNetworkPolicyRepository.removeRestrictedRules(app)
        throw new Error(`${err}`)
      }
      ApplicationNetworkPolicyRepository.assertNetworkBlocked(app)
      return
    }
    ApplicationNetworkPolicyRepository.assertNetworkUnblocked(app)
  }

  private static async removeRestrictedRules(app: PermissionAppSnapshot): Promise<void> {
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

  private static buildBlockRule(app: PermissionAppSnapshot, family: number): networkManager.FirewallRule {
    return {
      appUid: `${app.uid}`,
      direction: networkManager.Direction.OUTPUT,
      action: networkManager.Action.DENY,
      protocol: networkManager.Protocol.ALL,
      family: family
    } as networkManager.FirewallRule
  }

  private static assertNetworkBlocked(app: PermissionAppSnapshot): void {
    let restrictedRules = ApplicationNetworkPolicyRepository.getRestrictedRulesByUid(app)
    let hasIpv4Rule = restrictedRules.some((rule: networkManager.FirewallRule): boolean =>
      rule.family === undefined || rule.family === IPV4_FAMILY
    )
    let hasIpv6Rule = restrictedRules.some((rule: networkManager.FirewallRule): boolean =>
      rule.family === IPV6_FAMILY
    ) || restrictedRules.length >= 2
    if (!hasIpv4Rule || !hasIpv6Rule) {
      throw new Error('network policy verify failed')
    }
  }

  private static assertNetworkUnblocked(app: PermissionAppSnapshot): void {
    if (ApplicationNetworkPolicyRepository.getRestrictedRulesByUid(app).length > 0) {
      throw new Error('network policy remove verify failed')
    }
  }

  private static getRestrictedRulesByUid(app: PermissionAppSnapshot): networkManager.FirewallRule[] {
    return networkManager.getFirewallRules(ADMIN_WANT)
      .filter((rule: networkManager.FirewallRule): boolean =>
        rule.appUid === `${app.uid}` && ApplicationNetworkPolicyRepository.isRestrictedRule(rule)
      )
  }
}
