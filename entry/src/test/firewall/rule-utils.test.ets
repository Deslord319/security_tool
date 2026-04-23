import { describe, expect, it } from '@ohos/hypium'
import { netFirewall } from '@kit.NetworkKit'
import { FirewallRuleUtils } from '../../main/ets/services/firewall/FirewallRuleUtils'
import { FirewallRuleIntent } from '../../main/ets/services/firewall/FirewallModels'

interface BuildIpIntentOptions {
  localIps?: netFirewall.NetFirewallIpParams[]
  remoteIps?: netFirewall.NetFirewallIpParams[]
  localPorts?: netFirewall.NetFirewallPortParams[]
  remotePorts?: netFirewall.NetFirewallPortParams[]
  protocol?: number
  targetUserIds?: number[]
}

function buildIpv4Address(address: string, mask: number): netFirewall.NetFirewallIpParams {
  return {
    type: 1,
    family: 1,
    address: address,
    mask: mask
  }
}

function buildIpv4Range(startIp: string, endIp: string): netFirewall.NetFirewallIpParams {
  return {
    type: 2,
    family: 1,
    startIp: startIp,
    endIp: endIp
  }
}

function buildIpIntent(
  localRuleId: string,
  direction: netFirewall.NetFirewallRuleDirection,
  action: netFirewall.FirewallRuleAction,
  options: BuildIpIntentOptions = {}
): FirewallRuleIntent {
  return {
    localRuleId: localRuleId,
    name: localRuleId,
    type: netFirewall.NetFirewallRuleType.RULE_IP,
    direction: direction,
    action: action,
    isEnabled: true,
    targetUserIds: options.targetUserIds ?? [100],
    protocol: options.protocol ?? 6,
    localIps: options.localIps,
    remoteIps: options.remoteIps,
    localPorts: options.localPorts,
    remotePorts: options.remotePorts,
    createdAt: 1,
    updatedAt: 1
  }
}

function buildDomainIntent(
  localRuleId: string,
  domain: string,
  action: netFirewall.FirewallRuleAction,
  targetUserIds: number[] = [100]
): FirewallRuleIntent {
  return {
    localRuleId: localRuleId,
    name: localRuleId,
    type: netFirewall.NetFirewallRuleType.RULE_DOMAIN,
    direction: netFirewall.NetFirewallRuleDirection.RULE_OUT,
    action: action,
    isEnabled: true,
    targetUserIds: targetUserIds,
    domains: [{ domain: domain, isWildcard: false }],
    createdAt: 1,
    updatedAt: 1
  }
}

function buildDnsIntent(
  localRuleId: string,
  primaryDns: string,
  action: netFirewall.FirewallRuleAction,
  targetUserIds: number[] = [100]
): FirewallRuleIntent {
  return {
    localRuleId: localRuleId,
    name: localRuleId,
    type: netFirewall.NetFirewallRuleType.RULE_DNS,
    direction: netFirewall.NetFirewallRuleDirection.RULE_OUT,
    action: action,
    isEnabled: true,
    targetUserIds: targetUserIds,
    dns: { primaryDns: primaryDns },
    createdAt: 1,
    updatedAt: 1
  }
}

