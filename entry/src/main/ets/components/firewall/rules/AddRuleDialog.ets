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
import { UserFirewallOption } from '../../../models/firewall/firewall_service_contracts'
import {
  attachFirewallRuleUserIds,
  getFirewallRuleUserIds
} from '../../../models/DataModels'
import { normalizeFirewallRuleUserIds } from '../../../viewmodels/firewall/rules/FirewallRulesViewModel'

interface FirewallRuleWithKey extends netFirewall.NetFirewallRule {
  id?: number
  ruleId?: number
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
    this.remoteAddress = this.resolveRemoteAddress(rule)
    this.localPort = this.resolvePort(rule.localPorts)
    this.remotePort = this.resolvePort(rule.remotePorts)
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
      let ip = rule.remoteIps?.[0]
      if (!ip?.address) {
        return ''
      }
      let mask = ip.mask
      return mask !== undefined && mask < 32 ? `${ip.address}/${mask}` : ip.address
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
    let port = ports?.[0]
    if (!port) {
      return ''
    }
    if (port.endPort !== undefined && port.endPort !== port.startPort) {
      return `${port.startPort}-${port.endPort}`
    }
    return `${port.startPort}`
  }

  private isValidPort(value: string): boolean {
    if (!/^\d+$/.test(value)) {
      return false
    }
    let port = parseInt(value, 10)
    return port >= 1 && port <= 65535
  }

  private isValidDomain(value: string): boolean {
    return /^(?:\*\.)?(?=.{1,253}$)(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$/.test(value)
  }

  private validateForm(): string {
    let ruleName = this.ruleName.trim()
    let remoteAddress = this.remoteAddress.trim()
    let localPort = this.localPort.trim()
    let remotePort = this.remotePort.trim()

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
      return FirewallDialogStrings.ERROR_IP_REQUIRED
    }

    if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_IP && !Ipv4Utils.isValidIpv4OrCidr(remoteAddress)) {
      return FirewallDialogStrings.ERROR_INVALID_IP
    }

    if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_IP && localPort.length > 0 && !this.isValidPort(localPort)) {
      return FirewallDialogStrings.ERROR_INVALID_LOCAL_PORT
    }

    if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_IP && remotePort.length > 0 && !this.isValidPort(remotePort)) {
      return FirewallDialogStrings.ERROR_INVALID_REMOTE_PORT
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
      let parts = remoteAddress.split('/')
      rule.remoteIps = [{
        type: 1,
        family: 1,
        address: parts[0].trim(),
        mask: parts.length > 1 ? parseInt(parts[1].trim(), 10) : 32
      }]
      if (localPort.length > 0) {
        let localPortNum = parseInt(localPort, 10)
        rule.localPorts = [{ startPort: localPortNum, endPort: localPortNum }]
      } else {
        rule.localPorts = undefined
      }
      if (remotePort.length > 0) {
        let remotePortNum = parseInt(remotePort, 10)
        rule.remotePorts = [{ startPort: remotePortNum, endPort: remotePortNum }]
      } else {
        rule.remotePorts = undefined
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
    return FirewallDialogStrings.REMOTE_ADDRESS
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
          .onSelect((index: number) => { this.ruleDirection = index + 1 })
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
          Text(FirewallDialogStrings.LOCAL_PORT)
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          TextInput({ text: this.localPort, placeholder: FirewallDialogStrings.PORT_PLACEHOLDER })
            .height(40)
            .fontColor(FormControlUtils.text(this.currentTheme))
            .placeholderColor(FormControlUtils.placeholder(this.currentTheme))
            .backgroundColor(FormControlUtils.background(this.currentTheme))
            .borderRadius(AppStyles.RADIUS_MD)
            .border({ width: AppStyles.DIVIDER_HEIGHT, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
            .type(InputType.Number)
            .onChange((value: string) => { this.localPort = value })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Column({ space: 6 }) {
          Text(FirewallDialogStrings.REMOTE_PORT)
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          TextInput({ text: this.remotePort, placeholder: FirewallDialogStrings.PORT_PLACEHOLDER })
            .height(40)
            .fontColor(FormControlUtils.text(this.currentTheme))
            .placeholderColor(FormControlUtils.placeholder(this.currentTheme))
            .backgroundColor(FormControlUtils.background(this.currentTheme))
            .borderRadius(AppStyles.RADIUS_MD)
            .border({ width: AppStyles.DIVIDER_HEIGHT, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
            .type(InputType.Number)
            .onChange((value: string) => { this.remotePort = value })
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
  }

  build() {
    DetailDialogShell({
      dialogWidth: 620,
      maxBodyHeight: 620,
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
