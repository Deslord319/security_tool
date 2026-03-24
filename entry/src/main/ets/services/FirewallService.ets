import { netFirewall } from '@kit.NetworkKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { FirewallManagedRuleMetadata, FirewallPresetMode } from '../models/DataModels'

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

interface FirewallRuleLogPayload {
  primaryKey?: number
  name?: string
  description?: string
  type?: netFirewall.NetFirewallRuleType
  direction?: netFirewall.NetFirewallRuleDirection
  action?: netFirewall.FirewallRuleAction
  userId?: number
  appUidType?: string
  isEnabled?: boolean
  protocol?: number
  localIps?: netFirewall.NetFirewallIpParams[]
  remoteIps?: netFirewall.NetFirewallIpParams[]
  localPorts?: netFirewall.NetFirewallPortParams[]
  remotePorts?: netFirewall.NetFirewallPortParams[]
  domains?: netFirewall.NetFirewallDomainParams[]
  dns?: netFirewall.NetFirewallDnsParams
  dnsStandbyState?: string
}

interface FirewallRuleWithKey extends netFirewall.NetFirewallRule {
  id?: number
  ruleId?: number
}

const RULE_METADATA_PREFIX = 'SECURITY_TOOL_META:'

export class FirewallService {
  private static lastErrorCode: number | undefined = undefined
  private static lastErrorMessage: string = ''
  private static lastErrorKind: FirewallErrorKind = 'unknown'

  static normalizeRuleForCreate(rule: netFirewall.NetFirewallRule): netFirewall.NetFirewallRule {
    if (rule.type !== netFirewall.NetFirewallRuleType.RULE_IP) {
      return FirewallService.cloneRuleForCreate(rule)
    }
    let normalizedRemoteIps = FirewallService.normalizeCreateIpParams(rule.remoteIps)
    return FirewallService.cloneRuleForCreate(rule, normalizedRemoteIps, normalizedRemoteIps !== undefined)
  }

