import { describe, expect, it } from '@ohos/hypium'
import { netFirewall } from '@kit.NetworkKit'
import { FirewallDialogStrings } from '../../main/ets/constants/modules/FirewallStrings'
import {
  attachFirewallRuleUserIds,
  FIREWALL_PROTOCOL_TCP,
  FIREWALL_PROTOCOL_UDP,
  FirewallScopedRule,
  getFirewallRuleUserIds,
  UserFirewallOption
} from '../../main/ets/models/firewall/FirewallModels'
import {
  FirewallRuleFormModel,
  FirewallRuleFormState
} from '../../main/ets/components/firewall/rules/FirewallRuleFormModel'

function buildState(overrides: Partial<FirewallRuleFormState> = {}): FirewallRuleFormState {
  let state: FirewallRuleFormState = {
    ruleName: 'Allow DNS',
    ruleType: netFirewall.NetFirewallRuleType.RULE_IP,
    ruleDirection: netFirewall.NetFirewallRuleDirection.RULE_OUT,
    protocol: FIREWALL_PROTOCOL_UDP,
    remoteAddress: '8.8.8.8',
    standbyDns: '',
    localPort: '',
    remotePort: '53',
    action: netFirewall.FirewallRuleAction.RULE_ALLOW,
    selectedUserIds: [100]
  }
  if (overrides.ruleName !== undefined) {
    state.ruleName = overrides.ruleName
  }
  if (overrides.ruleType !== undefined) {
    state.ruleType = overrides.ruleType
  }
  if (overrides.ruleDirection !== undefined) {
    state.ruleDirection = overrides.ruleDirection
  }
  if (overrides.protocol !== undefined) {
    state.protocol = overrides.protocol
  }
  if (overrides.remoteAddress !== undefined) {
    state.remoteAddress = overrides.remoteAddress
  }
  if (overrides.standbyDns !== undefined) {
    state.standbyDns = overrides.standbyDns
  }
  if (overrides.localPort !== undefined) {
    state.localPort = overrides.localPort
  }
  if (overrides.remotePort !== undefined) {
    state.remotePort = overrides.remotePort
  }
  if (overrides.action !== undefined) {
    state.action = overrides.action
  }
  if (overrides.selectedUserIds !== undefined) {
    state.selectedUserIds = overrides.selectedUserIds
  }
  return state
}

