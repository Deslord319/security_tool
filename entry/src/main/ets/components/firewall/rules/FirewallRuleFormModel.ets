import { netFirewall } from '@kit.NetworkKit'
import { AppInfo } from '../../../constants/AppConstants'
import { FirewallDialogStrings } from '../../../constants/modules/FirewallStrings'
import { Ipv4Utils } from '../../../utils/Ipv4Utils'
import {
  attachFirewallRuleUserIds,
  FIREWALL_IPV4_FAMILY,
  FIREWALL_IPV4_MASK_MAX,
  FIREWALL_IPV4_MASK_MIN,
  FIREWALL_IPV4_PARAM_TYPE,
  FIREWALL_MAX_PORT_ITEM_COUNT,
  FIREWALL_PORT_MAX,
  FIREWALL_PORT_MIN,
  FIREWALL_PROTOCOL_TCP,
  FirewallScopedRule,
  getFirewallRuleUserIds,
  normalizeFirewallRuleUserIds,
  UserFirewallOption
} from '../../../services/firewall/FirewallModels'
import { FirewallRuleUtils } from '../../../services/firewall/FirewallRuleUtils'

export interface FirewallRuleFormParseResult<T> {
  success: boolean
  value?: T
  errorMessage?: string
}

export interface FirewallRuleFormState {
  ruleName: string
  ruleType: number
  ruleDirection: number
  protocol: number
  remoteAddress: string
  standbyDns: string
  localPort: string
  remotePort: string
  action: number
  selectedUserIds: number[]
}

export class FirewallRuleFormModel {
  static buildInitialState(
    initialRule: netFirewall.NetFirewallRule | undefined,
    userOptions: UserFirewallOption[]
  ): FirewallRuleFormState {
    let state = FirewallRuleFormModel.createDefaultState(userOptions)
    if (!initialRule) {
      return state
    }
    state.ruleName = initialRule.name ?? ''
    state.ruleType = initialRule.type ?? netFirewall.NetFirewallRuleType.RULE_IP
    state.ruleDirection = initialRule.direction ?? netFirewall.NetFirewallRuleDirection.RULE_IN
    state.action = initialRule.action ?? netFirewall.FirewallRuleAction.RULE_ALLOW
    state.protocol = initialRule.protocol ?? FIREWALL_PROTOCOL_TCP
    state.remoteAddress = FirewallRuleFormModel.resolveAddressForRule(initialRule)
    if (initialRule.type === netFirewall.NetFirewallRuleType.RULE_DNS) {
      state.standbyDns = initialRule.dns?.standbyDns ?? ''
    }
    let resolvedPort = FirewallRuleFormModel.resolvePortForDirection(initialRule)
    state.localPort = state.ruleDirection === netFirewall.NetFirewallRuleDirection.RULE_IN ? resolvedPort : ''
    state.remotePort = state.ruleDirection === netFirewall.NetFirewallRuleDirection.RULE_OUT ? resolvedPort : ''
    let ruleUserIds = normalizeFirewallRuleUserIds(getFirewallRuleUserIds(initialRule))
    state.selectedUserIds = ruleUserIds.length > 0
      ? ruleUserIds
      : FirewallRuleFormModel.getAllAvailableUserIds(userOptions)
    return state
  }

  static createDefaultState(userOptions: UserFirewallOption[]): FirewallRuleFormState {
    return {
      ruleName: '',
      ruleType: netFirewall.NetFirewallRuleType.RULE_IP,
      ruleDirection: netFirewall.NetFirewallRuleDirection.RULE_IN,
      protocol: FIREWALL_PROTOCOL_TCP,
      remoteAddress: '',
      standbyDns: '',
      localPort: '',
      remotePort: '',
      action: netFirewall.FirewallRuleAction.RULE_ALLOW,
      selectedUserIds: FirewallRuleFormModel.getAllAvailableUserIds(userOptions)
    }
  }

  static getAllAvailableUserIds(userOptions: UserFirewallOption[]): number[] {
    return normalizeFirewallRuleUserIds(userOptions.map((item: UserFirewallOption): number => item.userId))
  }

