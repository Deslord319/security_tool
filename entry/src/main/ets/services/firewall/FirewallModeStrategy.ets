import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'
import { AppInfo } from '../../constants/AppConstants'
import { FirewallPresetRuleNameStrings } from '../../constants/modules/FirewallStrings'
import { LooseValue } from '../../types/LooseValueTypes'
import { Ipv4Utils } from '../../utils/Ipv4Utils'
import { LogUtils } from '../../utils/LogUtils'
import { FirewallLocalRepository } from './FirewallLocalRepository'
import {
  FIREWALL_IPV4_FAMILY,
  FIREWALL_IPV4_MASK_MAX,
  FIREWALL_IPV4_MASK_MIN,
  FIREWALL_IPV4_PARAM_TYPE,
  FIREWALL_PORT_MAX,
  FIREWALL_PORT_MIN,
  FIREWALL_PROTOCOL_ICMP,
  FIREWALL_PROTOCOL_TCP,
  FIREWALL_PROTOCOL_UDP,
  FirewallPreparedRule,
  FirewallPresetConfig,
  FirewallPresetMode,
  UserFirewallOption
} from './FirewallModels'
import { FirewallRuleUtils } from './FirewallRuleUtils'
import { SystemUserProvider } from './providers/SystemUserProvider'

const TAG = 'FirewallModeStrategy'
const CONFIG_RAW_FILE = 'firewall_preset_config.json'
const FIREWALL_PORT_HTTP = 80
const FIREWALL_PORT_HTTPS = 443
const FIREWALL_PORT_SSH = 22
const FIREWALL_PORT_TELNET = 23
const FIREWALL_PORT_RDP = 3389
const FIREWALL_PORT_VNC = 5900
const FIREWALL_PORT_SMB_RPC = 135
const FIREWALL_PORT_SMB_NETBIOS = 139
const FIREWALL_PORT_SMB_DIRECT = 445
const FIREWALL_PORT_NETBIOS_NAME = 137
const FIREWALL_PORT_NETBIOS_DATAGRAM = 138
const PUBLIC_SERVICE_PORTS: number[] = [FIREWALL_PORT_HTTP, FIREWALL_PORT_HTTPS]
const PUBLIC_REMOTE_MANAGEMENT_PORTS: number[] = [
  FIREWALL_PORT_SSH,
  FIREWALL_PORT_TELNET,
  FIREWALL_PORT_RDP,
  FIREWALL_PORT_VNC
]
const PRIVATE_REMOTE_MANAGEMENT_PORTS: number[] = [FIREWALL_PORT_SSH, FIREWALL_PORT_RDP, FIREWALL_PORT_VNC]
const SMB_PORTS: number[] = [FIREWALL_PORT_SMB_RPC, FIREWALL_PORT_SMB_NETBIOS, FIREWALL_PORT_SMB_DIRECT]
const NETBIOS_PORTS: number[] = [FIREWALL_PORT_NETBIOS_NAME, FIREWALL_PORT_NETBIOS_DATAGRAM]

const DEFAULT_CONFIG: FirewallPresetConfig = {
  fixedPublicIp: '',
  privateCidrs: [],
  privateTcpPorts: [],
  privateUdpPorts: []
}

export class FirewallModeStrategy {
  static async buildRulesForMode(
    context: common.UIAbilityContext,
    mode: FirewallPresetMode,
    users?: UserFirewallOption[]
  ): Promise<FirewallPreparedRule[]> {
    if (mode === 'public') {
      return FirewallModeStrategy.buildPublicRules(context, users)
    }
    if (mode === 'private') {
      return FirewallModeStrategy.buildPrivateRules(context, users)
    }
    return FirewallModeStrategy.buildCustomRules(context)
  }

  static async buildPublicRules(
    _context: common.UIAbilityContext,
    users?: UserFirewallOption[]
  ): Promise<FirewallPreparedRule[]> {
    let usersResult = users === undefined ? await SystemUserProvider.loadAvailableUserIds() : undefined
    let templates = FirewallModeStrategy.buildPublicRuleTemplates()
    return FirewallModeStrategy.expandTemplatesForUsers(templates, users ?? usersResult?.users ?? [])
  }

