import { describe, expect, it } from '@ohos/hypium'
import { netFirewall } from '@kit.NetworkKit'
import { FirewallManagedRuleMetadata } from '../../main/ets/models/DataModels'
import { FirewallRepository } from '../../main/ets/services/firewall/repositories/FirewallRepository'
import { FirewallRulesService } from '../../main/ets/services/firewall/rules/FirewallRulesService'

function createIpRule(
  ruleId: number,
  startIp: string,
  endIp: string,
  startPort: number,
  endPort: number,
  action: number
): netFirewall.NetFirewallRule {
  return {
    ruleId,
    userId: 100,
    name: `ip-rule-${ruleId}`,
    direction: netFirewall.NetFirewallRuleDirection.RULE_IN,
    action,
    type: netFirewall.NetFirewallRuleType.RULE_IP,
    isEnabled: true,
    protocol: 6,
    remoteIps: [{
      type: 2,
      family: 1,
      startIp,
      endIp
    } as netFirewall.NetFirewallIpParams],
    remotePorts: [{
      startPort,
      endPort
    } as netFirewall.NetFirewallPortParams]
  } as netFirewall.NetFirewallRule
}

function createDomainRule(
  ruleId: number,
  domain: string,
  action: number,
  direction: netFirewall.NetFirewallRuleDirection = netFirewall.NetFirewallRuleDirection.RULE_OUT
): netFirewall.NetFirewallRule {
  return {
    ruleId,
    userId: 100,
    name: `domain-rule-${ruleId}`,
    direction,
    action,
    type: netFirewall.NetFirewallRuleType.RULE_DOMAIN,
    isEnabled: true,
    domains: [{
      domain
    } as netFirewall.NetFirewallDomainParams]
  } as netFirewall.NetFirewallRule
}

export default function firewallRulesServiceTest() {
  describe('FirewallRulesService', () => {
    it('should build and parse managed rule metadata', 0, () => {
      let metadata: FirewallManagedRuleMetadata = {
        owner: 'security_tool',
        mode: 'public',
        kind: 'preset',
        templateKey: 'public-ip'
      }

      let description = FirewallRulesService.buildManagedRuleDescription(metadata)
      let parsed = FirewallRulesService.parseManagedRuleDescription(description)

      expect(description.indexOf('SECURITY_TOOL_META:')).assertEqual(0)
      expect(parsed !== null).assertTrue()
      expect(parsed!.mode).assertEqual('public')
      expect(parsed!.kind).assertEqual('preset')
    })

    it('should reject invalid managed rule metadata payload', 0, () => {
      let parsed = FirewallRulesService.parseManagedRuleDescription('SECURITY_TOOL_META:{"owner":"other"}')
      expect(parsed === null).assertTrue()
    })

    it('should apply managed metadata into cloned rule description', 0, () => {
      let metadata: FirewallManagedRuleMetadata = {
        owner: 'security_tool',
        mode: 'custom',
        kind: 'custom',
        customRuleId: 'rule-1'
      }
      let rule = createDomainRule(1, 'example.com', 0)

      let result = FirewallRulesService.applyManagedRuleMetadata(rule, metadata)

      expect(result.description !== undefined).assertTrue()
      expect((result.description ?? '').indexOf('SECURITY_TOOL_META:')).assertEqual(0)
    })

    it('should detect duplicate ip rules', 0, () => {
      let existing = createIpRule(1, '10.0.0.1', '10.0.0.10', 80, 80, 0)
      let target = createIpRule(2, '10.0.0.1', '10.0.0.10', 80, 80, 0)

      let conflict = FirewallRulesService.findRuleConflict([existing], target)

      expect(conflict !== null).assertTrue()
      expect(conflict!.kind).assertEqual('duplicate')
      expect(FirewallRepository.getRulePrimaryKey(conflict!.existingRule)).assertEqual(1)
    })

    it('should detect hard conflict for same key with different action', 0, () => {
      let existing = createDomainRule(1, 'example.com', 0)
      let target = createDomainRule(2, 'example.com', 1)

      let conflict = FirewallRulesService.findRuleConflict([existing], target)

      expect(conflict !== null).assertTrue()
      expect(conflict!.kind).assertEqual('hard_conflict')
    })

    it('should detect overlap conflict for wildcard and exact domain', 0, () => {
      let existing = createDomainRule(1, '*.example.com', 0)
      let target = createDomainRule(2, 'api.example.com', 1)

      let conflict = FirewallRulesService.findRuleConflict([existing], target)

      expect(conflict !== null).assertTrue()
      expect(conflict!.kind).assertEqual('overlap_conflict')
    })

    it('should summarize conflict counts across rule set', 0, () => {
      let rules: netFirewall.NetFirewallRule[] = [
        createDomainRule(1, 'example.com', 0),
        createDomainRule(2, 'example.com', 1),
        createDomainRule(3, '*.example.com', 0),
        createDomainRule(4, 'api.example.com', 1)
      ]

      let summary = FirewallRulesService.summarizeConflicts(rules)

      expect(summary.hardConflicts).assertEqual(1)
      expect(summary.overlapConflicts).assertEqual(1)
    })

    it('should count rules by type and direction', 0, () => {
      let rules: netFirewall.NetFirewallRule[] = [
        createIpRule(1, '10.0.0.1', '10.0.0.2', 80, 80, 0),
        createDomainRule(2, 'example.com', 0),
        createDomainRule(3, 'api.example.com', 1, netFirewall.NetFirewallRuleDirection.RULE_IN)
      ]

      expect(FirewallRulesService.countByType(rules, netFirewall.NetFirewallRuleType.RULE_DOMAIN)).assertEqual(2)
      expect(FirewallRulesService.countByDirection(rules, netFirewall.NetFirewallRuleDirection.RULE_IN)).assertEqual(2)
    })
  })
}
