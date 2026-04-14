import { LogUtils } from '../../../utils/LogUtils'
import { netFirewall } from '@kit.NetworkKit'
import { AppInfo } from '../../../constants/AppConstants'

export class FirewallRepository {
  private static readonly TAG = 'FirewallRepository'

  static async getFirewallPolicy(): Promise<netFirewall.NetFirewallPolicy | null> {
    try {
      return await netFirewall.getNetFirewallPolicy(AppInfo.DEFAULT_USER_ID)
    } catch (err) {
      LogUtils.error(FirewallRepository.TAG, `getFirewallPolicy failed: ${JSON.stringify(err)}`)
      return null
    }
  }

  static async getAllRules(userId?: number): Promise<netFirewall.NetFirewallRule[]> {
    try {
      let effectiveUserId = userId ?? AppInfo.DEFAULT_USER_ID
      let allRules: netFirewall.NetFirewallRule[] = []
      let page = 1
      while (true) {
        let requestParam: netFirewall.RequestParam = {
          page: page,
          pageSize: 50,
          orderField: netFirewall.NetFirewallOrderField.ORDER_BY_RULE_NAME,
          orderType: netFirewall.NetFirewallOrderType.ORDER_ASC
        }
        let result = await netFirewall.getNetFirewallRules(effectiveUserId, requestParam)
        let pageRules = result.data ?? []
        allRules.push(...pageRules)
        if (pageRules.length < requestParam.pageSize) {
          break
        }
        page++
      }
      return allRules
    } catch (err) {
      LogUtils.error(FirewallRepository.TAG, `getAllRules failed: ${JSON.stringify(err)}`)
      return []
    }
  }

