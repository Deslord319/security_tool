import { netFirewall } from '@kit.NetworkKit'

import { FirewallManagedRuleMetadata, FirewallPresetConfig, FirewallPresetMode } from '../../../models/DataModels'
import { FirewallRulesService } from '../rules/FirewallRulesService'

const DEFAULT_USER_ID = 100

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
    rules.push(...FirewallModeRuleBuilder.createInboundRules('public', 'allow_icmp', '允许 ICMPv4', netFirewall.FirewallRuleAction.RULE_ALLOW, 1))
    rules.push(...FirewallModeRuleBuilder.createInboundRules(
      'public', 'allow_service', '允许对外服务', netFirewall.FirewallRuleAction.RULE_ALLOW, 6, [80, 443]
    ))
    if (fixedPublicIp.length > 0) {
      rules.push(...FirewallModeRuleBuilder.createInboundRules(
        'public', 'allow_remote_manage', '允许远程管理', netFirewall.FirewallRuleAction.RULE_ALLOW, 6, [22, 3389],
        [fixedPublicIp]
      ))
    }
    rules.push(...FirewallModeRuleBuilder.createInboundRules(
      'public', 'deny_smb', '阻止 SMB 共享', netFirewall.FirewallRuleAction.RULE_DENY, 6, [135, 139, 445]
    ))
    rules.push(...FirewallModeRuleBuilder.createInboundRules(
      'public', 'deny_netbios', '阻止 NetBIOS', netFirewall.FirewallRuleAction.RULE_DENY, 17, [137, 138]
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
      'private', 'allow_icmp', '允许 ICMP', netFirewall.FirewallRuleAction.RULE_ALLOW, 1, undefined, cidrs
    ))
    rules.push(...FirewallModeRuleBuilder.createInboundRules(
      'private', 'allow_remote_manage', '允许内网远程', netFirewall.FirewallRuleAction.RULE_ALLOW, 6, [22, 3389, 5900], cidrs
    ))
    rules.push(...FirewallModeRuleBuilder.createInboundRules(
      'private', 'allow_share', '允许内网共享', netFirewall.FirewallRuleAction.RULE_ALLOW, 6, [135, 139, 445], cidrs
    ))
    rules.push(...FirewallModeRuleBuilder.createInboundRules(
      'private', 'allow_discovery', '允许内网发现', netFirewall.FirewallRuleAction.RULE_ALLOW, 17, [137, 138], cidrs
    ))
    if (privateTcpPorts.length > 0) {
      rules.push(...FirewallModeRuleBuilder.createInboundRules(
        'private', 'allow_private_tcp', '允许内网应用 TCP', netFirewall.FirewallRuleAction.RULE_ALLOW, 6, privateTcpPorts, cidrs
      ))
    }
    if (privateUdpPorts.length > 0) {
      rules.push(...FirewallModeRuleBuilder.createInboundRules(
        'private', 'allow_private_udp', '允许内网应用 UDP', netFirewall.FirewallRuleAction.RULE_ALLOW, 17, privateUdpPorts, cidrs
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
          userId: DEFAULT_USER_ID,
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
    if (!FirewallModeRuleBuilder.isValidIpv4(address)) {
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

  private static isValidIpv4(address: string): boolean {
    let segments = address.split('.')
    if (segments.length !== 4) {
      return false
    }
    return segments.every((segment: string): boolean => {
      if (!/^\d+$/.test(segment)) {
        return false
      }
      let value = Number(segment)
      return Number.isInteger(value) && value >= 0 && value <= 255
    })
  }
}
