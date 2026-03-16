import { netFirewall } from '@kit.NetworkKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'FirewallService'
const DOMAIN = 0x0001
const DEFAULT_USER_ID = 100
export type FirewallErrorKind = 'invalid_argument' | 'permission' | 'unknown'
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

export class FirewallService {
  private static lastErrorCode: number | undefined = undefined
  private static lastErrorMessage: string = ''
  private static lastErrorKind: FirewallErrorKind = 'unknown'

  static clearLastError(): void {
    FirewallService.lastErrorCode = undefined
    FirewallService.lastErrorMessage = ''
    FirewallService.lastErrorKind = 'unknown'
  }

  static getLastErrorText(): string {
    if (FirewallService.lastErrorMessage.length === 0) {
      return ''
    }
    if (FirewallService.lastErrorCode !== undefined) {
      return `${FirewallService.lastErrorMessage}（错误码 ${FirewallService.lastErrorCode}）`
    }
    return FirewallService.lastErrorMessage
  }

  static getLastErrorCode(): number | undefined {
    return FirewallService.lastErrorCode
  }

  static getLastErrorKind(): FirewallErrorKind {
    return FirewallService.lastErrorKind
  }

  private static recordError(action: string, err: Object): void {
    let code = FirewallService.extractErrorCode(err)
    let message = FirewallService.extractErrorMessage(err)
    FirewallService.lastErrorCode = code
    FirewallService.lastErrorKind = FirewallService.classifyError(code, message)
    FirewallService.lastErrorMessage = message.length > 0 ? message : `${action}失败`
  }

  private static extractErrorCode(err: Object): number | undefined {
    let codeValue = (err as Record<string, Object>)['code']
    if (typeof codeValue === 'number') {
      return codeValue
    }
    if (typeof codeValue === 'string') {
      let parsed = Number(codeValue)
      return Number.isNaN(parsed) ? undefined : parsed
    }
    return undefined
  }

  private static extractErrorMessage(err: Object): string {
    let messageValue = (err as Record<string, Object>)['message']
    if (typeof messageValue === 'string') {
      return messageValue
    }
    let dataValue = (err as Record<string, Object>)['data']
    if (typeof dataValue === 'string') {
      return dataValue
    }
    return ''
  }

  private static classifyError(code: number | undefined, message: string): FirewallErrorKind {
    let normalized = message.toLowerCase()
    if (normalized.includes('permission') ||
      normalized.includes('denied') ||
      normalized.includes('admin') ||
      normalized.includes('unauthorized') ||
      code === 9200001) {
      return 'permission'
    }
    if (normalized.includes('invalid') ||
      normalized.includes('argument') ||
      normalized.includes('param') ||
      normalized.includes('format') ||
      normalized.includes('value')) {
      return 'invalid_argument'
    }
    return 'unknown'
  }

  // 获取防火墙策略（含开关状态）
  static async getFirewallPolicy(): Promise<netFirewall.NetFirewallPolicy | null> {
    FirewallService.clearLastError()
    try {
      let policy = await netFirewall.getNetFirewallPolicy(DEFAULT_USER_ID)
      return policy
    } catch (err) {
      FirewallService.recordError('读取防火墙策略', err as Object)
      hilog.error(DOMAIN, TAG, `getFirewallPolicy failed: ${JSON.stringify(err)}`)
      return null
    }
  }

  // 获取防火墙开关状态
  static async getFirewallStatus(): Promise<boolean> {
    let policy = await FirewallService.getFirewallPolicy()
    return policy !== null ? policy.isOpen : false
  }

