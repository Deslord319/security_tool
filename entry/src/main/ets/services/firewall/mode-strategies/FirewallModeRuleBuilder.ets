import { netFirewall } from '@kit.NetworkKit'

import { FirewallManagedRuleMetadata, FirewallPresetConfig, FirewallPresetMode } from '../../../models/DataModels'
import { Ipv4Utils } from '../../../utils/Ipv4Utils'
import { FirewallRulesService } from '../rules/FirewallRulesService'
import { AppInfo } from '../../../constants/AppConstants'
import { FirewallPresetRuleNameStrings } from '../../../constants/modules/FirewallStrings'

export class FirewallModeRuleBuilder {
  static buildRulesForMode(
    mode: FirewallPresetMode,
    config: FirewallPresetConfig
  ): netFirewall.NetFirewallRule[] {
    if (mode === 'custom') {
      return []
    }
    return mode === 'public'
      ? FirewallModeRuleBuilder.buildPublicRules(config.fixedPublicIp)
      : FirewallModeRuleBuilder.buildPrivateRules(config.privateCidrs, config.privateTcpPorts, config.privateUdpPorts)
  }

  static buildPublicRules(fixedPublicIp: string): netFirewall.NetFirewallRule[] {
    let rules: netFirewall.NetFirewallRule[] = []
    rules.push(...FirewallModeRuleBuilder.createInboundRules('public', 'allow_icmp', FirewallPresetRuleNameStrings.PUBLIC_ALLOW_ICMPV4, netFirewall.FirewallRuleAction.RULE_ALLOW, 1))
    rules.push(...FirewallModeRuleBuilder.createInboundRules(
      'public', 'allow_service', FirewallPresetRuleNameStrings.PUBLIC_ALLOW_SERVICE, netFirewall.FirewallRuleAction.RULE_ALLOW, 6, [80, 443]
    ))
    if (fixedPublicIp.length > 0) {
      rules.push(...FirewallModeRuleBuilder.createInboundRules(
        'public', 'allow_remote_manage', FirewallPresetRuleNameStrings.PUBLIC_ALLOW_REMOTE_MANAGE, netFirewall.FirewallRuleAction.RULE_ALLOW, 6, [22, 3389],
        [fixedPublicIp]
      ))
    }
    rules.push(...FirewallModeRuleBuilder.createInboundRules(
      'public', 'deny_smb', FirewallPresetRuleNameStrings.PUBLIC_DENY_SMB, netFirewall.FirewallRuleAction.RULE_DENY, 6, [135, 139, 445]
    ))
    rules.push(...FirewallModeRuleBuilder.createInboundRules(
      'public', 'deny_netbios', FirewallPresetRuleNameStrings.PUBLIC_DENY_NETBIOS, netFirewall.FirewallRuleAction.RULE_DENY, 17, [137, 138]
    ))
    return rules
  }

  static buildPrivateRules(
    cidrs: string[],
    privateTcpPorts: number[],
    privateUdpPorts: number[]
  ): netFirewall.NetFirewallRule[] {
    let rules: netFirewall.NetFirewallRule[] = []
    if (cidrs.length === 0) {
      return rules
    }
    rules.push(...FirewallModeRuleBuilder.createInboundRules(
      'private', 'allow_icmp', FirewallPresetRuleNameStrings.PRIVATE_ALLOW_ICMP, netFirewall.FirewallRuleAction.RULE_ALLOW, 1, undefined, cidrs
    ))
    rules.push(...FirewallModeRuleBuilder.createInboundRules(
      'private', 'allow_remote_manage', FirewallPresetRuleNameStrings.PRIVATE_ALLOW_REMOTE_MANAGE, netFirewall.FirewallRuleAction.RULE_ALLOW, 6, [22, 3389, 5900], cidrs
    ))
    rules.push(...FirewallModeRuleBuilder.createInboundRules(
      'private', 'allow_share', FirewallPresetRuleNameStrings.PRIVATE_ALLOW_SHARE, netFirewall.FirewallRuleAction.RULE_ALLOW, 6, [135, 139, 445], cidrs
    ))
    rules.push(...FirewallModeRuleBuilder.createInboundRules(
      'private', 'allow_discovery', FirewallPresetRuleNameStrings.PRIVATE_ALLOW_DISCOVERY, netFirewall.FirewallRuleAction.RULE_ALLOW, 17, [137, 138], cidrs
    ))
    if (privateTcpPorts.length > 0) {
      rules.push(...FirewallModeRuleBuilder.createInboundRules(
        'private', 'allow_private_tcp', FirewallPresetRuleNameStrings.PRIVATE_ALLOW_TCP, netFirewall.FirewallRuleAction.RULE_ALLOW, 6, privateTcpPorts, cidrs
      ))
    }
    if (privateUdpPorts.length > 0) {
      rules.push(...FirewallModeRuleBuilder.createInboundRules(
        'private', 'allow_private_udp', FirewallPresetRuleNameStrings.PRIVATE_ALLOW_UDP, netFirewall.FirewallRuleAction.RULE_ALLOW, 17, privateUdpPorts, cidrs
      ))
    }
    return rules
  }

  private static createInboundRules(
    mode: FirewallPresetMode,
    templateKey: string,
    name: string,
    action: netFirewall.FirewallRuleAction,
    protocol: number,
    localPorts?: number[],
    remoteCidrs?: string[]
  ): netFirewall.NetFirewallRule[] {
    let ports = localPorts && localPorts.length > 0 ? localPorts : [undefined]
    let usingAnyScope = !remoteCidrs || remoteCidrs.length === 0
    let scopes: Array<string | undefined> = usingAnyScope ? [undefined] : (remoteCidrs as string[])
    let rules: netFirewall.NetFirewallRule[] = []
    scopes.forEach((cidr: string | undefined) => {
      ports.forEach((port: number | undefined) => {
        let rule: netFirewall.NetFirewallRule = {
          userId: AppInfo.DEFAULT_USER_ID,
          name: name,
          direction: netFirewall.NetFirewallRuleDirection.RULE_IN,
          action: action,
          type: netFirewall.NetFirewallRuleType.RULE_IP,
          isEnabled: true,
          protocol: protocol
        }
        if (port !== undefined) {
          rule.localPorts = [{ startPort: port, endPort: port }]
        }
        if (!usingAnyScope) {
          let ipParam = FirewallModeRuleBuilder.toIpParam(cidr ?? '')
          if (!ipParam) {
            return
          }
          rule.remoteIps = [ipParam]
        }
        rules.push(FirewallRulesService.applyManagedRuleMetadata(rule, {
          owner: 'security_tool',
          mode: mode,
          kind: 'preset',
          templateKey: `${templateKey}_${usingAnyScope ? 'any' : (cidr ?? 'any')}_${port ?? 'all'}`
        } as FirewallManagedRuleMetadata))
      })
    })
    return rules
  }

  private static toIpParam(value: string): netFirewall.NetFirewallIpParams | null {
    let normalized = value.trim()
    if (normalized.length === 0) {
      return null
    }
    let parts = normalized.split('/')
    let address = parts[0].trim()
    if (!Ipv4Utils.isValidIpv4(address)) {
      return null
    }
    let mask = 32
    if (parts.length > 1) {
      let parsedMask = Number(parts[1].trim())
      if (!Number.isInteger(parsedMask) || parsedMask < 0 || parsedMask > 32) {
        return null
      }
      mask = parsedMask
    }
    return {
      type: 1,
      family: 1,
      address: address,
      mask: mask
    }
  }
}
