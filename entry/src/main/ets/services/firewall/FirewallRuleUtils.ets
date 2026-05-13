import { netFirewall } from '@kit.NetworkKit'
import { FirewallRuleValidationErrorStrings } from '../../constants/modules/FirewallErrorStrings'
import { Ipv4Utils } from '../../utils/Ipv4Utils'
import {
  FirewallConflictSummary,
  FirewallRuleDeployment,
  FirewallRuleConflictKind,
  FirewallRuleConflictMatch,
  FirewallRuleIntent,
  FirewallRuleIntentInput,
  FirewallRuleDisplayItem,
  FirewallRuleValidationResult,
  FirewallScopedRule,
  FIREWALL_IPV4_FAMILY,
  FIREWALL_IPV4_MASK_MAX,
  FIREWALL_IPV4_MASK_MIN,
  FIREWALL_IPV4_PARAM_TYPE,
  FIREWALL_IPV4_RANGE_PARAM_TYPE,
  FIREWALL_PORT_MAX,
  FIREWALL_PORT_MIN,
  normalizeFirewallRuleUserIds
} from './FirewallModels'

export class FirewallRuleUtils {
  static formatIpParamsForDisplay(params?: netFirewall.NetFirewallIpParams[]): string {
    if (!params || params.length === 0) {
      return ''
    }
    let ip = params[0]
    if (typeof ip.startIp === 'string' && typeof ip.endIp === 'string' &&
      ip.startIp.trim().length > 0 && ip.endIp.trim().length > 0) {
      return `${ip.startIp.trim()}-${ip.endIp.trim()}`
    }
    if (typeof ip.address !== 'string' || ip.address.trim().length === 0) {
      return ''
    }
    let address = ip.address.trim()
    let mask = FirewallRuleUtils.normalizeNumber(ip.mask)
    return mask === undefined || mask >= FIREWALL_IPV4_MASK_MAX ? address : `${address}/${mask}`
  }

  static formatPortParamsForDisplay(params?: netFirewall.NetFirewallPortParams[]): string {
    let normalized = FirewallRuleUtils.clonePortParams(params)
    if (!normalized || normalized.length === 0) {
      return ''
    }
    return normalized.map((port: netFirewall.NetFirewallPortParams): string => {
      let startPort = port.startPort ?? 0
      let endPort = port.endPort ?? startPort
      return startPort === endPort ? `${startPort}` : `${startPort}-${endPort}`
    }).join(',')
  }

  static buildSystemRuleFromIntent(intent: FirewallRuleIntent, userId: number): netFirewall.NetFirewallRule {
    let rule: netFirewall.NetFirewallRule = {
      userId: userId,
      name: intent.name,
      direction: intent.direction as netFirewall.NetFirewallRuleDirection,
      action: intent.action as netFirewall.FirewallRuleAction,
      type: intent.type as netFirewall.NetFirewallRuleType,
      isEnabled: intent.isEnabled
    }
    FirewallRuleUtils.copyRuleFieldsFromIntent(rule, intent)
    return rule
  }

  static normalizeRuleForCreate(rule: netFirewall.NetFirewallRule): netFirewall.NetFirewallRule {
    let normalizedRule = FirewallRuleUtils.cloneSystemRule(rule)
    if (normalizedRule.type === netFirewall.NetFirewallRuleType.RULE_IP) {
      let remoteIps = FirewallRuleUtils.normalizeCreateIpParams(rule.remoteIps)
      if (remoteIps !== undefined) {
        normalizedRule.remoteIps = remoteIps
      }
      let localIps = FirewallRuleUtils.normalizeCreateIpParams(rule.localIps)
      if (localIps !== undefined) {
        normalizedRule.localIps = localIps
      }
    }
    return normalizedRule
  }

