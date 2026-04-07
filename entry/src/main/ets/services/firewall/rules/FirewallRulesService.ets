import { netFirewall } from '@kit.NetworkKit'

import { FirewallManagedRuleMetadata } from '../../../models/DataModels'
import { FirewallRepository } from '../repositories'

const RULE_METADATA_PREFIX = 'SECURITY_TOOL_META:'

export type FirewallRuleConflictKind = 'none' | 'duplicate' | 'hard_conflict' | 'overlap_conflict'

export interface FirewallRuleConflictMatch {
  kind: FirewallRuleConflictKind
  existingRule: netFirewall.NetFirewallRule
}

export interface FirewallConflictSummary {
  duplicates: number
  hardConflicts: number
  overlapConflicts: number
}

export class FirewallRulesService {
  static buildManagedRuleDescription(metadata: FirewallManagedRuleMetadata): string {
    return `${RULE_METADATA_PREFIX}${JSON.stringify(metadata)}`
  }

  static parseManagedRuleDescription(description?: string): FirewallManagedRuleMetadata | null {
    if (!description || !description.startsWith(RULE_METADATA_PREFIX)) {
      return null
    }
    try {
      let payload = JSON.parse(description.substring(RULE_METADATA_PREFIX.length)) as FirewallManagedRuleMetadata
      if (payload.owner !== 'security_tool') {
        return null
      }
      if (payload.mode !== 'public' && payload.mode !== 'private' && payload.mode !== 'custom') {
        return null
      }
      if (payload.kind !== 'preset' && payload.kind !== 'custom') {
        return null
      }
      return payload
    } catch (_err) {
      return null
    }
  }

  static applyManagedRuleMetadata(
    rule: netFirewall.NetFirewallRule,
    metadata: FirewallManagedRuleMetadata
  ): netFirewall.NetFirewallRule {
    let clonedRule = FirewallRepository.cloneRuleForCreate(rule)
    clonedRule.description = FirewallRulesService.buildManagedRuleDescription(metadata)
    return clonedRule
  }

  static findRuleConflict(
    existingRules: netFirewall.NetFirewallRule[],
    targetRule: netFirewall.NetFirewallRule,
    excludeRuleId?: number
  ): FirewallRuleConflictMatch | null {
    for (let i = 0; i < existingRules.length; i++) {
      let existingRule = existingRules[i]
      if (excludeRuleId !== undefined && FirewallRepository.getRulePrimaryKey(existingRule) === excludeRuleId) {
        continue
      }
      let kind = FirewallRulesService.classifyRuleConflict(existingRule, targetRule)
      if (kind !== 'none') {
        return { kind, existingRule }
      }
    }
    return null
  }