  static getSelectedUserIdsForSave(userIds: number[]): number[] {
    return normalizeFirewallRuleUserIds(userIds)
  }

  static resolveAddressForRule(rule: netFirewall.NetFirewallRule): string {
    if (rule.type === netFirewall.NetFirewallRuleType.RULE_IP) {
      let ipParams = rule.direction === netFirewall.NetFirewallRuleDirection.RULE_IN ? rule.localIps : rule.remoteIps
      return FirewallRuleUtils.formatIpParamsForDisplay(ipParams)
    }
    if (rule.type === netFirewall.NetFirewallRuleType.RULE_DOMAIN) {
      return rule.domains?.[0]?.domain ?? ''
    }
    if (rule.type === netFirewall.NetFirewallRuleType.RULE_DNS) {
      return rule.dns?.primaryDns ?? ''
    }
    return ''
  }

  static resolvePortForDirection(rule: netFirewall.NetFirewallRule): string {
    if (rule.type !== netFirewall.NetFirewallRuleType.RULE_IP) {
      return ''
    }
    let ports = rule.direction === netFirewall.NetFirewallRuleDirection.RULE_IN ? rule.localPorts : rule.remotePorts
    return FirewallRuleUtils.formatPortParamsForDisplay(ports)
  }

  static parseIpInput(raw: string): FirewallRuleFormParseResult<netFirewall.NetFirewallIpParams[] | undefined> {
    let value = raw.trim()
    if (value.length === 0 || value.toUpperCase() === FirewallDialogStrings.ALL_VALUE) {
      return { success: true, value: undefined }
    }
    let rangeParts = value.split('-')
    if (rangeParts.length > 2) {
      return { success: false, errorMessage: FirewallDialogStrings.ERROR_INVALID_IP_RANGE }
    }
    if (rangeParts.length === 2) {
      return FirewallRuleFormModel.parseIpRange(rangeParts[0].trim(), rangeParts[1].trim())
    }
    return FirewallRuleFormModel.parseIpAddressOrCidr(value)
  }

  static parsePortInput(
    raw: string,
    invalidMessage: string,
    maxPortItemCount: number = FIREWALL_MAX_PORT_ITEM_COUNT
  ): FirewallRuleFormParseResult<netFirewall.NetFirewallPortParams[] | undefined> {
    let value = raw.trim()
    if (value.length === 0 || value.toUpperCase() === FirewallDialogStrings.ALL_VALUE) {
      return { success: true, value: undefined }
    }
    let tokens = value.split(',')
    let result: netFirewall.NetFirewallPortParams[] = []
    for (let i = 0; i < tokens.length; i++) {
      let token = tokens[i].trim()
      if (token.length === 0) {
        return { success: false, errorMessage: `${FirewallDialogStrings.ERROR_INVALID_PORT_TOKEN}: ${i + 1}` }
      }
      let parsed = FirewallRuleFormModel.parsePortToken(token, invalidMessage)
      if (!parsed.success) {
        return {
          success: false,
          errorMessage: parsed.errorMessage
        }
      }
      if (parsed.value) {
        result.push(parsed.value)
      }
    }
    let normalized = FirewallRuleFormModel.normalizePorts(result)
    if (normalized.length > maxPortItemCount) {
      return { success: false, errorMessage: `${FirewallDialogStrings.ERROR_PORT_ITEM_LIMIT}: ${maxPortItemCount}` }
    }
    return { success: true, value: normalized.length > 0 ? normalized : undefined }
  }