  static validateRuleIntentInput(input: FirewallRuleIntentInput): FirewallRuleValidationResult {
    if (input.name.trim().length === 0) {
      return { success: false, errorMessage: FirewallRuleValidationErrorStrings.RULE_NAME_REQUIRED }
    }
    if (FirewallRuleUtils.normalizeUserIds(input.targetUserIds).length === 0) {
      return { success: false, errorMessage: FirewallRuleValidationErrorStrings.TARGET_USERS_REQUIRED }
    }
    if (input.type === netFirewall.NetFirewallRuleType.RULE_DOMAIN && !input.domains?.[0]) {
      return { success: false, errorMessage: FirewallRuleValidationErrorStrings.DOMAIN_REQUIRED }
    }
    if (input.type === netFirewall.NetFirewallRuleType.RULE_DNS && !input.dns?.primaryDns) {
      return { success: false, errorMessage: FirewallRuleValidationErrorStrings.DNS_REQUIRED }
    }
    return { success: true }
  }

  static normalizeUserIds(userIds: number[]): number[] {
    return normalizeFirewallRuleUserIds(userIds)
  }

  static findRuleConflict(
    existingIntents: FirewallRuleIntent[],
    targetIntent: FirewallRuleIntent,
    excludeLocalRuleId?: string
  ): FirewallRuleConflictMatch | null {
    for (let i = 0; i < existingIntents.length; i++) {
      let existingIntent = existingIntents[i]
      if (excludeLocalRuleId !== undefined && existingIntent.localRuleId === excludeLocalRuleId) {
        continue
      }
      let kind = FirewallRuleUtils.classifyRuleConflict(existingIntent, targetIntent)
      if (kind !== 'none') {
        return { kind: kind, existingRule: existingIntent }
      }
    }
    return null
  }

  static summarizeConflicts(intents: FirewallRuleIntent[]): FirewallConflictSummary {
    let summary: FirewallConflictSummary = {
      duplicates: 0,
      hardConflicts: 0,
      overlapConflicts: 0
    }
    for (let i = 0; i < intents.length; i++) {
      for (let j = i + 1; j < intents.length; j++) {
        let kind = FirewallRuleUtils.classifyRuleConflict(intents[i], intents[j])
        if (kind === 'duplicate') {
          summary.duplicates++
        } else if (kind === 'hard_conflict') {
          summary.hardConflicts++
        } else if (kind === 'overlap_conflict') {
          summary.overlapConflicts++
        }
      }
    }
    return summary
  }

  static buildIntentFromInput(
    localRuleId: string,
    input: FirewallRuleIntentInput,
    now: number,
    createdAt?: number
  ): FirewallRuleIntent {
    return {
      localRuleId: localRuleId,
      name: input.name.trim(),
      type: input.type,
      direction: input.direction,
      action: input.action,
      isEnabled: input.isEnabled ?? true,
      targetUserIds: FirewallRuleUtils.normalizeUserIds(input.targetUserIds),
      protocol: FirewallRuleUtils.normalizeNumber(input.protocol),
      remoteIps: FirewallRuleUtils.cloneIpParams(input.remoteIps),
      localIps: FirewallRuleUtils.cloneIpParams(input.localIps),
      localPorts: FirewallRuleUtils.clonePortParams(input.localPorts),
      remotePorts: FirewallRuleUtils.clonePortParams(input.remotePorts),
      domains: FirewallRuleUtils.cloneDomainParams(input.domains),
      dns: FirewallRuleUtils.cloneDnsParams(input.dns),
      createdAt: createdAt ?? now,
      updatedAt: now
    }
  }