  static async buildPrivateRules(
    context: common.UIAbilityContext,
    users?: UserFirewallOption[]
  ): Promise<FirewallPreparedRule[]> {
    let config = await FirewallModeStrategy.loadPresetConfig(context)
    let usersResult = users === undefined ? await SystemUserProvider.loadAvailableUserIds() : undefined
    let templates = FirewallModeStrategy.buildPrivateRuleTemplates(config.privateCidrs, config.privateTcpPorts, config.privateUdpPorts)
    return FirewallModeStrategy.expandTemplatesForUsers(templates, users ?? usersResult?.users ?? [])
  }

  static async buildCustomRules(context: common.UIAbilityContext): Promise<FirewallPreparedRule[]> {
    let intents = await FirewallLocalRepository.listRuleIntents(context)
    let preparedRules: FirewallPreparedRule[] = []
    for (let i = 0; i < intents.length; i++) {
      let intent = intents[i]
      let targetUserIds = FirewallRuleUtils.normalizeUserIds(intent.targetUserIds)
      for (let j = 0; j < targetUserIds.length; j++) {
        let userId = targetUserIds[j]
        let rule = FirewallRuleUtils.buildSystemRuleFromIntent(intent, userId)
        preparedRules.push({
          localRuleId: intent.localRuleId,
          userId: userId,
          rule: FirewallRuleUtils.normalizeRuleForCreate(rule)
        })
      }
    }
    return preparedRules
  }

  static async loadPresetConfig(context: common.UIAbilityContext): Promise<FirewallPresetConfig> {
    try {
      let rawContent = await context.resourceManager.getRawFileContent(CONFIG_RAW_FILE)
      let jsonText = FirewallModeStrategy.bytesToString(rawContent)
      let parsed = JSON.parse(jsonText) as Partial<FirewallPresetConfig>
      return FirewallModeStrategy.normalizeConfig(parsed)
    } catch (err) {
      LogUtils.error(TAG, `loadPresetConfig failed: ${JSON.stringify(err)}`)
      return FirewallModeStrategy.cloneDefaultConfig()
    }
  }

  private static expandTemplatesForUsers(
    templates: netFirewall.NetFirewallRule[],
    users: UserFirewallOption[]
  ): FirewallPreparedRule[] {
    let preparedRules: FirewallPreparedRule[] = []
    users.forEach((user: UserFirewallOption) => {
      templates.forEach((template: netFirewall.NetFirewallRule) => {
        let rule = FirewallRuleUtils.cloneSystemRule(template)
        rule.userId = user.userId
        preparedRules.push({
          userId: user.userId,
          rule: FirewallRuleUtils.normalizeRuleForCreate(rule)
        })
      })
    })
    return preparedRules
  }

  private static buildPublicRuleTemplates(): netFirewall.NetFirewallRule[] {
    let rules: netFirewall.NetFirewallRule[] = []
    rules.push(...FirewallModeStrategy.createInboundRules(FirewallPresetRuleNameStrings.PUBLIC_ALLOW_ICMPV4, netFirewall.FirewallRuleAction.RULE_ALLOW, FIREWALL_PROTOCOL_ICMP))
    rules.push(...FirewallModeStrategy.createInboundRules(FirewallPresetRuleNameStrings.PUBLIC_ALLOW_SERVICE, netFirewall.FirewallRuleAction.RULE_ALLOW, FIREWALL_PROTOCOL_TCP, PUBLIC_SERVICE_PORTS))
    rules.push(...FirewallModeStrategy.createInboundRules(FirewallPresetRuleNameStrings.PUBLIC_DENY_REMOTE_ACCESS, netFirewall.FirewallRuleAction.RULE_DENY, FIREWALL_PROTOCOL_TCP, PUBLIC_REMOTE_MANAGEMENT_PORTS))
    rules.push(...FirewallModeStrategy.createInboundRules(FirewallPresetRuleNameStrings.PUBLIC_DENY_SMB, netFirewall.FirewallRuleAction.RULE_DENY, FIREWALL_PROTOCOL_TCP, SMB_PORTS))
    rules.push(...FirewallModeStrategy.createInboundRules(FirewallPresetRuleNameStrings.PUBLIC_DENY_NETBIOS, netFirewall.FirewallRuleAction.RULE_DENY, FIREWALL_PROTOCOL_UDP, NETBIOS_PORTS))
    return rules
  }