  static async setFirewallEnabled(enabled: boolean): Promise<boolean> {
    try {
      let existingPolicy = await FirewallRepository.getFirewallPolicy()
      if (existingPolicy === null) {
        return false
      }
      let policy: netFirewall.NetFirewallPolicy = {
        isOpen: enabled,
        inAction: existingPolicy.inAction,
        outAction: existingPolicy.outAction
      }
      await netFirewall.setNetFirewallPolicy(AppInfo.DEFAULT_USER_ID, policy)
      return true
    } catch (err) {
      LogUtils.error(FirewallRepository.TAG, `setFirewallEnabled failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static async setFirewallPolicy(policy: netFirewall.NetFirewallPolicy): Promise<boolean> {
    try {
      await netFirewall.setNetFirewallPolicy(AppInfo.DEFAULT_USER_ID, policy)
      return true
    } catch (err) {
      LogUtils.error(FirewallRepository.TAG, `setFirewallPolicy failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static async addRule(rule: netFirewall.NetFirewallRule): Promise<number> {
    let preparedRule = FirewallRepository.normalizeRuleForCreate(rule)
    LogUtils.info(FirewallRepository.TAG, `addRule payload: ${JSON.stringify(preparedRule)}`)
    try {
      return await netFirewall.addNetFirewallRule(preparedRule)
    } catch (err) {
      LogUtils.error(FirewallRepository.TAG, `addRule failed payload: ${JSON.stringify(preparedRule)}`)
      LogUtils.error(FirewallRepository.TAG, `addRule failed: ${JSON.stringify(err)}`)
      return -1
    }
  }

  static async removeRule(ruleId: number): Promise<boolean> {
    LogUtils.info(FirewallRepository.TAG, `removeRule payload: ruleId=${ruleId}`)
    try {
      await netFirewall.removeNetFirewallRule(AppInfo.DEFAULT_USER_ID, ruleId)
      return true
    } catch (err) {
      LogUtils.error(FirewallRepository.TAG, `removeRule failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static async updateRule(rule: netFirewall.NetFirewallRule): Promise<boolean> {
    LogUtils.info(FirewallRepository.TAG, `updateRule payload: ${JSON.stringify(rule)}`)
    try {
      await netFirewall.updateNetFirewallRule(rule)
      return true
    } catch (err) {
      LogUtils.error(FirewallRepository.TAG, `updateRule failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static async replaceRule(oldRuleId: number, newRule: netFirewall.NetFirewallRule): Promise<number> {
    LogUtils.info(FirewallRepository.TAG, `replaceRule payload: oldRuleId=${oldRuleId}, newRule=${JSON.stringify(newRule)}`)
    let removed = await FirewallRepository.removeRule(oldRuleId)
    if (!removed) {
      return -1
    }
    let newRuleId = await FirewallRepository.addRule(newRule)
    if (newRuleId > 0) {
      return newRuleId
    }
    LogUtils.error(FirewallRepository.TAG, `replaceRule failed after removing old rule, oldRuleId=${oldRuleId}`)
    return -1
  }

  static async addRules(rules: netFirewall.NetFirewallRule[]): Promise<boolean> {
    LogUtils.info(FirewallRepository.TAG, `addRules payload: rules.length=${rules.length}`)
    for (let i = 0; i < rules.length; i++) {
      let ruleId = await FirewallRepository.addRule(FirewallRepository.cloneRuleForCreate(rules[i]))
      if (ruleId <= 0) {
        return false
      }
    }
    return true
  }

  static async clearAllRules(): Promise<boolean> {
    let rules = await FirewallRepository.getAllRules()
    for (let i = 0; i < rules.length; i++) {
      let ruleId = FirewallRepository.getRulePrimaryKey(rules[i])
      if (ruleId === undefined) {
        continue
      }
      let removed = await FirewallRepository.removeRule(ruleId)
      if (!removed) {
        return false
      }
    }
    return true
  }

  static normalizeRuleForCreate(rule: netFirewall.NetFirewallRule): netFirewall.NetFirewallRule {
    if (rule.type !== netFirewall.NetFirewallRuleType.RULE_IP) {
      return FirewallRepository.cloneRuleForCreate(rule)
    }
    let normalizedRemoteIps = FirewallRepository.normalizeCreateIpParams(rule.remoteIps)
    return FirewallRepository.cloneRuleForCreate(
      rule,
      normalizedRemoteIps,
      normalizedRemoteIps !== undefined,
      normalizedRemoteIps !== undefined
    )
  }

  static cloneRuleForCreate(
    rule: netFirewall.NetFirewallRule,
    remoteIpsOverride?: netFirewall.NetFirewallIpParams[],
    preserveEmptyRemoteIps: boolean = false,
    copyRuleIpRemoteIps: boolean = true
  ): netFirewall.NetFirewallRule {
    let clonedRule: netFirewall.NetFirewallRule = {
      userId: FirewallRepository.normalizeNumber(rule.userId) ?? AppInfo.DEFAULT_USER_ID,
      name: rule.name,
      direction: rule.direction,
      action: rule.action,
      type: rule.type,
      isEnabled: rule.isEnabled
    }
    let sourceRule = rule as FirewallRuleWithKey
    let targetRule = clonedRule as FirewallRuleWithKey
    if (typeof sourceRule.ruleId === 'number') {
      targetRule.ruleId = sourceRule.ruleId
    }
    if (typeof sourceRule.id === 'number') {
      targetRule.id = sourceRule.id
    }
    if (rule.description !== undefined) {
      clonedRule.description = rule.description
    }
    let appUid = FirewallRepository.normalizeNumber(rule.appUid)
    if (appUid !== undefined) {
      clonedRule.appUid = appUid
    }
    let localIps = FirewallRepository.cloneIpParams(rule.localIps)
    if (localIps !== undefined) {
      clonedRule.localIps = localIps
    }
    let shouldCloneRemoteIps = preserveEmptyRemoteIps || remoteIpsOverride !== undefined ||
      (rule.type === netFirewall.NetFirewallRuleType.RULE_IP && copyRuleIpRemoteIps)
    if (shouldCloneRemoteIps) {
      let remoteIps = remoteIpsOverride ?? FirewallRepository.cloneIpParams(rule.remoteIps)
      if (remoteIps !== undefined) {
        clonedRule.remoteIps = remoteIps
      }
    }
    let protocol = FirewallRepository.normalizeNumber(rule.protocol)
    if (protocol !== undefined) {
      clonedRule.protocol = protocol
    }
    let localPorts = FirewallRepository.clonePortParams(rule.localPorts)
    if (localPorts !== undefined) {
      clonedRule.localPorts = localPorts
    }
    let remotePorts = FirewallRepository.clonePortParams(rule.remotePorts)
    if (remotePorts !== undefined) {
      clonedRule.remotePorts = remotePorts
    }
    let domains = FirewallRepository.cloneDomainParams(rule.domains)
    if (domains !== undefined) {
      clonedRule.domains = domains
    }
    let dns = FirewallRepository.cloneDnsParams(rule.dns)
    if (dns !== undefined) {
      clonedRule.dns = dns
    }
    return clonedRule
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

  private static cloneIpParams(
    source?: netFirewall.NetFirewallIpParams[]
  ): netFirewall.NetFirewallIpParams[] | undefined {
    if (!source || source.length === 0) {
      return undefined
    }
    let result: netFirewall.NetFirewallIpParams[] = []
    for (let i = 0; i < source.length; i++) {
      let clonedItem = FirewallRepository.sanitizeIpParam(source[i])
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
      let normalized = FirewallRepository.normalizeCreateIpParam(source[i])
      if (normalized) {
        result.push(normalized)
      }
    }
    return result.length > 0 ? result : undefined
  }

  private static normalizeCreateIpParam(
    source: netFirewall.NetFirewallIpParams
  ): netFirewall.NetFirewallIpParams | undefined {
    if (FirewallRepository.isAnyIpv4Param(source)) {
      return undefined
    }
    return FirewallRepository.sanitizeIpParam(source)
  }

  private static isAnyIpv4Param(source: netFirewall.NetFirewallIpParams): boolean {
    return source.address === '0.0.0.0' && FirewallRepository.normalizeNumber(source.mask) === 0
  }

  private static sanitizeIpParam(
    source: netFirewall.NetFirewallIpParams
  ): netFirewall.NetFirewallIpParams | undefined {
    let family = FirewallRepository.normalizeNumber(source.family) ?? 1
    if (source.type === 1 || (source.address !== undefined && source.mask !== undefined)) {
      let mask = FirewallRepository.normalizeNumber(source.mask)
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
      let startPort = FirewallRepository.normalizeNumber(item.startPort)
      let endPort = FirewallRepository.normalizeNumber(item.endPort)
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

  private static normalizeNumber(value: Object | number | undefined): number | undefined {
    if (typeof value === 'number' && Number.isFinite(value)) {
      return value
    }
    return undefined
  }
}

interface FirewallRuleWithKey extends netFirewall.NetFirewallRule {
  id?: number
  ruleId?: number
}