  static buildIntentInputFromRule(rule: netFirewall.NetFirewallRule, targetUserIds: number[]): FirewallRuleIntentInput {
    let localRuleId = (rule as FirewallScopedRule).localRuleId
    return {
      localRuleId: localRuleId,
      name: rule.name ?? '',
      type: rule.type,
      direction: rule.direction,
      action: rule.action,
      isEnabled: rule.isEnabled ?? true,
      targetUserIds: FirewallRuleUtils.normalizeUserIds(targetUserIds),
      protocol: FirewallRuleUtils.normalizeNumber(rule.protocol),
      remoteIps: FirewallRuleUtils.cloneIpParams(rule.remoteIps),
      localIps: FirewallRuleUtils.cloneIpParams(rule.localIps),
      localPorts: FirewallRuleUtils.clonePortParams(rule.localPorts),
      remotePorts: FirewallRuleUtils.clonePortParams(rule.remotePorts),
      domains: FirewallRuleUtils.cloneDomainParams(rule.domains),
      dns: FirewallRuleUtils.cloneDnsParams(rule.dns)
    }
  }

  static cloneSystemRule(rule: netFirewall.NetFirewallRule): netFirewall.NetFirewallRule {
    let clonedRule: netFirewall.NetFirewallRule = {
      userId: FirewallRuleUtils.normalizeNumber(rule.userId) ?? 0,
      name: rule.name,
      direction: rule.direction,
      action: rule.action,
      type: rule.type,
      isEnabled: rule.isEnabled
    }
    let appUid = FirewallRuleUtils.normalizeNumber(rule.appUid)
    if (appUid !== undefined) {
      clonedRule.appUid = appUid
    }
    FirewallRuleUtils.copyRuleFields(clonedRule, rule)
    return clonedRule
  }

  static cloneDisplayRuleFromIntent(
    intent: FirewallRuleIntent,
    deployments: FirewallRuleDeployment[] = []
  ): FirewallRuleDisplayItem {
    let rule = FirewallRuleUtils.buildSystemRuleFromIntent(intent, intent.targetUserIds[0] ?? 0) as FirewallScopedRule
    rule.localRuleId = intent.localRuleId
    rule.targetUserIds = FirewallRuleUtils.normalizeUserIds(intent.targetUserIds)
    rule.deployments = deployments
    rule.createdAt = intent.createdAt
    rule.updatedAt = intent.updatedAt
    return rule as FirewallRuleDisplayItem
  }

  private static copyRuleFieldsFromIntent(rule: netFirewall.NetFirewallRule, intent: FirewallRuleIntent): void {
    let protocol = FirewallRuleUtils.normalizeNumber(intent.protocol)
    if (protocol !== undefined) {
      rule.protocol = protocol
    }
    let remoteIps = FirewallRuleUtils.cloneIpParams(intent.remoteIps)
    if (remoteIps !== undefined) {
      rule.remoteIps = remoteIps
    }
    let localIps = FirewallRuleUtils.cloneIpParams(intent.localIps)
    if (localIps !== undefined) {
      rule.localIps = localIps
    }
    let localPorts = FirewallRuleUtils.clonePortParams(intent.localPorts)
    if (localPorts !== undefined) {
      rule.localPorts = localPorts
    }
    let remotePorts = FirewallRuleUtils.clonePortParams(intent.remotePorts)
    if (remotePorts !== undefined) {
      rule.remotePorts = remotePorts
    }
    let domains = FirewallRuleUtils.cloneDomainParams(intent.domains)
    if (domains !== undefined) {
      rule.domains = domains
    }
    let dns = FirewallRuleUtils.cloneDnsParams(intent.dns)
    if (dns !== undefined) {
      rule.dns = dns
    }
  }

