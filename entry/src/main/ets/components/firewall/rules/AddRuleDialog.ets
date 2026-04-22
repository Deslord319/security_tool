import { SymbolGlyphModifier, TextModifier } from '@kit.ArkUI'
import { AppColors, AppStyles, AppInfo } from '../../../constants/AppConstants'
import { netFirewall } from '@kit.NetworkKit'
import { DialogService } from '../../../utils/DialogService'
import { ThemeMode } from '../../../theme/ThemeColors'
import { FormControlUtils } from '../../../utils/FormControlUtils'
import { ActionText } from '../../../constants/StringCatalog'
import { FirewallDialogStrings, FirewallRuleLabelStrings, FirewallUserStrings } from '../../../constants/modules/FirewallStrings'
import { DetailDialogShell } from '../../DetailDialogShell'
import { MultiCheckSelect } from '../../MultiCheckSelect'
import { Ipv4Utils } from '../../../utils/Ipv4Utils'
import { SystemUserProvider } from '../../../services/firewall/providers/SystemUserProvider'
import { UserFirewallOption } from '../../../services/firewall/FirewallModels'
import { FirewallRuleUtils } from '../../../services/firewall/FirewallRuleUtils'
import {
  attachFirewallRuleUserIds,
  getFirewallRuleUserIds
} from '../../../models/DataModels'
import { normalizeFirewallRuleUserIds } from '../../../viewmodels/firewall/rules/FirewallRulesViewModel'

interface FirewallRuleWithKey extends netFirewall.NetFirewallRule {
  id?: number
  ruleId?: number
  localRuleId?: string
}

interface DialogParseResult<T> {
  success: boolean
  value?: T
  errorMessage?: string
}

@CustomDialog
export struct AddRuleDialog {
  controller: CustomDialogController
  onConfirm: (rule: netFirewall.NetFirewallRule) => void = () => {}
  onClose: () => void = () => {}
  initialRule?: netFirewall.NetFirewallRule
  isEditMode: boolean = false
  currentTheme: ThemeMode = ThemeMode.LIGHT

  @State ruleName: string = ''
  @State ruleType: number = netFirewall.NetFirewallRuleType.RULE_IP
  @State ruleDirection: number = netFirewall.NetFirewallRuleDirection.RULE_IN
  @State protocol: number = 6
  @State remoteAddress: string = ''
  @State localPort: string = ''
  @State remotePort: string = ''
  @State action: number = netFirewall.FirewallRuleAction.RULE_ALLOW
  @State userOptions: UserFirewallOption[] = []
  @State selectedUserIds: number[] = []
  private readonly protocolOptions: SelectOption[] = [
    { value: FirewallDialogStrings.PROTOCOL_TCP },
    { value: FirewallDialogStrings.PROTOCOL_UDP },
    { value: FirewallDialogStrings.PROTOCOL_ICMP }
  ]
  private readonly protocolValues: number[] = [6, 17, 1]
  private readonly maxPortItemCount: number = 10

  aboutToAppear(): void {
    this.applyInitialRule()
    void this.loadUserOptions()
  }

  private applyInitialRule(): void {
    let rule = this.initialRule
    if (!rule) {
      return
    }
    this.ruleName = rule.name ?? ''
    this.ruleType = rule.type ?? netFirewall.NetFirewallRuleType.RULE_IP
    this.ruleDirection = rule.direction ?? netFirewall.NetFirewallRuleDirection.RULE_IN
    this.action = rule.action ?? netFirewall.FirewallRuleAction.RULE_ALLOW
    this.protocol = rule.protocol ?? 6
    this.remoteAddress = this.resolveIpAddressForDirection(rule)
    let resolvedPort = this.resolvePortForDirection(rule)
    this.localPort = this.ruleDirection === netFirewall.NetFirewallRuleDirection.RULE_IN ? resolvedPort : ''
    this.remotePort = this.ruleDirection === netFirewall.NetFirewallRuleDirection.RULE_OUT ? resolvedPort : ''
  }