  static validate(state: FirewallRuleFormState): string {
    let ruleName = state.ruleName.trim()
    let remoteAddress = state.remoteAddress.trim()
    let portValue = state.ruleDirection === netFirewall.NetFirewallRuleDirection.RULE_IN
      ? state.localPort.trim()
      : state.remotePort.trim()

    if (ruleName.length === 0) {
      return FirewallDialogStrings.RULE_NAME_PLACEHOLDER
    }

    if (remoteAddress.length === 0) {
      if (state.ruleType === netFirewall.NetFirewallRuleType.RULE_DOMAIN) {
        return FirewallDialogStrings.ERROR_DOMAIN_REQUIRED
      }
      if (state.ruleType === netFirewall.NetFirewallRuleType.RULE_DNS) {
        return FirewallDialogStrings.ERROR_DNS_REQUIRED
      }
    }

    if (state.ruleType === netFirewall.NetFirewallRuleType.RULE_IP) {
      let ipResult = FirewallRuleFormModel.parseIpInput(remoteAddress)
      if (!ipResult.success) {
        return ipResult.errorMessage ?? FirewallDialogStrings.ERROR_INVALID_IP
      }
      let portResult = FirewallRuleFormModel.parsePortInput(
        portValue,
        state.ruleDirection === netFirewall.NetFirewallRuleDirection.RULE_IN
          ? FirewallDialogStrings.ERROR_INVALID_LOCAL_PORT
          : FirewallDialogStrings.ERROR_INVALID_REMOTE_PORT
      )
      if (!portResult.success) {
        return portResult.errorMessage ??
          (state.ruleDirection === netFirewall.NetFirewallRuleDirection.RULE_IN
            ? FirewallDialogStrings.ERROR_INVALID_LOCAL_PORT
            : FirewallDialogStrings.ERROR_INVALID_REMOTE_PORT)
      }
    }

    if (state.ruleType === netFirewall.NetFirewallRuleType.RULE_DOMAIN &&
      !FirewallRuleFormModel.isValidDomain(remoteAddress)) {
      return FirewallDialogStrings.ERROR_INVALID_DOMAIN
    }

    if (state.ruleType === netFirewall.NetFirewallRuleType.RULE_DNS && !Ipv4Utils.isValidIpv4(remoteAddress)) {
      return FirewallDialogStrings.ERROR_INVALID_DNS
    }

    let standbyDns = state.standbyDns.trim()
    if (state.ruleType === netFirewall.NetFirewallRuleType.RULE_DNS &&
      standbyDns.length > 0 && !Ipv4Utils.isValidIpv4(standbyDns)) {
      return FirewallDialogStrings.ERROR_INVALID_STANDBY_DNS
    }

    if (FirewallRuleFormModel.getSelectedUserIdsForSave(state.selectedUserIds).length === 0) {
      return FirewallDialogStrings.ERROR_USER_SCOPE_REQUIRED
    }

    return ''
  }

  static buildRule(
    state: FirewallRuleFormState,
    initialRule: netFirewall.NetFirewallRule | undefined,
    isEditMode: boolean
  ): netFirewall.NetFirewallRule {
    let rule: netFirewall.NetFirewallRule = {
      userId: initialRule?.userId ?? AppInfo.DEFAULT_USER_ID,
      name: state.ruleName.trim(),
      direction: state.ruleDirection as netFirewall.NetFirewallRuleDirection,
      action: state.action as netFirewall.FirewallRuleAction,
      type: state.ruleType as netFirewall.NetFirewallRuleType,
      protocol: state.protocol,
      isEnabled: initialRule?.isEnabled ?? true,
      description: initialRule?.description
    }
    if (isEditMode && initialRule) {
      let scopedRule = rule as FirewallScopedRule
      let originalRule = initialRule as FirewallScopedRule
      if (typeof originalRule.id === 'number') {
        scopedRule.id = originalRule.id
      }
      if (typeof originalRule.localRuleId === 'string') {
        scopedRule.localRuleId = originalRule.localRuleId
      }
    }
    FirewallRuleFormModel.applyRuleSpecificFields(
      rule,
      state.remoteAddress.trim(),
      state.localPort.trim(),
      state.remotePort.trim(),
      state.standbyDns.trim()
    )
    return attachFirewallRuleUserIds(rule, FirewallRuleFormModel.getSelectedUserIdsForSave(state.selectedUserIds))
  }