  private static copyRuleFields(target: netFirewall.NetFirewallRule, source: netFirewall.NetFirewallRule): void {
    let protocol = FirewallRuleUtils.normalizeNumber(source.protocol)
    if (protocol !== undefined) {
      target.protocol = protocol
    }
    let remoteIps = FirewallRuleUtils.cloneIpParams(source.remoteIps)
    if (remoteIps !== undefined) {
      target.remoteIps = remoteIps
    }
    let localIps = FirewallRuleUtils.cloneIpParams(source.localIps)
    if (localIps !== undefined) {
      target.localIps = localIps
    }
    let localPorts = FirewallRuleUtils.clonePortParams(source.localPorts)
    if (localPorts !== undefined) {
      target.localPorts = localPorts
    }
    let remotePorts = FirewallRuleUtils.clonePortParams(source.remotePorts)
    if (remotePorts !== undefined) {
      target.remotePorts = remotePorts
    }
    let domains = FirewallRuleUtils.cloneDomainParams(source.domains)
    if (domains !== undefined) {
      target.domains = domains
    }
    let dns = FirewallRuleUtils.cloneDnsParams(source.dns)
    if (dns !== undefined) {
      target.dns = dns
    }
  }

  private static classifyRuleConflict(left: FirewallRuleIntent, right: FirewallRuleIntent): FirewallRuleConflictKind {
    if (!FirewallRuleUtils.hasUserScopeIntersection(left, right)) {
      return 'none'
    }
    if (left.type !== right.type || left.direction !== right.direction) {
      return 'none'
    }
    let sameAction = left.action === right.action
    if (FirewallRuleUtils.isSameRuleKey(left, right)) {
      return sameAction ? 'duplicate' : 'hard_conflict'
    }
    if (!sameAction && FirewallRuleUtils.isOverlappingRule(left, right)) {
      return 'overlap_conflict'
    }
    return 'none'
  }

  private static hasUserScopeIntersection(left: FirewallRuleIntent, right: FirewallRuleIntent): boolean {
    let rightUserSet = new Set<number>(right.targetUserIds)
    return left.targetUserIds.some((userId: number): boolean => rightUserSet.has(userId))
  }

  private static isSameRuleKey(left: FirewallRuleIntent, right: FirewallRuleIntent): boolean {
    switch (left.type) {
      case netFirewall.NetFirewallRuleType.RULE_IP:
        return FirewallRuleUtils.isSameIpRuleKey(left, right)
      case netFirewall.NetFirewallRuleType.RULE_DOMAIN:
        return FirewallRuleUtils.isSameDomainRuleKey(left, right)
      case netFirewall.NetFirewallRuleType.RULE_DNS:
        return FirewallRuleUtils.isSameDnsRuleKey(left, right)
      default:
        return false
    }
  }

  private static isOverlappingRule(left: FirewallRuleIntent, right: FirewallRuleIntent): boolean {
    switch (left.type) {
      case netFirewall.NetFirewallRuleType.RULE_IP:
        return FirewallRuleUtils.isIpRuleOverlap(left, right)
      case netFirewall.NetFirewallRuleType.RULE_DOMAIN:
        return FirewallRuleUtils.isDomainRuleOverlap(left, right)
      default:
        return false
    }
  }

  private static isSameIpRuleKey(left: FirewallRuleIntent, right: FirewallRuleIntent): boolean {
    let leftIp = FirewallRuleUtils.normalizeIpRule(left)
    let rightIp = FirewallRuleUtils.normalizeIpRule(right)
    if (!leftIp || !rightIp) {
      return false
    }
    if (!(leftIp.protocol === rightIp.protocol &&
      leftIp.ip.start === rightIp.ip.start &&
      leftIp.ip.end === rightIp.ip.end &&
      leftIp.ports.length === rightIp.ports.length)) {
      return false
    }
    for (let i = 0; i < leftIp.ports.length; i++) {
      if (leftIp.ports[i].start !== rightIp.ports[i].start || leftIp.ports[i].end !== rightIp.ports[i].end) {
        return false
      }
    }
    return true
  }