export default function firewallRuleFormModelTest() {
  describe('FirewallRuleFormModel', () => {
    it('should parse IPv4 address, CIDR, range and all value', 0, () => {
      let single = FirewallRuleFormModel.parseIpInput('192.168.1.10')
      expect(single.success).assertTrue()
      expect(single.value?.[0].address).assertEqual('192.168.1.10')
      expect(single.value?.[0].mask).assertEqual(32)

      let cidr = FirewallRuleFormModel.parseIpInput('192.168.1.0/24')
      expect(cidr.success).assertTrue()
      expect(cidr.value?.[0].address).assertEqual('192.168.1.0')
      expect(cidr.value?.[0].mask).assertEqual(24)

      let range = FirewallRuleFormModel.parseIpInput('10.0.0.1-10.0.0.20')
      expect(range.success).assertTrue()
      expect(range.value?.[0].startIp).assertEqual('10.0.0.1')
      expect(range.value?.[0].endIp).assertEqual('10.0.0.20')

      let all = FirewallRuleFormModel.parseIpInput(FirewallDialogStrings.ALL_VALUE)
      expect(all.success).assertTrue()
      expect(all.value === undefined).assertTrue()

      let invalidRange = FirewallRuleFormModel.parseIpInput('10.0.0.20-10.0.0.1')
      expect(invalidRange.success).assertFalse()
      expect(invalidRange.errorMessage).assertEqual(FirewallDialogStrings.ERROR_INVALID_IP_RANGE)
    })

    it('should parse, sort, deduplicate and limit port values', 0, () => {
      let parsed = FirewallRuleFormModel.parsePortInput(
        '443,80,1000-2000,80',
        FirewallDialogStrings.ERROR_INVALID_REMOTE_PORT
      )
      expect(parsed.success).assertTrue()
      expect(parsed.value?.length).assertEqual(3)
      expect(parsed.value?.[0].startPort).assertEqual(80)
      expect(parsed.value?.[1].startPort).assertEqual(443)
      expect(parsed.value?.[2].startPort).assertEqual(1000)
      expect(parsed.value?.[2].endPort).assertEqual(2000)

      let invalid = FirewallRuleFormModel.parsePortInput('0', FirewallDialogStrings.ERROR_INVALID_REMOTE_PORT)
      expect(invalid.success).assertFalse()
      expect(invalid.errorMessage).assertEqual(FirewallDialogStrings.ERROR_INVALID_REMOTE_PORT)

      let tooMany = FirewallRuleFormModel.parsePortInput('1,2,3', FirewallDialogStrings.ERROR_INVALID_REMOTE_PORT, 2)
      expect(tooMany.success).assertFalse()
      expect(tooMany.errorMessage).assertEqual(`${FirewallDialogStrings.ERROR_PORT_ITEM_LIMIT}: 2`)
    })

    it('should validate required fields by rule type and user scope', 0, () => {
      expect(FirewallRuleFormModel.validate(buildState({ ruleName: ' ' }))).assertEqual(FirewallDialogStrings.RULE_NAME_PLACEHOLDER)
      expect(FirewallRuleFormModel.validate(buildState({
        ruleType: netFirewall.NetFirewallRuleType.RULE_DOMAIN,
        remoteAddress: ''
      }))).assertEqual(FirewallDialogStrings.ERROR_DOMAIN_REQUIRED)
      expect(FirewallRuleFormModel.validate(buildState({
        ruleType: netFirewall.NetFirewallRuleType.RULE_DOMAIN,
        remoteAddress: 'bad_domain'
      }))).assertEqual(FirewallDialogStrings.ERROR_INVALID_DOMAIN)
      expect(FirewallRuleFormModel.validate(buildState({
        ruleType: netFirewall.NetFirewallRuleType.RULE_DNS,
        remoteAddress: '999.1.1.1'
      }))).assertEqual(FirewallDialogStrings.ERROR_INVALID_DNS)
      expect(FirewallRuleFormModel.validate(buildState({
        ruleType: netFirewall.NetFirewallRuleType.RULE_DNS,
        remoteAddress: '8.8.8.8',
        standbyDns: 'bad'
      }))).assertEqual(FirewallDialogStrings.ERROR_INVALID_STANDBY_DNS)
      expect(FirewallRuleFormModel.validate(buildState({
        ruleType: netFirewall.NetFirewallRuleType.RULE_DNS,
        remoteAddress: '8.8.8.8',
        standbyDns: ''
      }))).assertEqual('')
      expect(FirewallRuleFormModel.validate(buildState({ selectedUserIds: [] }))).assertEqual(FirewallDialogStrings.ERROR_USER_SCOPE_REQUIRED)
      expect(FirewallRuleFormModel.validate(buildState({
        ruleType: netFirewall.NetFirewallRuleType.RULE_DOMAIN,
        remoteAddress: '*.example.com'
      }))).assertEqual('')
    })

    it('should build DNS rules with optional standby DNS', 0, () => {
      let rule = FirewallRuleFormModel.buildRule(buildState({
        ruleType: netFirewall.NetFirewallRuleType.RULE_DNS,
        remoteAddress: '8.8.8.8',
        standbyDns: '1.1.1.1',
        remotePort: ''
      }), undefined, false)

      expect(rule.dns?.primaryDns).assertEqual('8.8.8.8')
      expect(rule.dns?.standbyDns).assertEqual('1.1.1.1')
      expect(rule.protocol === undefined).assertTrue()
      expect(rule.remotePorts === undefined).assertTrue()

      let primaryOnlyRule = FirewallRuleFormModel.buildRule(buildState({
        ruleType: netFirewall.NetFirewallRuleType.RULE_DNS,
        remoteAddress: '8.8.4.4',
        standbyDns: ' ',
        remotePort: ''
      }), undefined, false)
      expect(primaryOnlyRule.dns?.primaryDns).assertEqual('8.8.4.4')
      expect(primaryOnlyRule.dns?.standbyDns === undefined).assertTrue()
    })

    it('should build outbound IP rules with normalized user scope', 0, () => {
      let rule = FirewallRuleFormModel.buildRule(buildState({
        ruleName: 'Allow DNS',
        action: netFirewall.FirewallRuleAction.RULE_DENY,
        selectedUserIds: [101, 100, 101]
      }), undefined, false)

      expect(rule.name).assertEqual('Allow DNS')
      expect(rule.direction).assertEqual(netFirewall.NetFirewallRuleDirection.RULE_OUT)
      expect(rule.action).assertEqual(netFirewall.FirewallRuleAction.RULE_DENY)
      expect(rule.protocol).assertEqual(FIREWALL_PROTOCOL_UDP)
      expect(rule.remoteIps?.[0].address).assertEqual('8.8.8.8')
      expect(rule.remotePorts?.[0].startPort).assertEqual(53)
      expect(rule.localIps === undefined).assertTrue()
      expect(rule.localPorts === undefined).assertTrue()
      expect(getFirewallRuleUserIds(rule).join(',')).assertEqual('100,101')
    })

    it('should build initial state and preserve edit rule identity', 0, () => {
      let initialRule = attachFirewallRuleUserIds({
        userId: 100,
        name: 'Initial',
        type: netFirewall.NetFirewallRuleType.RULE_IP,
        direction: netFirewall.NetFirewallRuleDirection.RULE_IN,
        action: netFirewall.FirewallRuleAction.RULE_ALLOW,
        protocol: FIREWALL_PROTOCOL_TCP,
        isEnabled: true,
        localIps: [{ type: 1, family: 1, address: '192.168.1.10', mask: 32 }],
        localPorts: [{ startPort: 80, endPort: 80 }]
      }, [101]) as FirewallScopedRule
      initialRule.id = 9001
      initialRule.localRuleId = 'local-rule-1'
      let users: UserFirewallOption[] = [{ userId: 100, label: '用户 100' }, { userId: 101, label: '用户 101' }]

      let state = FirewallRuleFormModel.buildInitialState(initialRule, users)
      expect(state.ruleName).assertEqual('Initial')
      expect(state.remoteAddress).assertEqual('192.168.1.10')
      expect(state.localPort).assertEqual('80')
      expect(state.selectedUserIds.join(',')).assertEqual('101')

      state.ruleName = 'Updated'
      let updatedRule = FirewallRuleFormModel.buildRule(state, initialRule, true) as FirewallScopedRule
      expect(updatedRule.id).assertEqual(9001)
      expect(updatedRule.localRuleId).assertEqual('local-rule-1')
      expect(updatedRule.name).assertEqual('Updated')
    })

    it('should build initial state for DNS rules with standby DNS', 0, () => {
      let initialRule = attachFirewallRuleUserIds({
        userId: 100,
        name: 'DNS Rule',
        type: netFirewall.NetFirewallRuleType.RULE_DNS,
        direction: netFirewall.NetFirewallRuleDirection.RULE_OUT,
        action: netFirewall.FirewallRuleAction.RULE_ALLOW,
        isEnabled: true,
        dns: {
          primaryDns: '8.8.8.8',
          standbyDns: '1.1.1.1'
        }
      }, [100]) as FirewallScopedRule

      let state = FirewallRuleFormModel.buildInitialState(initialRule, [{ userId: 100, label: '用户 100' }])

      expect(state.remoteAddress).assertEqual('8.8.8.8')
      expect(state.standbyDns).assertEqual('1.1.1.1')
    })
  })
}