  private static buildPrivateRuleTemplates(
    cidrs: string[],
    privateTcpPorts: number[],
    privateUdpPorts: number[]
  ): netFirewall.NetFirewallRule[] {
    let rules: netFirewall.NetFirewallRule[] = []
    if (cidrs.length === 0) {
      return rules
    }
    rules.push(...FirewallModeStrategy.createInboundRules(FirewallPresetRuleNameStrings.PRIVATE_ALLOW_ICMP, netFirewall.FirewallRuleAction.RULE_ALLOW, FIREWALL_PROTOCOL_ICMP, undefined, cidrs))
    rules.push(...FirewallModeStrategy.createInboundRules(FirewallPresetRuleNameStrings.PRIVATE_ALLOW_REMOTE_MANAGE, netFirewall.FirewallRuleAction.RULE_ALLOW, FIREWALL_PROTOCOL_TCP, PRIVATE_REMOTE_MANAGEMENT_PORTS, cidrs))
    rules.push(...FirewallModeStrategy.createInboundRules(FirewallPresetRuleNameStrings.PRIVATE_ALLOW_SHARE, netFirewall.FirewallRuleAction.RULE_ALLOW, FIREWALL_PROTOCOL_TCP, SMB_PORTS, cidrs))
    rules.push(...FirewallModeStrategy.createInboundRules(FirewallPresetRuleNameStrings.PRIVATE_ALLOW_DISCOVERY, netFirewall.FirewallRuleAction.RULE_ALLOW, FIREWALL_PROTOCOL_UDP, NETBIOS_PORTS, cidrs))
    if (privateTcpPorts.length > 0) {
      rules.push(...FirewallModeStrategy.createInboundRules(FirewallPresetRuleNameStrings.PRIVATE_ALLOW_TCP, netFirewall.FirewallRuleAction.RULE_ALLOW, FIREWALL_PROTOCOL_TCP, privateTcpPorts, cidrs))
    }
    if (privateUdpPorts.length > 0) {
      rules.push(...FirewallModeStrategy.createInboundRules(FirewallPresetRuleNameStrings.PRIVATE_ALLOW_UDP, netFirewall.FirewallRuleAction.RULE_ALLOW, FIREWALL_PROTOCOL_UDP, privateUdpPorts, cidrs))
    }
    return rules
  }

  private static createInboundRules(
    name: string,
    action: netFirewall.FirewallRuleAction,
    protocol: number,
    localPorts?: number[],
    remoteCidrs?: string[]
  ): netFirewall.NetFirewallRule[] {
    let rules: netFirewall.NetFirewallRule[] = []
    if (!remoteCidrs || remoteCidrs.length === 0) {
      rules.push(FirewallModeStrategy.createInboundRuleTemplate(name, action, protocol, localPorts))
      return rules
    }
    remoteCidrs.forEach((cidr: string) => {
      let ipParam = FirewallModeStrategy.toIpParam(cidr)
      if (!ipParam) {
        return
      }
      let rule = FirewallModeStrategy.createInboundRuleTemplate(name, action, protocol, localPorts)
      rule.remoteIps = [ipParam]
      rules.push(rule)
    })
    return rules
  }

