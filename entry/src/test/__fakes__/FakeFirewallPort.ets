import { netFirewall } from '@kit.NetworkKit'

export class FakeFirewallPort {
  policy: netFirewall.NetFirewallPolicy = {
    isOpen: false,
    inAction: 0,
    outAction: 0
  } as netFirewall.NetFirewallPolicy
  rules: netFirewall.NetFirewallRule[] = []
  failMode: string | null = null

  async getPolicy(): Promise<netFirewall.NetFirewallPolicy> {
    if (this.failMode === 'getPolicy') {
      throw new Error('fake_get_policy_failed')
    }
    return this.policy
  }

  async listRules(): Promise<netFirewall.NetFirewallRule[]> {
    if (this.failMode === 'listRules') {
      throw new Error('fake_list_rules_failed')
    }
    return this.rules
  }
}