  static isValidDomain(value: string): boolean {
    return /^(?:\*\.)?(?=.{1,253}$)(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$/.test(value)
  }

  private static parseIpRange(
    startIp: string,
    endIp: string
  ): FirewallRuleFormParseResult<netFirewall.NetFirewallIpParams[] | undefined> {
    if (!Ipv4Utils.isValidIpv4(startIp) || !Ipv4Utils.isValidIpv4(endIp)) {
      return { success: false, errorMessage: FirewallDialogStrings.ERROR_INVALID_IP_RANGE }
    }
    let startValue = Ipv4Utils.parseIpv4(startIp)
    let endValue = Ipv4Utils.parseIpv4(endIp)
    if (startValue === null || endValue === null || startValue > endValue) {
      return { success: false, errorMessage: FirewallDialogStrings.ERROR_INVALID_IP_RANGE }
    }
    return {
      success: true,
      value: [{
        type: FIREWALL_IPV4_PARAM_TYPE,
        family: FIREWALL_IPV4_FAMILY,
        startIp: startIp,
        endIp: endIp
      }]
    }
  }

  private static parseIpAddressOrCidr(raw: string): FirewallRuleFormParseResult<netFirewall.NetFirewallIpParams[] | undefined> {
    let cidrParts = raw.split('/')
    if (cidrParts.length > 2 || !Ipv4Utils.isValidIpv4(cidrParts[0].trim())) {
      return { success: false, errorMessage: FirewallDialogStrings.ERROR_INVALID_IP }
    }
    if (cidrParts.length === 2) {
      let maskRaw = cidrParts[1].trim()
      if (!/^\d+$/.test(maskRaw)) {
        return { success: false, errorMessage: FirewallDialogStrings.ERROR_INVALID_CIDR_MASK }
      }
      let maskValue = parseInt(maskRaw, 10)
      if (maskValue < FIREWALL_IPV4_MASK_MIN || maskValue > FIREWALL_IPV4_MASK_MAX) {
        return { success: false, errorMessage: FirewallDialogStrings.ERROR_INVALID_CIDR_MASK }
      }
      return {
        success: true,
        value: [{
          type: FIREWALL_IPV4_PARAM_TYPE,
          family: FIREWALL_IPV4_FAMILY,
          address: cidrParts[0].trim(),
          mask: maskValue
        }]
      }
    }
    return {
      success: true,
      value: [{
        type: FIREWALL_IPV4_PARAM_TYPE,
        family: FIREWALL_IPV4_FAMILY,
        address: raw,
        mask: FIREWALL_IPV4_MASK_MAX
      }]
    }
  }

  private static parsePortToken(
    token: string,
    invalidMessage: string
  ): FirewallRuleFormParseResult<netFirewall.NetFirewallPortParams | undefined> {
    let rangeParts = token.split('-')
    if (rangeParts.length > 2) {
      return { success: false, errorMessage: `${FirewallDialogStrings.ERROR_INVALID_PORT_RANGE}: ${token}` }
    }
    if (rangeParts.length === 1) {
      return FirewallRuleFormModel.parseSinglePort(token, invalidMessage)
    }
    return FirewallRuleFormModel.parsePortRange(token, rangeParts[0].trim(), rangeParts[1].trim(), invalidMessage)
  }

  private static parseSinglePort(
    token: string,
    invalidMessage: string
  ): FirewallRuleFormParseResult<netFirewall.NetFirewallPortParams | undefined> {
    if (!/^\d+$/.test(token)) {
      return { success: false, errorMessage: `${FirewallDialogStrings.ERROR_INVALID_PORT_TOKEN}: ${token}` }
    }
    let port = parseInt(token, 10)
    if (!FirewallRuleFormModel.isValidPort(port)) {
      return { success: false, errorMessage: invalidMessage }
    }
    return { success: true, value: { startPort: port, endPort: port } }
  }

  private static parsePortRange(
    token: string,
    startRaw: string,
    endRaw: string,
    invalidMessage: string
  ): FirewallRuleFormParseResult<netFirewall.NetFirewallPortParams | undefined> {
    if (!/^\d+$/.test(startRaw) || !/^\d+$/.test(endRaw)) {
      return { success: false, errorMessage: `${FirewallDialogStrings.ERROR_INVALID_PORT_RANGE}: ${token}` }
    }
    let startPort = parseInt(startRaw, 10)
    let endPort = parseInt(endRaw, 10)
    if (!FirewallRuleFormModel.isValidPort(startPort) || !FirewallRuleFormModel.isValidPort(endPort)) {
      return { success: false, errorMessage: invalidMessage }
    }
    if (startPort > endPort) {
      return { success: false, errorMessage: `${FirewallDialogStrings.ERROR_INVALID_PORT_RANGE}: ${token}` }
    }
    return { success: true, value: { startPort: startPort, endPort: endPort } }
  }

  private static normalizePorts(ports: netFirewall.NetFirewallPortParams[]): netFirewall.NetFirewallPortParams[] {
    return ports.sort((left: netFirewall.NetFirewallPortParams, right: netFirewall.NetFirewallPortParams): number => {
      let startDiff = (left.startPort ?? 0) - (right.startPort ?? 0)
      if (startDiff !== 0) {
        return startDiff
      }
      return (left.endPort ?? left.startPort ?? 0) - (right.endPort ?? right.startPort ?? 0)
    }).reduce((items: netFirewall.NetFirewallPortParams[], current: netFirewall.NetFirewallPortParams) => {
      let previous = items[items.length - 1]
      if (previous &&
        previous.startPort === current.startPort &&
        previous.endPort === current.endPort) {
        return items
      }
      items.push(current)
      return items
    }, [])
  }

  private static isValidPort(port: number): boolean {
    return port >= FIREWALL_PORT_MIN && port <= FIREWALL_PORT_MAX
  }

  private static applyRuleSpecificFields(
    rule: netFirewall.NetFirewallRule,
    remoteAddress: string,
    localPort: string,
    remotePort: string,
    standbyDns: string
  ): void {
    if (rule.type === netFirewall.NetFirewallRuleType.RULE_IP) {
      FirewallRuleFormModel.applyIpRuleFields(rule, remoteAddress, localPort, remotePort)
      return
    }
    if (rule.type === netFirewall.NetFirewallRuleType.RULE_DOMAIN) {
      rule.domains = [{ domain: remoteAddress, isWildcard: remoteAddress.includes('*') }]
      rule.remoteIps = undefined
      rule.localPorts = undefined
      rule.remotePorts = undefined
      rule.protocol = undefined
      rule.dns = undefined
      return
    }
    if (rule.type === netFirewall.NetFirewallRuleType.RULE_DNS) {
      rule.dns = { primaryDns: remoteAddress }
      if (standbyDns.length > 0) {
        rule.dns.standbyDns = standbyDns
      }
      rule.remoteIps = undefined
      rule.localPorts = undefined
      rule.remotePorts = undefined
      rule.protocol = undefined
      rule.domains = undefined
    }
  }

  private static applyIpRuleFields(
    rule: netFirewall.NetFirewallRule,
    remoteAddress: string,
    localPort: string,
    remotePort: string
  ): void {
    let ipResult = FirewallRuleFormModel.parseIpInput(remoteAddress)
    let portResult = FirewallRuleFormModel.parsePortInput(
      rule.direction === netFirewall.NetFirewallRuleDirection.RULE_IN ? localPort : remotePort,
      rule.direction === netFirewall.NetFirewallRuleDirection.RULE_IN
        ? FirewallDialogStrings.ERROR_INVALID_LOCAL_PORT
        : FirewallDialogStrings.ERROR_INVALID_REMOTE_PORT
    )
    if (rule.direction === netFirewall.NetFirewallRuleDirection.RULE_IN) {
      rule.localIps = ipResult.value
      rule.localPorts = portResult.value
      rule.remoteIps = undefined
      rule.remotePorts = undefined
    } else {
      rule.remoteIps = ipResult.value
      rule.remotePorts = portResult.value
      rule.localIps = undefined
      rule.localPorts = undefined
    }
    rule.domains = undefined
    rule.dns = undefined
  }
}