  private static isIpRuleOverlap(left: FirewallRuleIntent, right: FirewallRuleIntent): boolean {
    let leftIp = FirewallRuleUtils.normalizeIpRule(left)
    let rightIp = FirewallRuleUtils.normalizeIpRule(right)
    if (!leftIp || !rightIp) {
      return false
    }
    if (!FirewallRuleUtils.isProtocolOverlap(leftIp.protocol, rightIp.protocol) ||
      !FirewallRuleUtils.isRangeOverlap(leftIp.ip, rightIp.ip)) {
      return false
    }
    for (let i = 0; i < leftIp.ports.length; i++) {
      for (let j = 0; j < rightIp.ports.length; j++) {
        if (FirewallRuleUtils.isRangeOverlap(leftIp.ports[i], rightIp.ports[j])) {
          return true
        }
      }
    }
    return false
  }

  private static isSameDomainRuleKey(left: FirewallRuleIntent, right: FirewallRuleIntent): boolean {
    let leftPattern = FirewallRuleUtils.normalizeDomainRule(left)
    let rightPattern = FirewallRuleUtils.normalizeDomainRule(right)
    if (!leftPattern || !rightPattern) {
      return false
    }
    return leftPattern.kind === rightPattern.kind &&
      leftPattern.normalized === rightPattern.normalized &&
      leftPattern.suffix === rightPattern.suffix
  }

  private static isDomainRuleOverlap(left: FirewallRuleIntent, right: FirewallRuleIntent): boolean {
    let leftPattern = FirewallRuleUtils.normalizeDomainRule(left)
    let rightPattern = FirewallRuleUtils.normalizeDomainRule(right)
    if (!leftPattern || !rightPattern) {
      return false
    }
    if (leftPattern.kind === 'exact' && rightPattern.kind === 'exact') {
      return false
    }
    if (leftPattern.kind === 'single_wildcard' && rightPattern.kind === 'exact') {
      return FirewallRuleUtils.matchesSingleWildcard(leftPattern.suffix ?? '', rightPattern.normalized)
    }
    if (leftPattern.kind === 'exact' && rightPattern.kind === 'single_wildcard') {
      return FirewallRuleUtils.matchesSingleWildcard(rightPattern.suffix ?? '', leftPattern.normalized)
    }
    return false
  }

  private static isSameDnsRuleKey(left: FirewallRuleIntent, right: FirewallRuleIntent): boolean {
    let leftDns = left.dns?.primaryDns?.trim().toLowerCase() ?? ''
    let rightDns = right.dns?.primaryDns?.trim().toLowerCase() ?? ''
    return leftDns.length > 0 && leftDns === rightDns
  }

  private static normalizeIpRule(intent: FirewallRuleIntent): NormalizedIpRule | null {
    let activeIps = intent.direction === netFirewall.NetFirewallRuleDirection.RULE_IN ? intent.localIps : intent.remoteIps
    let ipParams = activeIps?.[0]
    let anyIpRange: NormalizedIpRange = { start: 0, end: 0xFFFFFFFF }
    let ipRange = ipParams ? FirewallRuleUtils.normalizeIpParamRange(ipParams) : anyIpRange
    if (!ipRange) {
      return null
    }
    return {
      protocol: intent.protocol ?? 0,
      ip: ipRange,
      ports: FirewallRuleUtils.normalizePortRange(intent)
    }
  }

  private static normalizeIpParamRange(ipParam: netFirewall.NetFirewallIpParams): NormalizedIpRange | null {
    if (ipParam.startIp && ipParam.endIp) {
      let startIp = Ipv4Utils.parseIpv4(ipParam.startIp.trim())
      let endIp = Ipv4Utils.parseIpv4(ipParam.endIp.trim())
      if (startIp === null || endIp === null || startIp > endIp) {
        return null
      }
      return { start: startIp, end: endIp }
    }
    if (!ipParam.address) {
      return null
    }
    return FirewallRuleUtils.normalizeIpv4Range(ipParam.address, ipParam.mask)
  }