  static getRulePrimaryKey(rule: netFirewall.NetFirewallRule): number | undefined {
    let sourceRule = rule as FirewallRuleWithKey
    if (typeof sourceRule.ruleId === 'number') {
      return sourceRule.ruleId
    }
    if (typeof sourceRule.id === 'number') {
      return sourceRule.id
    }
    return undefined
  }

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
      let existingPolicy = await FirewallService.getFirewallPolicy()
      let policy: netFirewall.NetFirewallPolicy = {
        isOpen: enabled,
        inAction: existingPolicy?.inAction ?? netFirewall.FirewallRuleAction.RULE_ALLOW,
        outAction: existingPolicy?.outAction ?? netFirewall.FirewallRuleAction.RULE_ALLOW
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

  static async setFirewallPolicy(policy: netFirewall.NetFirewallPolicy): Promise<boolean> {
    FirewallService.clearLastError()
    try {
      await netFirewall.setNetFirewallPolicy(DEFAULT_USER_ID, policy)
      hilog.info(DOMAIN, TAG, `setFirewallPolicy success: ${JSON.stringify(policy)}`)
      return true
    } catch (err) {
      FirewallService.recordError('set firewall policy failed', err as Object)
      hilog.error(DOMAIN, TAG, `setFirewallPolicy failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // 获取所有防火墙规则（分页获取全部）
  static async getAllRules(): Promise<netFirewall.NetFirewallRule[]> {
    FirewallService.clearLastError()
    try {
      let allRules: netFirewall.NetFirewallRule[] = []
      let page = 1
      while (true) {
        let requestParam: netFirewall.RequestParam = {
          page: page,
          pageSize: 50,
          orderField: netFirewall.NetFirewallOrderField.ORDER_BY_RULE_NAME,
          orderType: netFirewall.NetFirewallOrderType.ORDER_ASC
        }
        let result = await netFirewall.getNetFirewallRules(DEFAULT_USER_ID, requestParam)
        let pageRules = result.data ?? []
        allRules.push(...pageRules)
        if (pageRules.length < requestParam.pageSize) {
          break
        }
        page++
      }
      return allRules
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
      let preparedRule = FirewallService.normalizeRuleForCreate(rule)
      FirewallService.logRulePayload('addRule payload', preparedRule)
      let ruleId = await netFirewall.addNetFirewallRule(preparedRule)
      hilog.info(DOMAIN, TAG, `addRule success, ruleId: ${ruleId}`)
      return ruleId
    } catch (err) {
      FirewallService.recordError('新增防火墙规则', err as Object)
      let preparedRule = FirewallService.normalizeRuleForCreate(rule)
      FirewallService.logRulePayload('addRule failed payload', preparedRule)
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
      FirewallService.logRulePayload('updateRule payload', rule)
      await netFirewall.updateNetFirewallRule(rule)
      hilog.info(DOMAIN, TAG, `updateRule success`)
      return true
    } catch (err) {
      FirewallService.recordError('更新防火墙规则', err as Object)
      FirewallService.logRulePayload('updateRule failed payload', rule)
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

  static cloneRuleForCreate(
    rule: netFirewall.NetFirewallRule,
    remoteIpsOverride?: netFirewall.NetFirewallIpParams[],
    includeRemoteIps: boolean = true
  ): netFirewall.NetFirewallRule {
    let clonedRule: netFirewall.NetFirewallRule = {
      userId: FirewallService.normalizeNumber(rule.userId) ?? DEFAULT_USER_ID,
      name: rule.name,
      direction: rule.direction,
      action: rule.action,
      type: rule.type,
      isEnabled: rule.isEnabled
    }
    if (rule.description !== undefined) {
      clonedRule.description = rule.description
    }
    let appUid = FirewallService.normalizeNumber(rule.appUid)
    if (appUid !== undefined) {
      clonedRule.appUid = appUid
    }
    let localIps = FirewallService.cloneIpParams(rule.localIps)
    if (localIps !== undefined) {
      clonedRule.localIps = localIps
    }
    if (includeRemoteIps) {
      let remoteIps = remoteIpsOverride ?? FirewallService.cloneIpParams(rule.remoteIps)
      if (remoteIps !== undefined) {
        clonedRule.remoteIps = remoteIps
      }
    }
    let protocol = FirewallService.normalizeNumber(rule.protocol)
    if (protocol !== undefined) {
      clonedRule.protocol = protocol
    }
    let localPorts = FirewallService.clonePortParams(rule.localPorts)
    if (localPorts !== undefined) {
      clonedRule.localPorts = localPorts
    }
    let remotePorts = FirewallService.clonePortParams(rule.remotePorts)
    if (remotePorts !== undefined) {
      clonedRule.remotePorts = remotePorts
    }
    let domains = FirewallService.cloneDomainParams(rule.domains)
    if (domains !== undefined) {
      clonedRule.domains = domains
    }
    let dns = FirewallService.cloneDnsParams(rule.dns)
    if (dns !== undefined) {
      clonedRule.dns = dns
    }
    return clonedRule
  }

  private static cloneIpParams(
    source?: netFirewall.NetFirewallIpParams[]
  ): netFirewall.NetFirewallIpParams[] | undefined {
    if (!source || source.length === 0) {
      return undefined
    }
    let result: netFirewall.NetFirewallIpParams[] = []
    for (let i = 0; i < source.length; i++) {
      let clonedItem = FirewallService.sanitizeIpParam(source[i])
      if (clonedItem) {
        result.push(clonedItem)
      }
    }
    return result.length > 0 ? result : undefined
  }

  private static normalizeCreateIpParams(
    source?: netFirewall.NetFirewallIpParams[]
  ): netFirewall.NetFirewallIpParams[] | undefined {
    if (!source || source.length === 0) {
      return undefined
    }
    let result: netFirewall.NetFirewallIpParams[] = []
    for (let i = 0; i < source.length; i++) {
      let normalized = FirewallService.normalizeCreateIpParam(source[i])
      if (normalized) {
        result.push(normalized)
      }
    }
    return result.length > 0 ? result : undefined
  }

  private static normalizeCreateIpParam(
    source: netFirewall.NetFirewallIpParams
  ): netFirewall.NetFirewallIpParams | undefined {
    if (FirewallService.isAnyIpv4Param(source)) {
      return undefined
    }
    return FirewallService.sanitizeIpParam(source)
  }

  private static isAnyIpv4Param(source: netFirewall.NetFirewallIpParams): boolean {
    return source.address === '0.0.0.0' && FirewallService.normalizeNumber(source.mask) === 0
  }

  private static sanitizeIpParam(
    source: netFirewall.NetFirewallIpParams
  ): netFirewall.NetFirewallIpParams | undefined {
    let family = FirewallService.normalizeNumber(source.family) ?? 1
    if (source.type === 1 || (source.address !== undefined && source.mask !== undefined)) {
      let mask = FirewallService.normalizeNumber(source.mask)
      if (source.address === undefined || mask === undefined) {
        return undefined
      }
      return {
        type: 1,
        family: family,
        address: source.address,
        mask: mask
      }
    }
    if (source.type === 2 || (source.startIp !== undefined && source.endIp !== undefined)) {
      if (source.startIp === undefined || source.endIp === undefined) {
        return undefined
      }
      return {
        type: 2,
        family: family,
        startIp: source.startIp,
        endIp: source.endIp
      }
    }
    return undefined
  }

  private static clonePortParams(
    source?: netFirewall.NetFirewallPortParams[]
  ): netFirewall.NetFirewallPortParams[] | undefined {
    if (!source || source.length === 0) {
      return undefined
    }
    let result: netFirewall.NetFirewallPortParams[] = []
    for (let i = 0; i < source.length; i++) {
      let item = source[i]
      let startPort = FirewallService.normalizeNumber(item.startPort)
      let endPort = FirewallService.normalizeNumber(item.endPort)
      if (startPort === undefined && endPort === undefined) {
        continue
      }
      let resolvedStartPort = startPort ?? endPort ?? 0
      let resolvedEndPort = endPort ?? startPort ?? resolvedStartPort
      result.push({
        startPort: resolvedStartPort,
        endPort: resolvedEndPort
      })
    }
    return result.length > 0 ? result : undefined
  }

  private static cloneDomainParams(
    source?: netFirewall.NetFirewallDomainParams[]
  ): netFirewall.NetFirewallDomainParams[] | undefined {
    if (!source || source.length === 0) {
      return undefined
    }
    let result: netFirewall.NetFirewallDomainParams[] = []
    for (let i = 0; i < source.length; i++) {
      let item = source[i]
      result.push({
        domain: item.domain,
        isWildcard: item.isWildcard
      })
    }
    return result
  }

  private static cloneDnsParams(
    source?: netFirewall.NetFirewallDnsParams
  ): netFirewall.NetFirewallDnsParams | undefined {
    if (!source || typeof source.primaryDns !== 'string' || source.primaryDns.trim().length === 0) {
      return undefined
    }
    let result: netFirewall.NetFirewallDnsParams = {
      primaryDns: source.primaryDns
    }
    if (typeof source.standbyDns === 'string' && source.standbyDns.trim().length > 0) {
      result.standbyDns = source.standbyDns
    }
    return result
  }

  private static getDnsStandbyState(source?: netFirewall.NetFirewallDnsParams): string | undefined {
    if (!source) {
      return undefined
    }
    let keys = Object.keys(source as Object as Record<string, Object>)
    if (keys.indexOf('standbyDns') === -1) {
      return 'omitted'
    }
    if (typeof source.standbyDns === 'string' && source.standbyDns.trim().length > 0) {
      return 'present'
    }
    return 'invalid'
  }

  private static normalizeNumber(value: Object | number | undefined): number | undefined {
    if (typeof value === 'number' && Number.isFinite(value)) {
      return value
    }
    return undefined
  }

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
    let clonedRule = FirewallService.cloneRuleForCreate(rule)
    clonedRule.description = FirewallService.buildManagedRuleDescription(metadata)
    return clonedRule
  }

  static async addRules(rules: netFirewall.NetFirewallRule[]): Promise<boolean> {
    for (let i = 0; i < rules.length; i++) {
      let ruleId = await FirewallService.addRule(FirewallService.cloneRuleForCreate(rules[i]))
      if (ruleId <= 0) {
        return false
      }
    }
    return true
  }

  static async clearAllRules(): Promise<boolean> {
    let rules = await FirewallService.getAllRules()
    for (let i = 0; i < rules.length; i++) {
      let ruleId = FirewallService.getRulePrimaryKey(rules[i])
      if (ruleId === undefined) {
        continue
      }
      let removed = await FirewallService.removeRule(ruleId)
      if (!removed) {
        return false
      }
    }
    return true
  }

  static async applyRuleSet(
    rules: netFirewall.NetFirewallRule[],
    mode: FirewallPresetMode
  ): Promise<boolean> {
    FirewallService.clearLastError()
    let snapshotPolicy = await FirewallService.getFirewallPolicy()
    if (snapshotPolicy === null) {
      return false
    }
    let snapshotRules = await FirewallService.getAllRules()
    let targetPolicy: netFirewall.NetFirewallPolicy = {
      isOpen: snapshotPolicy.isOpen,
      inAction: netFirewall.FirewallRuleAction.RULE_DENY,
      outAction: netFirewall.FirewallRuleAction.RULE_ALLOW
    }
    if (!await FirewallService.clearAllRules()) {
      return false
    }
    if (!await FirewallService.setFirewallPolicy(targetPolicy)) {
      await FirewallService.restoreRuleSet(snapshotPolicy, snapshotRules)
      return false
    }
    if (!await FirewallService.addRules(rules)) {
      hilog.error(DOMAIN, TAG, `applyRuleSet failed while applying mode=${mode}`)
      await FirewallService.restoreRuleSet(snapshotPolicy, snapshotRules)
      return false
    }
    return true
  }

  private static async restoreRuleSet(
    policy: netFirewall.NetFirewallPolicy,
    rules: netFirewall.NetFirewallRule[]
  ): Promise<void> {
    await FirewallService.clearAllRules()
    await FirewallService.setFirewallPolicy(policy)
    await FirewallService.addRules(rules.map((rule: netFirewall.NetFirewallRule) => FirewallService.cloneRuleForCreate(rule)))
  }

  static findRuleConflict(
    existingRules: netFirewall.NetFirewallRule[],
    newRule: netFirewall.NetFirewallRule,
    excludeRuleId?: number
  ): FirewallRuleConflictMatch | null {
    for (let i = 0; i < existingRules.length; i++) {
      let existingRule = existingRules[i]
      if (excludeRuleId !== undefined && FirewallService.getRulePrimaryKey(existingRule) === excludeRuleId) {
        continue
      }
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
    if (!ipParams) {
      return null
    }
    let ipRange = FirewallService.normalizeIpParamRange(ipParams)
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

  private static normalizeIpParamRange(ipParam: netFirewall.NetFirewallIpParams): NormalizedIpRange | null {
    if (ipParam.startIp && ipParam.endIp) {
      let startIp = FirewallService.parseIpv4(ipParam.startIp.trim())
      let endIp = FirewallService.parseIpv4(ipParam.endIp.trim())
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
    return FirewallService.normalizeIpv4Range(ipParam.address, ipParam.mask)
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
  private static logRulePayload(prefix: string, rule: netFirewall.NetFirewallRule): void {
    let summary: FirewallRuleLogPayload = {
      primaryKey: FirewallService.getRulePrimaryKey(rule),
      name: rule.name,
      description: rule.description,
      type: rule.type,
      direction: rule.direction,
      action: rule.action,
      userId: rule.userId,
      appUidType: rule.appUid === undefined ? 'absent' : typeof rule.appUid,
      isEnabled: rule.isEnabled,
      protocol: rule.protocol,
      localIps: FirewallService.sanitizeLogIpParams(rule.localIps),
      remoteIps: FirewallService.sanitizeLogIpParams(rule.remoteIps),
      localPorts: rule.localPorts,
      remotePorts: rule.remotePorts,
      domains: FirewallService.cloneDomainParams(rule.domains),
      dns: FirewallService.cloneDnsParams(rule.dns),
      dnsStandbyState: FirewallService.getDnsStandbyState(rule.dns)
    }
    hilog.info(DOMAIN, TAG, `${prefix}: ${JSON.stringify(summary)}`)
  }

  private static sanitizeLogIpParams(
    source?: netFirewall.NetFirewallIpParams[]
  ): netFirewall.NetFirewallIpParams[] | undefined {
    return FirewallService.cloneIpParams(source)
  }

  static countByType(rules: netFirewall.NetFirewallRule[], type: netFirewall.NetFirewallRuleType): number {
    return rules.filter((r: netFirewall.NetFirewallRule) => r.type === type).length
  }

  // 按方向统计数量
  static countByDirection(rules: netFirewall.NetFirewallRule[], direction: netFirewall.NetFirewallRuleDirection): number {
    return rules.filter((r: netFirewall.NetFirewallRule) => r.direction === direction).length
  }
}