  private async loadUserOptions(): Promise<void> {
    try {
      let result = await SystemUserProvider.loadAvailableUserIds()
      this.userOptions = result.users ?? []
    } catch (_err) {
      this.userOptions = []
    }
    this.applyInitialRuleScope()
  }

  private applyInitialRuleScope(): void {
    if (!this.initialRule) {
      this.selectedUserIds = this.getAllAvailableUserIds()
      return
    }
    let ruleUserIds = normalizeFirewallRuleUserIds(getFirewallRuleUserIds(this.initialRule))
    this.selectedUserIds = ruleUserIds.length > 0 ? ruleUserIds : this.getAllAvailableUserIds()
  }

  private getAllAvailableUserIds(): number[] {
    return normalizeFirewallRuleUserIds(this.userOptions.map((item: UserFirewallOption): number => item.userId))
  }

  private getSelectedUserIdsForSave(): number[] {
    return normalizeFirewallRuleUserIds(this.selectedUserIds)
  }

  private resolveRemoteAddress(rule: netFirewall.NetFirewallRule): string {
    if (rule.type === netFirewall.NetFirewallRuleType.RULE_IP) {
      return this.resolveIpAddressForDirection(rule)
    }
    if (rule.type === netFirewall.NetFirewallRuleType.RULE_DOMAIN) {
      return rule.domains?.[0]?.domain ?? ''
    }
    if (rule.type === netFirewall.NetFirewallRuleType.RULE_DNS) {
      return rule.dns?.primaryDns ?? ''
    }
    return ''
  }

  private resolvePort(ports?: netFirewall.NetFirewallPortParams[]): string {
    return FirewallRuleUtils.formatPortParamsForDisplay(ports)
  }

  private resolveIpAddressForDirection(rule: netFirewall.NetFirewallRule): string {
    if (rule.type !== netFirewall.NetFirewallRuleType.RULE_IP) {
      return this.resolveRemoteAddress(rule)
    }
    let ipParams = rule.direction === netFirewall.NetFirewallRuleDirection.RULE_IN ? rule.localIps : rule.remoteIps
    return FirewallRuleUtils.formatIpParamsForDisplay(ipParams)
  }

  private resolvePortForDirection(rule: netFirewall.NetFirewallRule): string {
    if (rule.type !== netFirewall.NetFirewallRuleType.RULE_IP) {
      return ''
    }
    let ports = rule.direction === netFirewall.NetFirewallRuleDirection.RULE_IN ? rule.localPorts : rule.remotePorts
    return this.resolvePort(ports)
  }

  private getIpFieldLabel(): string {
    return this.ruleDirection === netFirewall.NetFirewallRuleDirection.RULE_IN
      ? FirewallDialogStrings.LOCAL_ADDRESS
      : FirewallDialogStrings.REMOTE_ADDRESS
  }