  private static normalizeIpv4Range(address: string, maskValue?: number): NormalizedIpRange | null {
    let ipValue = Ipv4Utils.parseIpv4(address.trim())
    if (ipValue === null) {
      return null
    }
    let mask = maskValue === undefined ? FIREWALL_IPV4_MASK_MAX : maskValue
    if (mask < FIREWALL_IPV4_MASK_MIN || mask > FIREWALL_IPV4_MASK_MAX) {
      return null
    }
    if (mask === FIREWALL_IPV4_MASK_MIN) {
      return { start: 0, end: 0xFFFFFFFF }
    }
    let hostBits = FIREWALL_IPV4_MASK_MAX - mask
    let blockSize = Math.pow(2, hostBits)
    let start = Math.floor(ipValue / blockSize) * blockSize
    return { start: start, end: start + blockSize - 1 }
  }

  private static normalizePortRange(intent: FirewallRuleIntent): NormalizedPortRange[] {
    let sourcePorts = intent.direction === netFirewall.NetFirewallRuleDirection.RULE_IN ? intent.localPorts : intent.remotePorts
    let normalizedPorts = FirewallRuleUtils.clonePortParams(sourcePorts)
    if (!normalizedPorts || normalizedPorts.length === 0) {
      return [{ start: 0, end: FIREWALL_PORT_MAX }]
    }
    return normalizedPorts.map((port: netFirewall.NetFirewallPortParams): NormalizedPortRange => {
      return {
        start: port.startPort ?? 0,
        end: port.endPort ?? port.startPort ?? FIREWALL_PORT_MAX
      }
    })
  }

  private static normalizeDomainRule(intent: FirewallRuleIntent): NormalizedDomainPattern | null {
    let domain = intent.domains?.[0]?.domain
    if (!domain) {
      return null
    }
    let normalized = FirewallRuleUtils.normalizeDomain(domain)
    if (normalized.length === 0) {
      return null
    }
    if (normalized.startsWith('*.')) {
      return { kind: 'single_wildcard', normalized: normalized, suffix: normalized.substring(2) }
    }
    return { kind: 'exact', normalized: normalized }
  }

  private static normalizeDomain(domain: string): string {
    let normalized = domain.trim().toLowerCase()
    while (normalized.endsWith('.')) {
      normalized = normalized.substring(0, normalized.length - 1)
    }
    return normalized
  }

  private static matchesSingleWildcard(suffix: string, exactDomain: string): boolean {
    let dotSuffix = `.${suffix}`
    if (!exactDomain.endsWith(dotSuffix)) {
      return false
    }
    let prefix = exactDomain.substring(0, exactDomain.length - dotSuffix.length)
    return prefix.length > 0 && !prefix.includes('.')
  }

  private static isProtocolOverlap(leftProtocol: number, rightProtocol: number): boolean {
    return leftProtocol === 0 || rightProtocol === 0 || leftProtocol === rightProtocol
  }

  private static isRangeOverlap(left: NormalizedIpRange | NormalizedPortRange, right: NormalizedIpRange | NormalizedPortRange): boolean {
    return Math.max(left.start, right.start) <= Math.min(left.end, right.end)
  }

  private static normalizeCreateIpParams(source?: netFirewall.NetFirewallIpParams[]): netFirewall.NetFirewallIpParams[] | undefined {
    if (!source || source.length === 0) {
      return undefined
    }
    let result: netFirewall.NetFirewallIpParams[] = []
    source.forEach((item: netFirewall.NetFirewallIpParams) => {
      if (item.address === '0.0.0.0' && (item.mask ?? 0) === 0) {
        return
      }
      let cloned = FirewallRuleUtils.cloneIpParams([item])?.[0]
      if (cloned) {
        result.push(cloned)
      }
    })
    return result.length > 0 ? result : undefined
  }