  private static createInboundRuleTemplate(
    name: string,
    action: netFirewall.FirewallRuleAction,
    protocol: number,
    localPorts?: number[]
  ): netFirewall.NetFirewallRule {
    let rule: netFirewall.NetFirewallRule = {
      userId: AppInfo.DEFAULT_USER_ID,
      name: name,
      direction: netFirewall.NetFirewallRuleDirection.RULE_IN,
      action: action,
      type: netFirewall.NetFirewallRuleType.RULE_IP,
      isEnabled: true,
      protocol: protocol
    }
    if (localPorts && localPorts.length > 0) {
      rule.localPorts = localPorts.map((port: number): netFirewall.NetFirewallPortParams => {
        return { startPort: port, endPort: port }
      })
    }
    return rule
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
    let mask = FIREWALL_IPV4_MASK_MAX
    if (parts.length > 1) {
      let parsedMask = Number(parts[1].trim())
      if (!Number.isInteger(parsedMask) || parsedMask < FIREWALL_IPV4_MASK_MIN || parsedMask > FIREWALL_IPV4_MASK_MAX) {
        return null
      }
      mask = parsedMask
    }
    return {
      type: FIREWALL_IPV4_PARAM_TYPE,
      family: FIREWALL_IPV4_FAMILY,
      address: address,
      mask: mask
    }
  }

  private static normalizeConfig(source: Partial<FirewallPresetConfig>): FirewallPresetConfig {
    return {
      fixedPublicIp: typeof source.fixedPublicIp === 'string' ? source.fixedPublicIp.trim() : '',
      privateCidrs: FirewallModeStrategy.normalizeStringArray(source.privateCidrs),
      privateTcpPorts: FirewallModeStrategy.normalizePorts(source.privateTcpPorts),
      privateUdpPorts: FirewallModeStrategy.normalizePorts(source.privateUdpPorts)
    }
  }

  private static normalizeStringArray(value: LooseValue): string[] {
    if (!Array.isArray(value)) {
      return []
    }
    let items: string[] = []
    value.forEach((item: LooseValue) => {
      if (typeof item === 'string') {
        let normalized = item.trim()
        if (normalized.length > 0) {
          items.push(normalized)
        }
      }
    })
    return items
  }

  private static normalizePorts(value: LooseValue): number[] {
    if (!Array.isArray(value)) {
      return []
    }
    let ports: number[] = []
    value.forEach((item: LooseValue) => {
      if (typeof item === 'number' && Number.isInteger(item) && item >= FIREWALL_PORT_MIN && item <= FIREWALL_PORT_MAX) {
        ports.push(item)
      }
    })
    return ports
  }

  private static bytesToString(data: Uint8Array): string {
    let chars: string[] = []
    for (let i = 0; i < data.length; i++) {
      let first = data[i]
      if (first <= 0x7F) {
        chars.push(String.fromCharCode(first))
        continue
      }
      if (first >= 0xC2 && first <= 0xDF && i + 1 < data.length) {
        let second = data[i + 1]
        if ((second & 0xC0) === 0x80) {
          chars.push(String.fromCharCode(((first & 0x1F) << 6) | (second & 0x3F)))
          i += 1
          continue
        }
      }
      if (first >= 0xE0 && first <= 0xEF && i + 2 < data.length) {
        let second = data[i + 1]
        let third = data[i + 2]
        if ((second & 0xC0) === 0x80 && (third & 0xC0) === 0x80) {
          chars.push(String.fromCharCode(((first & 0x0F) << 12) | ((second & 0x3F) << 6) | (third & 0x3F)))
          i += 2
          continue
        }
      }
      if (first >= 0xF0 && first <= 0xF4 && i + 3 < data.length) {
        let second = data[i + 1]
        let third = data[i + 2]
        let fourth = data[i + 3]
        if ((second & 0xC0) === 0x80 && (third & 0xC0) === 0x80 && (fourth & 0xC0) === 0x80) {
          let codePoint = ((first & 0x07) << 18) | ((second & 0x3F) << 12) | ((third & 0x3F) << 6) | (fourth & 0x3F)
          let adjusted = codePoint - 0x10000
          chars.push(String.fromCharCode(0xD800 + (adjusted >> 10)))
          chars.push(String.fromCharCode(0xDC00 + (adjusted & 0x3FF)))
          i += 3
          continue
        }
      }
      chars.push('\uFFFD')
    }
    return chars.join('')
  }

  private static cloneDefaultConfig(): FirewallPresetConfig {
    return {
      fixedPublicIp: DEFAULT_CONFIG.fixedPublicIp,
      privateCidrs: [],
      privateTcpPorts: [],
      privateUdpPorts: []
    }
  }
}
