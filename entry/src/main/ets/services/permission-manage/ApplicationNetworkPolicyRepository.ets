import { networkManager } from '@kit.MDMKit'
import { ADMIN_WANT } from '../../constants/AppConstants'
import { PermissionAppSnapshot, PermissionPolicyState } from '../../models/PermissionModels'
import { LogUtils } from '../../utils/LogUtils'

const TAG = 'ApplicationNetworkPolicyRepository'
const IPV4_FAMILY = 1
const IPV6_FAMILY = 2

export class ApplicationNetworkPolicyRepository {
  static loadRestrictedAppUidsStrict(): string[] {
    try {
      return networkManager.getFirewallRules(ADMIN_WANT)
        .filter((rule: networkManager.FirewallRule): boolean => ApplicationNetworkPolicyRepository.isRestrictedRule(rule))
        .map((rule: networkManager.FirewallRule): string => rule.appUid ?? '')
        .filter((appUid: string, index: number, all: string[]): boolean =>
          appUid.length > 0 && all.indexOf(appUid) === index
        )
    } catch (err) {
      LogUtils.warn(TAG, `loadRestrictedAppUidsStrict failed: ${JSON.stringify(err)}`)
      return []
    }
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
      appIdentifier: app.appIdentifier,
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
    let restrictedRules = ApplicationNetworkPolicyRepository.getRestrictedRulesByUid(app)
    if (policy === 'denied') {
      await ApplicationNetworkPolicyRepository.ensureBlockedRules(app, restrictedRules)
      ApplicationNetworkPolicyRepository.assertNetworkBlocked(app)
      return
    }
    await ApplicationNetworkPolicyRepository.removeRestrictedRules(restrictedRules)
    ApplicationNetworkPolicyRepository.assertNetworkUnblocked(app)
  }

  private static async ensureBlockedRules(
    app: PermissionAppSnapshot,
    restrictedRules: networkManager.FirewallRule[]
  ): Promise<void> {
    let addedRules: networkManager.FirewallRule[] = []
    try {
      if (!ApplicationNetworkPolicyRepository.hasIpv4Rule(restrictedRules)) {
        let rule = ApplicationNetworkPolicyRepository.buildBlockRule(app, IPV4_FAMILY)
        await networkManager.addFirewallRule(ADMIN_WANT, rule)
        addedRules.push(rule)
      }
      if (!ApplicationNetworkPolicyRepository.hasIpv6Rule(restrictedRules)) {
        let rule = ApplicationNetworkPolicyRepository.buildBlockRule(app, IPV6_FAMILY)
        await networkManager.addFirewallRule(ADMIN_WANT, rule)
        addedRules.push(rule)
      }
    } catch (err) {
      await ApplicationNetworkPolicyRepository.removeRestrictedRules(addedRules)
      throw new Error(`${err}`)
    }
  }

  private static async removeRestrictedRules(rules: networkManager.FirewallRule[]): Promise<void> {
    for (let rule of rules) {
      try {
        await networkManager.removeFirewallRule(ADMIN_WANT, rule)
      } catch (err) {
        LogUtils.warn(TAG, `removeFirewallRule failed: ${JSON.stringify(err)}`)
        throw new Error(`removeFirewallRule failed: ${JSON.stringify(err)}`)
      }
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
    if (!ApplicationNetworkPolicyRepository.hasIpv4Rule(restrictedRules) ||
      !ApplicationNetworkPolicyRepository.hasIpv6Rule(restrictedRules)) {
      throw new Error('network policy verify failed')
    }
  }

  private static assertNetworkUnblocked(app: PermissionAppSnapshot): void {
    if (ApplicationNetworkPolicyRepository.getRestrictedRulesByUid(app).length > 0) {
      throw new Error('network policy remove verify failed')
    }
  }

  private static getRestrictedRulesByUid(app: PermissionAppSnapshot): networkManager.FirewallRule[] {
    try {
      return networkManager.getFirewallRules(ADMIN_WANT)
        .filter((rule: networkManager.FirewallRule): boolean =>
          rule.appUid === `${app.uid}` && ApplicationNetworkPolicyRepository.isRestrictedRule(rule)
        )
    } catch (err) {
      LogUtils.warn(TAG, `getRestrictedRulesByUid failed: ${JSON.stringify(err)}`)
      return []
    }
  }

  private static hasIpv4Rule(rules: networkManager.FirewallRule[]): boolean {
    return rules.some((rule: networkManager.FirewallRule): boolean =>
      rule.family === undefined || rule.family === IPV4_FAMILY
    )
  }

  private static hasIpv6Rule(rules: networkManager.FirewallRule[]): boolean {
    return rules.some((rule: networkManager.FirewallRule): boolean =>
      rule.family === IPV6_FAMILY
    ) || rules.length >= 2
  }
}