export default function firewallRuleUtilsTest() {
  describe('FirewallRuleUtils', () => {
    it('should format ip params for single ip, cidr and range display', 0, () => {
      expect(FirewallRuleUtils.formatIpParamsForDisplay([buildIpv4Address('110.110.110.110', 32)])).assertEqual('110.110.110.110')
      expect(FirewallRuleUtils.formatIpParamsForDisplay([buildIpv4Address('8.8.8.0', 24)])).assertEqual('8.8.8.0/24')
      expect(FirewallRuleUtils.formatIpParamsForDisplay([buildIpv4Range('10.0.0.1', '10.0.0.20')])).assertEqual('10.0.0.1-10.0.0.20')
      expect(FirewallRuleUtils.formatIpParamsForDisplay(undefined)).assertEqual('')
    })

    it('should sort and deduplicate port params for display', 0, () => {
      expect(FirewallRuleUtils.formatPortParamsForDisplay([
        { startPort: 443, endPort: 443 },
        { startPort: 80, endPort: 80 },
        { startPort: 80, endPort: 80 },
        { startPort: 1000, endPort: 2000 }
      ])).assertEqual('80,443,1000-2000')
    })

    it('should allow empty ip rule address and ports during intent validation', 0, () => {
      let result = FirewallRuleUtils.validateRuleIntentInput({
        name: 'allow-all-out',
        type: netFirewall.NetFirewallRuleType.RULE_IP,
        direction: netFirewall.NetFirewallRuleDirection.RULE_OUT,
        action: netFirewall.FirewallRuleAction.RULE_ALLOW,
        targetUserIds: [100]
      })
      expect(result.success).assertTrue()
    })

    it('should reject invalid rule intent inputs with concrete messages', 0, () => {
      let emptyName = FirewallRuleUtils.validateRuleIntentInput({
        name: ' ',
        type: netFirewall.NetFirewallRuleType.RULE_IP,
        direction: netFirewall.NetFirewallRuleDirection.RULE_OUT,
        action: netFirewall.FirewallRuleAction.RULE_ALLOW,
        targetUserIds: [100]
      })
      expect(emptyName.success).assertFalse()
      expect(emptyName.errorMessage).assertEqual('rule name is required')

      let missingUsers = FirewallRuleUtils.validateRuleIntentInput({
        name: 'missing-users',
        type: netFirewall.NetFirewallRuleType.RULE_IP,
        direction: netFirewall.NetFirewallRuleDirection.RULE_OUT,
        action: netFirewall.FirewallRuleAction.RULE_ALLOW,
        targetUserIds: [-1]
      })
      expect(missingUsers.success).assertFalse()
      expect(missingUsers.errorMessage).assertEqual('target users are required')

      let missingDomain = FirewallRuleUtils.validateRuleIntentInput({
        name: 'missing-domain',
        type: netFirewall.NetFirewallRuleType.RULE_DOMAIN,
        direction: netFirewall.NetFirewallRuleDirection.RULE_OUT,
        action: netFirewall.FirewallRuleAction.RULE_ALLOW,
        targetUserIds: [100]
      })
      expect(missingDomain.success).assertFalse()
      expect(missingDomain.errorMessage).assertEqual('domain rule requires domain')

      let missingDns = FirewallRuleUtils.validateRuleIntentInput({
        name: 'missing-dns',
        type: netFirewall.NetFirewallRuleType.RULE_DNS,
        direction: netFirewall.NetFirewallRuleDirection.RULE_OUT,
        action: netFirewall.FirewallRuleAction.RULE_ALLOW,
        targetUserIds: [100]
      })
      expect(missingDns.success).assertFalse()
      expect(missingDns.errorMessage).assertEqual('dns rule requires primary dns')
    })

    it('should normalize user ids by filtering, deduplicating and sorting', 0, () => {
      let userIds = FirewallRuleUtils.normalizeUserIds([101, -1, 100, 101, 1.5])

      expect(userIds.length).assertEqual(2)
      expect(userIds[0]).assertEqual(100)
      expect(userIds[1]).assertEqual(101)
    })

    it('should use local fields for inbound ip conflict comparison', 0, () => {
      let existing = buildIpIntent(
        'existing',
        netFirewall.NetFirewallRuleDirection.RULE_IN,
        netFirewall.FirewallRuleAction.RULE_ALLOW,
        {
          localIps: [buildIpv4Address('192.168.1.10', 32)],
          localPorts: [{ startPort: 80, endPort: 80 }]
        }
      )
      let target = buildIpIntent(
        'target',
        netFirewall.NetFirewallRuleDirection.RULE_IN,
        netFirewall.FirewallRuleAction.RULE_DENY,
        {
          localIps: [buildIpv4Address('192.168.1.10', 32)],
          localPorts: [{ startPort: 80, endPort: 80 }]
        }
      )

      let conflict = FirewallRuleUtils.findRuleConflict([existing], target)
      expect(conflict?.kind).assertEqual('hard_conflict')
    })

    it('should detect overlap when outbound port sets intersect', 0, () => {
      let existing = buildIpIntent(
        'existing',
        netFirewall.NetFirewallRuleDirection.RULE_OUT,
        netFirewall.FirewallRuleAction.RULE_ALLOW,
        {
          remoteIps: [buildIpv4Address('8.8.8.0', 24)],
          remotePorts: [
            { startPort: 80, endPort: 80 },
            { startPort: 1000, endPort: 2000 }
          ]
        }
      )
      let target = buildIpIntent(
        'target',
        netFirewall.NetFirewallRuleDirection.RULE_OUT,
        netFirewall.FirewallRuleAction.RULE_DENY,
        {
          remoteIps: [buildIpv4Range('8.8.8.8', '8.8.8.8')],
          remotePorts: [{ startPort: 1500, endPort: 1500 }]
        }
      )

      let conflict = FirewallRuleUtils.findRuleConflict([existing], target)
      expect(conflict?.kind).assertEqual('overlap_conflict')
    })

    it('should classify duplicate, none, protocol mismatch and user-scope mismatch for ip rules', 0, () => {
      let existing = buildIpIntent(
        'existing',
        netFirewall.NetFirewallRuleDirection.RULE_OUT,
        netFirewall.FirewallRuleAction.RULE_ALLOW,
        {
          remoteIps: [buildIpv4Address('8.8.8.8', 32)],
          remotePorts: [{ startPort: 443, endPort: 443 }],
          protocol: 6,
          targetUserIds: [100]
        }
      )
      let duplicate = buildIpIntent(
        'duplicate',
        netFirewall.NetFirewallRuleDirection.RULE_OUT,
        netFirewall.FirewallRuleAction.RULE_ALLOW,
        {
          remoteIps: [buildIpv4Address('8.8.8.8', 32)],
          remotePorts: [{ startPort: 443, endPort: 443 }],
          protocol: 6,
          targetUserIds: [100]
        }
      )
      let protocolMismatch = buildIpIntent(
        'protocol-mismatch',
        netFirewall.NetFirewallRuleDirection.RULE_OUT,
        netFirewall.FirewallRuleAction.RULE_DENY,
        {
          remoteIps: [buildIpv4Address('8.8.8.8', 32)],
          remotePorts: [{ startPort: 443, endPort: 443 }],
          protocol: 17,
          targetUserIds: [100]
        }
      )
      let userMismatch = buildIpIntent(
        'user-mismatch',
        netFirewall.NetFirewallRuleDirection.RULE_OUT,
        netFirewall.FirewallRuleAction.RULE_DENY,
        {
          remoteIps: [buildIpv4Address('8.8.8.8', 32)],
          remotePorts: [{ startPort: 443, endPort: 443 }],
          protocol: 6,
          targetUserIds: [101]
        }
      )
      let noOverlap = buildIpIntent(
        'no-overlap',
        netFirewall.NetFirewallRuleDirection.RULE_OUT,
        netFirewall.FirewallRuleAction.RULE_DENY,
        {
          remoteIps: [buildIpv4Address('1.1.1.1', 32)],
          remotePorts: [{ startPort: 443, endPort: 443 }],
          protocol: 6,
          targetUserIds: [100]
        }
      )

      expect(FirewallRuleUtils.findRuleConflict([existing], duplicate)?.kind).assertEqual('duplicate')
      expect(FirewallRuleUtils.findRuleConflict([existing], protocolMismatch)).assertEqual(null)
      expect(FirewallRuleUtils.findRuleConflict([existing], userMismatch)).assertEqual(null)
      expect(FirewallRuleUtils.findRuleConflict([existing], noOverlap)).assertEqual(null)
    })

    it('should treat empty ip and ports as all ranges for conflict detection', 0, () => {
      let allOutbound = buildIpIntent(
        'all-outbound',
        netFirewall.NetFirewallRuleDirection.RULE_OUT,
        netFirewall.FirewallRuleAction.RULE_ALLOW,
        {
          protocol: 0,
          targetUserIds: [100]
        }
      )
      let specificOutbound = buildIpIntent(
        'specific-outbound',
        netFirewall.NetFirewallRuleDirection.RULE_OUT,
        netFirewall.FirewallRuleAction.RULE_DENY,
        {
          remoteIps: [buildIpv4Address('8.8.8.8', 32)],
          remotePorts: [{ startPort: 443, endPort: 443 }],
          protocol: 6,
          targetUserIds: [100]
        }
      )

      let conflict = FirewallRuleUtils.findRuleConflict([allOutbound], specificOutbound)
      expect(conflict?.kind).assertEqual('overlap_conflict')
    })

    it('should classify exact domain conflicts without wildcard semantics', 0, () => {
      let existing = buildDomainIntent('domain-1', 'Example.COM.', netFirewall.FirewallRuleAction.RULE_ALLOW)
      let duplicate = buildDomainIntent('domain-2', 'example.com', netFirewall.FirewallRuleAction.RULE_ALLOW)
      let hardConflict = buildDomainIntent('domain-3', 'example.com', netFirewall.FirewallRuleAction.RULE_DENY)
      let different = buildDomainIntent('domain-4', 'other.example.com', netFirewall.FirewallRuleAction.RULE_DENY)

      expect(FirewallRuleUtils.findRuleConflict([existing], duplicate)?.kind).assertEqual('duplicate')
      expect(FirewallRuleUtils.findRuleConflict([existing], hardConflict)?.kind).assertEqual('hard_conflict')
      expect(FirewallRuleUtils.findRuleConflict([existing], different)).assertEqual(null)
    })

    it('should classify dns conflicts by primary dns only', 0, () => {
      let existing = buildDnsIntent('dns-1', '8.8.8.8', netFirewall.FirewallRuleAction.RULE_ALLOW)
      let duplicate = buildDnsIntent('dns-2', ' 8.8.8.8 ', netFirewall.FirewallRuleAction.RULE_ALLOW)
      let hardConflict = buildDnsIntent('dns-3', '8.8.8.8', netFirewall.FirewallRuleAction.RULE_DENY)
      let different = buildDnsIntent('dns-4', '1.1.1.1', netFirewall.FirewallRuleAction.RULE_DENY)

      expect(FirewallRuleUtils.findRuleConflict([existing], duplicate)?.kind).assertEqual('duplicate')
      expect(FirewallRuleUtils.findRuleConflict([existing], hardConflict)?.kind).assertEqual('hard_conflict')
      expect(FirewallRuleUtils.findRuleConflict([existing], different)).assertEqual(null)
    })

    it('should summarize conflicts and count by type and direction', 0, () => {
      let duplicateLeft = buildIpIntent(
        'dup-left',
        netFirewall.NetFirewallRuleDirection.RULE_OUT,
        netFirewall.FirewallRuleAction.RULE_ALLOW,
        {
          remoteIps: [buildIpv4Address('8.8.8.8', 32)],
          remotePorts: [{ startPort: 443, endPort: 443 }],
          targetUserIds: [100]
        }
      )
      let duplicateRight = buildIpIntent(
        'dup-right',
        netFirewall.NetFirewallRuleDirection.RULE_OUT,
        netFirewall.FirewallRuleAction.RULE_ALLOW,
        {
          remoteIps: [buildIpv4Address('8.8.8.8', 32)],
          remotePorts: [{ startPort: 443, endPort: 443 }],
          targetUserIds: [100]
        }
      )
      let hardLeft = buildDomainIntent('hard-left', 'example.com', netFirewall.FirewallRuleAction.RULE_ALLOW, [101])
      let hardRight = buildDomainIntent('hard-right', 'example.com', netFirewall.FirewallRuleAction.RULE_DENY, [101])
      let overlapLeft = buildIpIntent(
        'overlap-left',
        netFirewall.NetFirewallRuleDirection.RULE_IN,
        netFirewall.FirewallRuleAction.RULE_ALLOW,
        {
          localIps: [buildIpv4Address('192.168.1.0', 24)],
          localPorts: [{ startPort: 80, endPort: 100 }],
          targetUserIds: [102]
        }
      )
      let overlapRight = buildIpIntent(
        'overlap-right',
        netFirewall.NetFirewallRuleDirection.RULE_IN,
        netFirewall.FirewallRuleAction.RULE_DENY,
        {
          localIps: [buildIpv4Address('192.168.1.20', 32)],
          localPorts: [{ startPort: 100, endPort: 100 }],
          targetUserIds: [102]
        }
      )
      let dnsRule = buildDnsIntent('dns-count', '8.8.4.4', netFirewall.FirewallRuleAction.RULE_ALLOW, [103])
      let intents: FirewallRuleIntent[] = [
        duplicateLeft,
        duplicateRight,
        hardLeft,
        hardRight,
        overlapLeft,
        overlapRight,
        dnsRule
      ]

      let summary = FirewallRuleUtils.summarizeConflicts(intents)
      expect(summary.duplicates).assertEqual(1)
      expect(summary.hardConflicts).assertEqual(1)
      expect(summary.overlapConflicts).assertEqual(1)
    })
  })
}