  private parseIpInput(raw: string): DialogParseResult<netFirewall.NetFirewallIpParams[] | undefined> {
    let value = raw.trim()
    if (value.length === 0) {
      return { success: true, value: undefined }
    }
    let rangeParts = value.split('-')
    if (rangeParts.length > 2) {
      return { success: false, errorMessage: FirewallDialogStrings.ERROR_INVALID_IP_RANGE }
    }
    if (rangeParts.length === 2) {
      let startIp = rangeParts[0].trim()
      let endIp = rangeParts[1].trim()
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
          type: 1,
          family: 1,
          startIp: startIp,
          endIp: endIp
        }]
      }
    }
    let cidrParts = value.split('/')
    if (cidrParts.length > 2 || !Ipv4Utils.isValidIpv4(cidrParts[0].trim())) {
      return { success: false, errorMessage: FirewallDialogStrings.ERROR_INVALID_IP }
    }
    if (cidrParts.length === 2) {
      let maskRaw = cidrParts[1].trim()
      if (!/^\d+$/.test(maskRaw)) {
        return { success: false, errorMessage: FirewallDialogStrings.ERROR_INVALID_CIDR_MASK }
      }
      let maskValue = parseInt(maskRaw, 10)
      if (maskValue < 0 || maskValue > 32) {
        return { success: false, errorMessage: FirewallDialogStrings.ERROR_INVALID_CIDR_MASK }
      }
      return {
        success: true,
        value: [{
          type: 1,
          family: 1,
          address: cidrParts[0].trim(),
          mask: maskValue
        }]
      }
    }
    return {
      success: true,
      value: [{
        type: 1,
        family: 1,
        address: value,
        mask: 32
      }]
    }
  }

  private parsePortInput(raw: string, invalidMessage: string): DialogParseResult<netFirewall.NetFirewallPortParams[] | undefined> {
    let value = raw.trim()
    if (value.length === 0) {
      return { success: true, value: undefined }
    }
    if (value.toUpperCase() === FirewallDialogStrings.ALL_VALUE) {
      return { success: false, errorMessage: invalidMessage }
    }
    let tokens = value.split(',')
    let result: netFirewall.NetFirewallPortParams[] = []
    for (let i = 0; i < tokens.length; i++) {
      let token = tokens[i].trim()
      if (token.length === 0) {
        return { success: false, errorMessage: `${FirewallDialogStrings.ERROR_INVALID_PORT_TOKEN}: ${i + 1}` }
      }
      let rangeParts = token.split('-')
      if (rangeParts.length > 2) {
        return { success: false, errorMessage: `${FirewallDialogStrings.ERROR_INVALID_PORT_RANGE}: ${token}` }
      }
      if (rangeParts.length === 1) {
        if (!/^\d+$/.test(token)) {
          return { success: false, errorMessage: `${FirewallDialogStrings.ERROR_INVALID_PORT_TOKEN}: ${token}` }
        }
        let port = parseInt(token, 10)
        if (port < 1 || port > 65535) {
          return { success: false, errorMessage: invalidMessage }
        }
        result.push({ startPort: port, endPort: port })
        continue
      }
      let startRaw = rangeParts[0].trim()
      let endRaw = rangeParts[1].trim()
      if (!/^\d+$/.test(startRaw) || !/^\d+$/.test(endRaw)) {
        return { success: false, errorMessage: `${FirewallDialogStrings.ERROR_INVALID_PORT_RANGE}: ${token}` }
      }
      let startPort = parseInt(startRaw, 10)
      let endPort = parseInt(endRaw, 10)
      if (startPort < 1 || startPort > 65535 || endPort < 1 || endPort > 65535) {
        return { success: false, errorMessage: invalidMessage }
      }
      if (startPort > endPort) {
        return { success: false, errorMessage: `${FirewallDialogStrings.ERROR_INVALID_PORT_RANGE}: ${token}` }
      }
      result.push({ startPort: startPort, endPort: endPort })
    }
    let normalized = result.sort((left: netFirewall.NetFirewallPortParams, right: netFirewall.NetFirewallPortParams): number => {
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
    if ((normalized?.length ?? 0) > this.maxPortItemCount) {
      return { success: false, errorMessage: `${FirewallDialogStrings.ERROR_PORT_ITEM_LIMIT}: ${this.maxPortItemCount}` }
    }
    return { success: true, value: normalized.length > 0 ? normalized : undefined }
  }

  private isValidDomain(value: string): boolean {
    return /^(?:\*\.)?(?=.{1,253}$)(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$/.test(value)
  }

  private validateForm(): string {
    let ruleName = this.ruleName.trim()
    let remoteAddress = this.remoteAddress.trim()
    let portValue = this.ruleDirection === netFirewall.NetFirewallRuleDirection.RULE_IN
      ? this.localPort.trim()
      : this.remotePort.trim()

    if (ruleName.length === 0) {
      return FirewallDialogStrings.RULE_NAME_PLACEHOLDER
    }

    if (remoteAddress.length === 0) {
      if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_DOMAIN) {
        return FirewallDialogStrings.ERROR_DOMAIN_REQUIRED
      }
      if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_DNS) {
        return FirewallDialogStrings.ERROR_DNS_REQUIRED
      }
    }

    if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_IP) {
      let ipResult = this.parseIpInput(remoteAddress)
      if (!ipResult.success) {
        return ipResult.errorMessage ?? FirewallDialogStrings.ERROR_INVALID_IP
      }
      let portResult = this.parsePortInput(
        portValue,
        this.ruleDirection === netFirewall.NetFirewallRuleDirection.RULE_IN
          ? FirewallDialogStrings.ERROR_INVALID_LOCAL_PORT
          : FirewallDialogStrings.ERROR_INVALID_REMOTE_PORT
      )
      if (!portResult.success) {
        return portResult.errorMessage ??
          (this.ruleDirection === netFirewall.NetFirewallRuleDirection.RULE_IN
            ? FirewallDialogStrings.ERROR_INVALID_LOCAL_PORT
            : FirewallDialogStrings.ERROR_INVALID_REMOTE_PORT)
      }
    }

    if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_DOMAIN && !this.isValidDomain(remoteAddress)) {
      return FirewallDialogStrings.ERROR_INVALID_DOMAIN
    }

    if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_DNS && !Ipv4Utils.isValidIpv4(remoteAddress)) {
      return FirewallDialogStrings.ERROR_INVALID_DNS
    }

    if (this.getSelectedUserIdsForSave().length === 0) {
      return FirewallDialogStrings.ERROR_USER_SCOPE_REQUIRED
    }

    return ''
  }

  private handleSubmit(): void {
    let validationMessage = this.validateForm()
    if (validationMessage.length > 0) {
      DialogService.openFailure(this.getUIContext(), validationMessage)
      return
    }

    let rule = this.isEditMode ? this.buildUpdateRule() : this.buildCreateRule()
    this.onConfirm(rule)
    this.closeDialog()
  }

  private closeDialog(): void {
    this.onClose()
  }

  private buildCreateRule(): netFirewall.NetFirewallRule {
    let rule: netFirewall.NetFirewallRule = {
      userId: this.initialRule?.userId ?? AppInfo.DEFAULT_USER_ID,
      name: this.ruleName.trim(),
      direction: this.ruleDirection as netFirewall.NetFirewallRuleDirection,
      action: this.action as netFirewall.FirewallRuleAction,
      type: this.ruleType as netFirewall.NetFirewallRuleType,
      isEnabled: this.initialRule?.isEnabled ?? true,
      description: this.initialRule?.description
    }

    this.applyRuleSpecificFields(rule, this.remoteAddress.trim(), this.localPort.trim(), this.remotePort.trim())
    return attachFirewallRuleUserIds(rule, this.getSelectedUserIdsForSave())
  }

  private buildUpdateRule(): netFirewall.NetFirewallRule {
    let baseRule: netFirewall.NetFirewallRule = {
      userId: this.initialRule?.userId ?? AppInfo.DEFAULT_USER_ID,
      name: this.ruleName.trim(),
      direction: this.ruleDirection as netFirewall.NetFirewallRuleDirection,
      action: this.action as netFirewall.FirewallRuleAction,
      type: this.ruleType as netFirewall.NetFirewallRuleType,
      isEnabled: this.initialRule?.isEnabled ?? true,
      description: this.initialRule?.description
    }
    let originalRule = this.initialRule as FirewallRuleWithKey
    let targetRule = baseRule as FirewallRuleWithKey
    if (typeof originalRule.ruleId === 'number') {
      targetRule.ruleId = originalRule.ruleId
    }
    if (typeof originalRule.id === 'number') {
      targetRule.id = originalRule.id
    }
    if (typeof originalRule.localRuleId === 'string') {
      targetRule.localRuleId = originalRule.localRuleId
    }
    this.applyRuleSpecificFields(baseRule, this.remoteAddress.trim(), this.localPort.trim(), this.remotePort.trim())
    return attachFirewallRuleUserIds(baseRule, this.getSelectedUserIdsForSave())
  }

  private applyRuleSpecificFields(
    rule: netFirewall.NetFirewallRule,
    remoteAddress: string,
    localPort: string,
    remotePort: string
  ): void {
    if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_IP) {
      let ipResult = this.parseIpInput(remoteAddress)
      let portResult = this.parsePortInput(
        this.ruleDirection === netFirewall.NetFirewallRuleDirection.RULE_IN ? localPort : remotePort,
        this.ruleDirection === netFirewall.NetFirewallRuleDirection.RULE_IN
          ? FirewallDialogStrings.ERROR_INVALID_LOCAL_PORT
          : FirewallDialogStrings.ERROR_INVALID_REMOTE_PORT
      )
      if (this.ruleDirection === netFirewall.NetFirewallRuleDirection.RULE_IN) {
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
      rule.protocol = this.protocol
      rule.domains = undefined
      rule.dns = undefined
    } else if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_DOMAIN) {
      rule.domains = [{ domain: remoteAddress, isWildcard: remoteAddress.includes('*') }]
      rule.remoteIps = undefined
      rule.localPorts = undefined
      rule.remotePorts = undefined
      rule.protocol = undefined
      rule.dns = undefined
    } else if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_DNS) {
      rule.dns = { primaryDns: remoteAddress }
      rule.remoteIps = undefined
      rule.localPorts = undefined
      rule.remotePorts = undefined
      rule.protocol = undefined
      rule.domains = undefined
    }
  }

  private getPrimaryButtonText(): string {
    return this.isEditMode ? ActionText.SAVE : ActionText.ADD
  }

  private getTertiaryButtonBackground(): ResourceColor {
    return this.currentTheme === ThemeMode.DARK
      ? 'rgba(255,255,255,0.08)'
      : AppColors.getColors(this.currentTheme).BG_PAGE
  }

  private getSelectedProtocolIndex(): number {
    const protocolIndex = this.protocolValues.indexOf(this.protocol)
    return protocolIndex >= 0 ? protocolIndex : 0
  }

  private getSelectedProtocolLabel(): string {
    return (this.protocolOptions[this.getSelectedProtocolIndex()]?.value as string) ?? FirewallDialogStrings.PROTOCOL_TCP
  }

  private getRuleTypeLabel(): string {
    if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_DOMAIN) {
      return FirewallRuleLabelStrings.DOMAIN_RULE
    }
    if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_DNS) {
      return FirewallRuleLabelStrings.DNS_RULE
    }
    return this.getIpFieldLabel()
  }

  private getRuleTypePlaceholder(): string {
    if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_DOMAIN) {
      return FirewallDialogStrings.DOMAIN_PLACEHOLDER
    }
    if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_DNS) {
      return FirewallDialogStrings.DNS_PLACEHOLDER
    }
    return FirewallDialogStrings.IP_PLACEHOLDER
  }

  @Builder
  private formContent() {
    Column({ space: 16 }) {
      Column({ space: 6 }) {
        Text(FirewallDialogStrings.RULE_NAME)
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        TextInput({ text: this.ruleName, placeholder: FirewallDialogStrings.RULE_NAME_PLACEHOLDER })
          .height(40)
          .fontColor(FormControlUtils.text(this.currentTheme))
          .placeholderColor(FormControlUtils.placeholder(this.currentTheme))
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: AppStyles.DIVIDER_HEIGHT, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .onChange((value: string) => { this.ruleName = value })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 6 }) {
        Text(FirewallDialogStrings.RULE_TYPE)
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        Select([
          { value: FirewallRuleLabelStrings.IP_RULE },
          { value: FirewallRuleLabelStrings.DOMAIN_RULE },
          { value: FirewallRuleLabelStrings.DNS_RULE }
        ])
          .selected(this.ruleType - 1)
          .value(this.ruleType === netFirewall.NetFirewallRuleType.RULE_DOMAIN ? FirewallRuleLabelStrings.DOMAIN_RULE :
            this.ruleType === netFirewall.NetFirewallRuleType.RULE_DNS ? FirewallRuleLabelStrings.DNS_RULE :
            FirewallRuleLabelStrings.IP_RULE)
          .fontColor(FormControlUtils.text(this.currentTheme))
          .textModifier(new TextModifier().fontColor(FormControlUtils.text(this.currentTheme)))
          .arrowModifier(new SymbolGlyphModifier().fontColor([FormControlUtils.selectArrow(this.currentTheme)]))
          .font({ size: AppStyles.FONT_SIZE_BODY })
          .width('100%')
          .height(40)
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: AppStyles.DIVIDER_HEIGHT, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .onSelect((index: number) => { this.ruleType = index + 1 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 6 }) {
        Text(FirewallDialogStrings.RULE_DIRECTION)
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        Select([
          { value: FirewallDialogStrings.DIRECTION_INBOUND },
          { value: FirewallDialogStrings.DIRECTION_OUTBOUND }
        ])
          .selected(this.ruleDirection - 1)
          .value(this.ruleDirection === netFirewall.NetFirewallRuleDirection.RULE_OUT ?
            FirewallDialogStrings.DIRECTION_OUTBOUND :
            FirewallDialogStrings.DIRECTION_INBOUND)
          .fontColor(FormControlUtils.text(this.currentTheme))
          .textModifier(new TextModifier().fontColor(FormControlUtils.text(this.currentTheme)))
          .arrowModifier(new SymbolGlyphModifier().fontColor([FormControlUtils.selectArrow(this.currentTheme)]))
          .font({ size: AppStyles.FONT_SIZE_BODY })
          .width('100%')
          .height(40)
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: AppStyles.DIVIDER_HEIGHT, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .onSelect((index: number) => {
            let nextDirection = index + 1
            if (nextDirection === this.ruleDirection) {
              return
            }
            let currentPort = this.ruleDirection === netFirewall.NetFirewallRuleDirection.RULE_IN ? this.localPort : this.remotePort
            this.ruleDirection = nextDirection
            if (this.ruleDirection === netFirewall.NetFirewallRuleDirection.RULE_IN) {
              this.localPort = currentPort
              this.remotePort = ''
              return
            }
            this.remotePort = currentPort
            this.localPort = ''
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_IP) {
        Column({ space: 6 }) {
          Text(FirewallDialogStrings.PROTOCOL)
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          Select(this.protocolOptions)
            .selected(this.getSelectedProtocolIndex())
            .value(this.getSelectedProtocolLabel())
            .fontColor(FormControlUtils.text(this.currentTheme))
            .textModifier(new TextModifier().fontColor(FormControlUtils.text(this.currentTheme)))
            .arrowModifier(new SymbolGlyphModifier().fontColor([FormControlUtils.selectArrow(this.currentTheme)]))
            .font({ size: AppStyles.FONT_SIZE_BODY })
            .width('100%')
            .height(40)
            .backgroundColor(FormControlUtils.background(this.currentTheme))
            .borderRadius(AppStyles.RADIUS_MD)
            .border({ width: AppStyles.DIVIDER_HEIGHT, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
            .onSelect((index: number) => {
              this.protocol = this.protocolValues[index] ?? this.protocolValues[0]
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      Column({ space: 6 }) {
        Text(this.getRuleTypeLabel())
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        TextInput({
          text: this.remoteAddress,
          placeholder: this.getRuleTypePlaceholder()
        })
          .height(40)
          .fontColor(FormControlUtils.text(this.currentTheme))
          .placeholderColor(FormControlUtils.placeholder(this.currentTheme))
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: AppStyles.DIVIDER_HEIGHT, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .onChange((value: string) => { this.remoteAddress = value })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_IP) {
        Column({ space: 6 }) {
          Text(this.ruleDirection === netFirewall.NetFirewallRuleDirection.RULE_IN
            ? FirewallDialogStrings.LOCAL_PORT
            : FirewallDialogStrings.REMOTE_PORT)
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          TextInput({
            text: this.ruleDirection === netFirewall.NetFirewallRuleDirection.RULE_IN ? this.localPort : this.remotePort,
            placeholder: FirewallDialogStrings.PORT_PLACEHOLDER
          })
            .height(40)
            .fontColor(FormControlUtils.text(this.currentTheme))
            .placeholderColor(FormControlUtils.placeholder(this.currentTheme))
            .backgroundColor(FormControlUtils.background(this.currentTheme))
            .borderRadius(AppStyles.RADIUS_MD)
            .border({ width: AppStyles.DIVIDER_HEIGHT, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
            .onChange((value: string) => {
              if (this.ruleDirection === netFirewall.NetFirewallRuleDirection.RULE_IN) {
                this.localPort = value
                this.remotePort = ''
                return
              }
              this.remotePort = value
              this.localPort = ''
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      Column({ space: 6 }) {
        Text(FirewallDialogStrings.USER_SCOPE)
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)

        if (this.userOptions.length === 0) {
          Text(FirewallUserStrings.NO_ACTIVATED_USERS)
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
            .width('100%')
        } else {
          MultiCheckSelect({
            options: this.userOptions,
            selectedValues: this.selectedUserIds,
            placeholder: FirewallDialogStrings.USER_SCOPE_PLACEHOLDER,
            allLabel: FirewallDialogStrings.ALL_VALUE,
            currentTheme: this.currentTheme,
            onChange: (selectedUserIds: number[]) => {
              this.selectedUserIds = normalizeFirewallRuleUserIds(selectedUserIds)
            }
          })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 6 }) {
        Text(FirewallDialogStrings.ACTION)
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        Select([
          { value: FirewallDialogStrings.ACTION_ALLOW },
          { value: FirewallDialogStrings.ACTION_DENY }
        ])
          .selected(this.action)
          .value(this.action === netFirewall.FirewallRuleAction.RULE_DENY ?
            FirewallDialogStrings.ACTION_DENY :
            FirewallDialogStrings.ACTION_ALLOW)
          .fontColor(FormControlUtils.text(this.currentTheme))
          .textModifier(new TextModifier().fontColor(FormControlUtils.text(this.currentTheme)))
          .arrowModifier(new SymbolGlyphModifier().fontColor([FormControlUtils.selectArrow(this.currentTheme)]))
          .font({ size: AppStyles.FONT_SIZE_BODY })
          .width('100%')
          .height(40)
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: AppStyles.DIVIDER_HEIGHT, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .onSelect((index: number) => { this.action = index })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row({ space: 16 }) {
        Button(ActionText.CANCEL)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .backgroundColor(this.getTertiaryButtonBackground())
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: AppStyles.DIVIDER_HEIGHT, color: AppColors.getColors(this.currentTheme).BORDER, style: BorderStyle.Solid })
          .layoutWeight(1)
          .height(40)
          .onClick(() => {
            this.closeDialog()
          })
        Button(this.getPrimaryButtonText())
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(Color.White)
          .backgroundColor(AppColors.BRAND_PRIMARY)
          .borderRadius(AppStyles.RADIUS_MD)
          .layoutWeight(1)
          .height(40)
          .onClick(() => {
            this.handleSubmit()
          })
      }
      .width('100%')
    }
    .margin({ top: 8 })
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    DetailDialogShell({
      dialogWidth: 620,
      maxBodyHeight: 760,
      currentTheme: this.currentTheme,
      showHeader: false,
      showCloseAction: false,
      onClose: () => {
        this.closeDialog()
      },
      content: () => {
        this.formContent()
      }
    })
  }
}
