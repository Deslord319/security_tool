import { describe, expect, it } from '@ohos/hypium'
import { netFirewall } from '@kit.NetworkKit'
import { FirewallRuleUtils } from '../../main/ets/services/firewall/FirewallRuleUtils'
import { FirewallRuleIntent } from '../../main/ets/services/firewall/FirewallModels'

function buildIpIntent(
  localRuleId: string,
  direction: netFirewall.NetFirewallRuleDirection,
  action: netFirewall.FirewallRuleAction,
  options: {
    localIps?: netFirewall.NetFirewallIpParams[]
    remoteIps?: netFirewall.NetFirewallIpParams[]
    localPorts?: netFirewall.NetFirewallPortParams[]
    remotePorts?: netFirewall.NetFirewallPortParams[]
    protocol?: number
  } = {}
): FirewallRuleIntent {
  return {
    localRuleId: localRuleId,
    name: localRuleId,
    type: netFirewall.NetFirewallRuleType.RULE_IP,
    direction: direction,
    action: action,
    isEnabled: true,
    targetUserIds: [100],
    protocol: options.protocol ?? 6,
    localIps: options.localIps,
    remoteIps: options.remoteIps,
    localPorts: options.localPorts,
    remotePorts: options.remotePorts,
    createdAt: 1,
    updatedAt: 1
  }
}

export default function firewallRuleUtilsTest() {
  describe('FirewallRuleUtils', () => {
    it('should format ip params for single ip, cidr and range display', 0, () => {
      expect(FirewallRuleUtils.formatIpParamsForDisplay([{ address: '110.110.110.110', mask: 32 }])).assertEqual('110.110.110.110')
      expect(FirewallRuleUtils.formatIpParamsForDisplay([{ address: '8.8.8.0', mask: 24 }])).assertEqual('8.8.8.0/24')
      expect(FirewallRuleUtils.formatIpParamsForDisplay([{ startIp: '10.0.0.1', endIp: '10.0.0.20' }])).assertEqual('10.0.0.1-10.0.0.20')
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

    it('should use local fields for inbound ip conflict comparison', 0, () => {
      let existing = buildIpIntent(
        'existing',
        netFirewall.NetFirewallRuleDirection.RULE_IN,
        netFirewall.FirewallRuleAction.RULE_ALLOW,
        {
          localIps: [{ address: '192.168.1.10', mask: 32 }],
          localPorts: [{ startPort: 80, endPort: 80 }]
        }
      )
      let target = buildIpIntent(
        'target',
        netFirewall.NetFirewallRuleDirection.RULE_IN,
        netFirewall.FirewallRuleAction.RULE_DENY,
        {
          localIps: [{ address: '192.168.1.10', mask: 32 }],
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
          remoteIps: [{ address: '8.8.8.0', mask: 24 }],
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
          remoteIps: [{ startIp: '8.8.8.8', endIp: '8.8.8.8' }],
          remotePorts: [{ startPort: 1500, endPort: 1500 }]
        }
      )

      let conflict = FirewallRuleUtils.findRuleConflict([existing], target)
      expect(conflict?.kind).assertEqual('overlap_conflict')
    })
  })
}