  static summarizeConflicts(rules: netFirewall.NetFirewallRule[]): FirewallConflictSummary {
    let summary: FirewallConflictSummary = {
      duplicates: 0,
      hardConflicts: 0,
      overlapConflicts: 0
    }
    for (let i = 0; i < rules.length; i++) {
      for (let j = i + 1; j < rules.length; j++) {
        let kind = FirewallRulesService.classifyRuleConflict(rules[i], rules[j])
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

  static countByType(rules: netFirewall.NetFirewallRule[], type: netFirewall.NetFirewallRuleType): number {
    return rules.filter((rule: netFirewall.NetFirewallRule) => rule.type === type).length
  }

  static countByDirection(
    rules: netFirewall.NetFirewallRule[],
    direction: netFirewall.NetFirewallRuleDirection
  ): number {
    return rules.filter((rule: netFirewall.NetFirewallRule) => rule.direction === direction).length
  }

  private static classifyRuleConflict(
    existingRule: netFirewall.NetFirewallRule,
    targetRule: netFirewall.NetFirewallRule
  ): FirewallRuleConflictKind {
    if (existingRule.type !== targetRule.type || existingRule.direction !== targetRule.direction) {
      return 'none'
    }
    let sameAction = existingRule.action === targetRule.action
    if (FirewallRulesService.isSameRuleKey(existingRule, targetRule)) {
      return sameAction ? 'duplicate' : 'hard_conflict'
    }
    if (!sameAction && FirewallRulesService.isOverlappingRule(existingRule, targetRule)) {
      return 'overlap_conflict'
    }
    return 'none'
  }

  private static isSameRuleKey(
    left: netFirewall.NetFirewallRule,
    right: netFirewall.NetFirewallRule
  ): boolean {
    switch (left.type) {
      case netFirewall.NetFirewallRuleType.RULE_IP:
        return FirewallRulesService.isSameIpRuleKey(left, right)
      case netFirewall.NetFirewallRuleType.RULE_DOMAIN:
        return FirewallRulesService.isSameDomainRuleKey(left, right)
      case netFirewall.NetFirewallRuleType.RULE_DNS:
        return FirewallRulesService.isSameDnsRuleKey(left, right)
      default:
        return false
    }
  }

  private static isOverlappingRule(
    left: netFirewall.NetFirewallRule,
    right: netFirewall.NetFirewallRule
  ): boolean {
    switch (left.type) {
      case netFirewall.NetFirewallRuleType.RULE_IP:
        return FirewallRulesService.isIpRuleOverlap(left, right)
      case netFirewall.NetFirewallRuleType.RULE_DOMAIN:
        return FirewallRulesService.isDomainRuleOverlap(left, right)
      default:
        return false
    }
  }

  private static isSameIpRuleKey(
    left: netFirewall.NetFirewallRule,
    right: netFirewall.NetFirewallRule
  ): boolean {
    let leftIp = FirewallRulesService.normalizeIpRule(left)
    let rightIp = FirewallRulesService.normalizeIpRule(right)
    if (!leftIp || !rightIp) {
      return false
    }
    return leftIp.protocol === rightIp.protocol &&
      leftIp.ip.start === rightIp.ip.start &&
      leftIp.ip.end === rightIp.ip.end &&
      leftIp.port.start === rightIp.port.start &&
      leftIp.port.end === rightIp.port.end
  }

  private static isIpRuleOverlap(
    left: netFirewall.NetFirewallRule,
    right: netFirewall.NetFirewallRule
  ): boolean {
    let leftIp = FirewallRulesService.normalizeIpRule(left)
    let rightIp = FirewallRulesService.normalizeIpRule(right)
    if (!leftIp || !rightIp) {
      return false
    }
    return FirewallRulesService.isProtocolOverlap(leftIp.protocol, rightIp.protocol) &&
      FirewallRulesService.isRangeOverlap(leftIp.ip, rightIp.ip) &&
      FirewallRulesService.isRangeOverlap(leftIp.port, rightIp.port)
  }

  private static isSameDomainRuleKey(
    left: netFirewall.NetFirewallRule,
    right: netFirewall.NetFirewallRule
  ): boolean {
    let leftPattern = FirewallRulesService.normalizeDomainRule(left)
    let rightPattern = FirewallRulesService.normalizeDomainRule(right)
    if (!leftPattern || !rightPattern) {
      return false
    }
    return leftPattern.kind === rightPattern.kind &&
      leftPattern.normalized === rightPattern.normalized &&
      leftPattern.suffix === rightPattern.suffix
  }

  private static isDomainRuleOverlap(
    left: netFirewall.NetFirewallRule,
    right: netFirewall.NetFirewallRule
  ): boolean {
    let leftPattern = FirewallRulesService.normalizeDomainRule(left)
    let rightPattern = FirewallRulesService.normalizeDomainRule(right)
    if (!leftPattern || !rightPattern) {
      return false
    }
    if (leftPattern.kind === 'exact' && rightPattern.kind === 'exact') {
      return false
    }
    if (leftPattern.kind === 'single_wildcard' && rightPattern.kind === 'exact') {
      return FirewallRulesService.matchesSingleWildcard(leftPattern.suffix ?? '', rightPattern.normalized)
    }
    if (leftPattern.kind === 'exact' && rightPattern.kind === 'single_wildcard') {
      return FirewallRulesService.matchesSingleWildcard(rightPattern.suffix ?? '', leftPattern.normalized)
    }
    return false
  }

  private static isSameDnsRuleKey(
    left: netFirewall.NetFirewallRule,
    right: netFirewall.NetFirewallRule
  ): boolean {
    let leftDns = left.dns?.primaryDns?.trim().toLowerCase() ?? ''
    let rightDns = right.dns?.primaryDns?.trim().toLowerCase() ?? ''
    return leftDns.length > 0 && leftDns === rightDns
  }

  private static normalizeIpRule(rule: netFirewall.NetFirewallRule): NormalizedIpRule | null {
    let ipParams = rule.remoteIps?.[0]
    if (!ipParams) {
      return null
    }
    let ipRange = FirewallRulesService.normalizeIpParamRange(ipParams)
    if (!ipRange) {
      return null
    }
    return {
      protocol: rule.protocol ?? 0,
      ip: ipRange,
      port: FirewallRulesService.normalizePortRange(rule)
    }
  }

  private static normalizeIpParamRange(ipParam: netFirewall.NetFirewallIpParams): NormalizedIpRange | null {
    if (ipParam.startIp && ipParam.endIp) {
      let startIp = FirewallRulesService.parseIpv4(ipParam.startIp.trim())
      let endIp = FirewallRulesService.parseIpv4(ipParam.endIp.trim())
      if (startIp === null || endIp === null || startIp > endIp) {
        return null
      }
      return {
        start: startIp,
        end: endIp
      }
    }
    if (!ipParam.address) {
      return null
    }
    return FirewallRulesService.normalizeIpv4Range(ipParam.address, ipParam.mask)
  }

  private static normalizeIpv4Range(address: string, maskValue?: number): NormalizedIpRange | null {
    let ipValue = FirewallRulesService.parseIpv4(address.trim())
    if (ipValue === null) {
      return null
    }
    let mask = maskValue === undefined ? 32 : maskValue
    if (mask < 0 || mask > 32) {
      return null
    }
    if (mask === 0) {
      return { start: 0, end: 0xFFFFFFFF }
    }
    let hostBits = 32 - mask
    let blockSize = Math.pow(2, hostBits)
    let start = Math.floor(ipValue / blockSize) * blockSize
    return {
      start,
      end: start + blockSize - 1
    }
  }

  private static parseIpv4(address: string): number | null {
    let segments = address.split('.')
    if (segments.length !== 4) {
      return null
    }
    let result = 0
    for (let i = 0; i < 4; i++) {
      if (!/^\d+$/.test(segments[i])) {
        return null
      }
      let value = Number(segments[i])
      if (value < 0 || value > 255) {
        return null
      }
      result = result * 256 + value
    }
    return result
  }

  private static normalizePortRange(rule: netFirewall.NetFirewallRule): NormalizedPortRange {
    let port = rule.localPorts?.[0] ?? rule.remotePorts?.[0]
    if (!port) {
      return { start: 0, end: 65535 }
    }
    return {
      start: port.startPort ?? 0,
      end: port.endPort ?? port.startPort ?? 65535
    }
  }

  private static isProtocolOverlap(leftProtocol: number, rightProtocol: number): boolean {
    return leftProtocol === 0 || rightProtocol === 0 || leftProtocol === rightProtocol
  }

  private static isRangeOverlap(left: NormalizedIpRange | NormalizedPortRange, right: NormalizedIpRange | NormalizedPortRange): boolean {
    return Math.max(left.start, right.start) <= Math.min(left.end, right.end)
  }

  private static normalizeDomainRule(rule: netFirewall.NetFirewallRule): NormalizedDomainPattern | null {
    let domain = rule.domains?.[0]?.domain
    if (!domain) {
      return null
    }
    let normalized = FirewallRulesService.normalizeDomain(domain)
    if (normalized.length === 0) {
      return null
    }
    if (normalized.startsWith('*.')) {
      let suffix = normalized.substring(2)
      if (suffix.length === 0) {
        return null
      }
      return {
        raw: domain,
        kind: 'single_wildcard',
        normalized,
        suffix
      }
    }
    return {
      raw: domain,
      kind: 'exact',
      normalized
    }
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
  port: NormalizedPortRange
}

interface NormalizedDomainPattern {
  raw: string
  kind: 'exact' | 'single_wildcard'
  normalized: string
  suffix?: string
}