  private static cloneIpParams(source?: netFirewall.NetFirewallIpParams[]): netFirewall.NetFirewallIpParams[] | undefined {
    if (!source || source.length === 0) {
      return undefined
    }
    let result: netFirewall.NetFirewallIpParams[] = []
    source.forEach((item: netFirewall.NetFirewallIpParams) => {
      let family = FirewallRuleUtils.normalizeNumber(item.family) ?? FIREWALL_IPV4_FAMILY
      if (item.type === FIREWALL_IPV4_RANGE_PARAM_TYPE || (item.startIp !== undefined && item.endIp !== undefined)) {
        if (item.startIp !== undefined && item.endIp !== undefined) {
          result.push({ type: FIREWALL_IPV4_RANGE_PARAM_TYPE, family: family, startIp: item.startIp, endIp: item.endIp })
        }
        return
      }
      let mask = FirewallRuleUtils.normalizeNumber(item.mask)
      if (item.address !== undefined && mask !== undefined) {
        result.push({ type: FIREWALL_IPV4_PARAM_TYPE, family: family, address: item.address, mask: mask })
      }
    })
    return result.length > 0 ? result : undefined
  }

  private static clonePortParams(source?: netFirewall.NetFirewallPortParams[]): netFirewall.NetFirewallPortParams[] | undefined {
    if (!source || source.length === 0) {
      return undefined
    }
    let result: netFirewall.NetFirewallPortParams[] = []
    source.forEach((item: netFirewall.NetFirewallPortParams) => {
      let startPort = FirewallRuleUtils.normalizeNumber(item.startPort)
      let endPort = FirewallRuleUtils.normalizeNumber(item.endPort)
      if (startPort === undefined && endPort === undefined) {
        return
      }
      let resolvedStartPort = startPort ?? endPort ?? FIREWALL_PORT_MIN
      let resolvedEndPort = endPort ?? startPort ?? resolvedStartPort
      result.push({ startPort: resolvedStartPort, endPort: resolvedEndPort })
    })
    if (result.length === 0) {
      return undefined
    }
    result.sort((left: netFirewall.NetFirewallPortParams, right: netFirewall.NetFirewallPortParams): number => {
      let startDiff = (left.startPort ?? 0) - (right.startPort ?? 0)
      if (startDiff !== 0) {
        return startDiff
      }
      return (left.endPort ?? left.startPort ?? 0) - (right.endPort ?? right.startPort ?? 0)
    })
    let deduped: netFirewall.NetFirewallPortParams[] = []
    result.forEach((item: netFirewall.NetFirewallPortParams) => {
      let previous = deduped[deduped.length - 1]
      if (previous &&
        previous.startPort === item.startPort &&
        previous.endPort === item.endPort) {
        return
      }
      deduped.push(item)
    })
    return deduped
  }

  private static cloneDomainParams(source?: netFirewall.NetFirewallDomainParams[]): netFirewall.NetFirewallDomainParams[] | undefined {
    if (!source || source.length === 0) {
      return undefined
    }
    return source.map((item: netFirewall.NetFirewallDomainParams): netFirewall.NetFirewallDomainParams => {
      return { domain: item.domain, isWildcard: item.isWildcard }
    })
  }

  private static cloneDnsParams(source?: netFirewall.NetFirewallDnsParams): netFirewall.NetFirewallDnsParams | undefined {
    if (!source || typeof source.primaryDns !== 'string' || source.primaryDns.trim().length === 0) {
      return undefined
    }
    let result: netFirewall.NetFirewallDnsParams = { primaryDns: source.primaryDns }
    if (typeof source.standbyDns === 'string' && source.standbyDns.trim().length > 0) {
      result.standbyDns = source.standbyDns
    }
    return result
  }

  private static normalizeNumber(value?: number): number | undefined {
    if (value !== undefined && Number.isFinite(value)) {
      return value
    }
    return undefined
  }
}

interface NormalizedIpRange {
  start: number
  end: number
}

interface NormalizedPortRange {
  start: number
  end: number
}

interface NormalizedIpRule {
  protocol: number
  ip: NormalizedIpRange
  ports: NormalizedPortRange[]
}

interface NormalizedDomainPattern {
  kind: 'exact' | 'single_wildcard'
  normalized: string
  suffix?: string
}