  // 启用/禁用防火墙
  static async setFirewallEnabled(enabled: boolean): Promise<boolean> {
    FirewallService.clearLastError()
    try {
      let policy: netFirewall.NetFirewallPolicy = {
        isOpen: enabled,
        inAction: netFirewall.FirewallRuleAction.RULE_ALLOW,
        outAction: netFirewall.FirewallRuleAction.RULE_ALLOW
      }
      await netFirewall.setNetFirewallPolicy(DEFAULT_USER_ID, policy)
      hilog.info(DOMAIN, TAG, `setFirewallEnabled: ${enabled}`)
      return true
    } catch (err) {
      FirewallService.recordError('设置防火墙状态', err as Object)
      hilog.error(DOMAIN, TAG, `setFirewallEnabled failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // 获取所有防火墙规则（分页获取全部）
  static async getAllRules(): Promise<netFirewall.NetFirewallRule[]> {
    FirewallService.clearLastError()
    try {
      let requestParam: netFirewall.RequestParam = {
        page: 1,
        pageSize: 50,
        orderField: netFirewall.NetFirewallOrderField.ORDER_BY_RULE_NAME,
        orderType: netFirewall.NetFirewallOrderType.ORDER_ASC
      }
      let result = await netFirewall.getNetFirewallRules(DEFAULT_USER_ID, requestParam)
      return result.data ?? []
    } catch (err) {
      FirewallService.recordError('读取防火墙规则', err as Object)
      hilog.error(DOMAIN, TAG, `getAllRules failed: ${JSON.stringify(err)}`)
      return []
    }
  }

  // 添加防火墙规则
  static async addRule(rule: netFirewall.NetFirewallRule): Promise<number> {
    FirewallService.clearLastError()
    try {
      let ruleId = await netFirewall.addNetFirewallRule(rule)
      hilog.info(DOMAIN, TAG, `addRule success, ruleId: ${ruleId}`)
      return ruleId
    } catch (err) {
      FirewallService.recordError('新增防火墙规则', err as Object)
      hilog.error(DOMAIN, TAG, `addRule failed: ${JSON.stringify(err)}`)
      return -1
    }
  }

  // 删除防火墙规则
  static async removeRule(ruleId: number): Promise<boolean> {
    FirewallService.clearLastError()
    try {
      await netFirewall.removeNetFirewallRule(DEFAULT_USER_ID, ruleId)
      hilog.info(DOMAIN, TAG, `removeRule success, ruleId: ${ruleId}`)
      return true
    } catch (err) {
      FirewallService.recordError('删除防火墙规则', err as Object)
      hilog.error(DOMAIN, TAG, `removeRule failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // 更新防火墙规则
  static async updateRule(rule: netFirewall.NetFirewallRule): Promise<boolean> {
    FirewallService.clearLastError()
    try {
      await netFirewall.updateNetFirewallRule(rule)
      hilog.info(DOMAIN, TAG, `updateRule success`)
      return true
    } catch (err) {
      FirewallService.recordError('更新防火墙规则', err as Object)
      hilog.error(DOMAIN, TAG, `updateRule failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static async replaceRule(oldRuleId: number, newRule: netFirewall.NetFirewallRule): Promise<number> {
    FirewallService.clearLastError()
    let removed = await FirewallService.removeRule(oldRuleId)
    if (!removed) {
      return -1
    }
    let newRuleId = await FirewallService.addRule(newRule)
    if (newRuleId > 0) {
      return newRuleId
    }
    hilog.error(DOMAIN, TAG, `replaceRule failed after removing old rule, oldRuleId=${oldRuleId}`)
    return -1
  }

  static findRuleConflict(
    existingRules: netFirewall.NetFirewallRule[],
    newRule: netFirewall.NetFirewallRule
  ): FirewallRuleConflictMatch | null {
    for (let i = 0; i < existingRules.length; i++) {
      let existingRule = existingRules[i]
      let kind = FirewallService.classifyRuleConflict(existingRule, newRule)
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
        let kind = FirewallService.classifyRuleConflict(rules[i], rules[j])
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

  private static classifyRuleConflict(
    existingRule: netFirewall.NetFirewallRule,
    newRule: netFirewall.NetFirewallRule
  ): FirewallRuleConflictKind {
    if (existingRule.type !== newRule.type || existingRule.direction !== newRule.direction) {
      return 'none'
    }
    let sameAction = existingRule.action === newRule.action
    if (FirewallService.isSameRuleKey(existingRule, newRule)) {
      return sameAction ? 'duplicate' : 'hard_conflict'
    }
    if (!sameAction && FirewallService.isOverlappingRule(existingRule, newRule)) {
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
        return FirewallService.isSameIpRuleKey(left, right)
      case netFirewall.NetFirewallRuleType.RULE_DOMAIN:
        return FirewallService.isSameDomainRuleKey(left, right)
      case netFirewall.NetFirewallRuleType.RULE_DNS:
        return FirewallService.isSameDnsRuleKey(left, right)
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
        return FirewallService.isIpRuleOverlap(left, right)
      case netFirewall.NetFirewallRuleType.RULE_DOMAIN:
        return FirewallService.isDomainRuleOverlap(left, right)
      default:
        return false
    }
  }

  private static isSameIpRuleKey(
    left: netFirewall.NetFirewallRule,
    right: netFirewall.NetFirewallRule
  ): boolean {
    let leftIp = FirewallService.normalizeIpRule(left)
    let rightIp = FirewallService.normalizeIpRule(right)
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
    let leftIp = FirewallService.normalizeIpRule(left)
    let rightIp = FirewallService.normalizeIpRule(right)
    if (!leftIp || !rightIp) {
      return false
    }
    return FirewallService.isProtocolOverlap(leftIp.protocol, rightIp.protocol) &&
      FirewallService.isRangeOverlap(leftIp.ip, rightIp.ip) &&
      FirewallService.isRangeOverlap(leftIp.port, rightIp.port)
  }

  private static isSameDomainRuleKey(
    left: netFirewall.NetFirewallRule,
    right: netFirewall.NetFirewallRule
  ): boolean {
    let leftPattern = FirewallService.normalizeDomainRule(left)
    let rightPattern = FirewallService.normalizeDomainRule(right)
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
    let leftPattern = FirewallService.normalizeDomainRule(left)
    let rightPattern = FirewallService.normalizeDomainRule(right)
    if (!leftPattern || !rightPattern) {
      return false
    }
    if (leftPattern.kind === 'exact' && rightPattern.kind === 'exact') {
      return false
    }
    if (leftPattern.kind === 'single_wildcard' && rightPattern.kind === 'exact') {
      return FirewallService.matchesSingleWildcard(leftPattern.suffix ?? '', rightPattern.normalized)
    }
    if (leftPattern.kind === 'exact' && rightPattern.kind === 'single_wildcard') {
      return FirewallService.matchesSingleWildcard(rightPattern.suffix ?? '', leftPattern.normalized)
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
    if (!ipParams || !ipParams.address) {
      return null
    }
    let ipRange = FirewallService.normalizeIpv4Range(ipParams.address, ipParams.mask)
    if (!ipRange) {
      return null
    }
    let normalizedRule: NormalizedIpRule = {
      protocol: rule.protocol ?? 0,
      ip: ipRange,
      port: FirewallService.normalizePortRange(rule)
    }
    return normalizedRule
  }

  private static normalizeIpv4Range(address: string, maskValue?: number): NormalizedIpRange | null {
    let ipValue = FirewallService.parseIpv4(address.trim())
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
    let port = rule.remotePorts?.[0]
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
    let normalized = FirewallService.normalizeDomain(domain)
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

  // 按规则类型统计数量
  static countByType(rules: netFirewall.NetFirewallRule[], type: netFirewall.NetFirewallRuleType): number {
    return rules.filter((r: netFirewall.NetFirewallRule) => r.type === type).length
  }

  // 按方向统计数量
  static countByDirection(rules: netFirewall.NetFirewallRule[], direction: netFirewall.NetFirewallRuleDirection): number {
    return rules.filter((r: netFirewall.NetFirewallRule) => r.direction === direction).length
  }
}
