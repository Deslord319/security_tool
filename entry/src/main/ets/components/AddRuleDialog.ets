import { AppColors, AppStyles } from '../constants/AppConstants'
import { netFirewall } from '@kit.NetworkKit'
import { DialogService } from '../utils/DialogService'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { FormControlUtils } from '../utils/FormControlUtils'

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

  @State ruleName: string = ''
  @State ruleType: number = netFirewall.NetFirewallRuleType.RULE_IP
  @State ruleDirection: number = netFirewall.NetFirewallRuleDirection.RULE_IN
  @State protocol: number = 6
  @State remoteAddress: string = ''
  @State localPort: string = ''
  @State remotePort: string = ''
  @State action: number = netFirewall.FirewallRuleAction.RULE_ALLOW
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  aboutToAppear(): void {
    this.applyInitialRule()
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

  private isValidIpv4Address(value: string): boolean {
    let parts = value.split('.')
    if (parts.length !== 4) {
      return false
    }
    return parts.every((segment: string): boolean => {
      if (!/^\d+$/.test(segment)) {
        return false
      }
      let num = parseInt(segment, 10)
      return num >= 0 && num <= 255 && `${num}` === segment
    })
  }

  private isValidIpv4OrCidr(value: string): boolean {
    let parts = value.split('/')
    if (parts.length > 2 || !this.isValidIpv4Address(parts[0].trim())) {
      return false
    }
    if (parts.length === 1) {
      return true
    }
    let mask = parts[1].trim()
    if (!/^\d+$/.test(mask)) {
      return false
    }
    let maskValue = parseInt(mask, 10)
    return maskValue >= 0 && maskValue <= 32
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
      return '请输入规则名称'
    }

    if (remoteAddress.length === 0) {
      if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_DOMAIN) {
        return '请输入域名'
      }
      if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_DNS) {
        return '请输入 DNS 地址'
      }
      return '请输入远端 IP 或 CIDR'
    }

    if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_IP && !this.isValidIpv4OrCidr(remoteAddress)) {
      return '远端 IP 或 CIDR 格式不正确'
    }

    if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_IP && localPort.length > 0 && !this.isValidPort(localPort)) {
      return '本地端口范围必须为 1-65535'
    }

    if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_IP && remotePort.length > 0 && !this.isValidPort(remotePort)) {
      return '远端端口范围必须为 1-65535'
    }

    if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_DOMAIN && !this.isValidDomain(remoteAddress)) {
      return '域名格式不正确'
    }

    if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_DNS && !this.isValidIpv4Address(remoteAddress)) {
      return 'DNS 地址格式不正确'
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
      userId: this.initialRule?.userId ?? 100,
      name: this.ruleName.trim(),
      direction: this.ruleDirection as netFirewall.NetFirewallRuleDirection,
      action: this.action as netFirewall.FirewallRuleAction,
      type: this.ruleType as netFirewall.NetFirewallRuleType,
      isEnabled: this.initialRule?.isEnabled ?? true
    }

    this.applyRuleSpecificFields(rule, this.remoteAddress.trim(), this.localPort.trim(), this.remotePort.trim())
    return rule
  }

  private buildUpdateRule(): netFirewall.NetFirewallRule {
    let baseRule: netFirewall.NetFirewallRule = {
      userId: this.initialRule?.userId ?? 100,
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
    return baseRule
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

  private getDialogTitle(): string {
    return this.isEditMode ? '编辑规则' : '新增规则'
  }

  private getPrimaryButtonText(): string {
    return this.isEditMode ? '保存' : '新增'
  }

  private getRuleTypeLabel(): string {
    if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_DOMAIN) {
      return '域名'
    }
    if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_DNS) {
      return 'DNS 地址'
    }
    return '远端地址'
  }

  private getRuleTypePlaceholder(): string {
    if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_DOMAIN) {
      return '例如 *.example.com'
    }
    if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_DNS) {
      return '例如 8.8.8.8'
    }
    return '例如 0.0.0.0/0'
  }

  build() {
    Column({ space: 16 }) {
      Row() {
        Text(this.getDialogTitle())
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          .layoutWeight(1)
        Text('×')
          .fontSize(20)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          .onClick(() => {
            this.closeDialog()
          })
      }
      .width('100%')

      Column({ space: 6 }) {
        Text('规则名称')
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        TextInput({ text: this.ruleName, placeholder: '请输入规则名称' })
          .height(40)
          .fontColor(FormControlUtils.text(this.currentTheme))
          .placeholderColor(FormControlUtils.placeholder(this.currentTheme))
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .onChange((value: string) => { this.ruleName = value })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 6 }) {
        Text('规则类型')
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        Select([
          { value: 'IP 规则' },
          { value: '域名规则' },
          { value: 'DNS 规则' }
        ])
          .selected(this.ruleType - 1)
          .value(this.ruleType === netFirewall.NetFirewallRuleType.RULE_DOMAIN ? '域名规则' :
            this.ruleType === netFirewall.NetFirewallRuleType.RULE_DNS ? 'DNS 规则' : 'IP 规则')
          .fontColor(FormControlUtils.text(this.currentTheme))
          .font({ size: AppStyles.FONT_SIZE_BODY })
          .width('100%')
          .height(40)
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .onSelect((index: number) => { this.ruleType = index + 1 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 6 }) {
        Text('方向')
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        Select([
          { value: '入站' },
          { value: '出站' }
        ])
          .selected(this.ruleDirection - 1)
          .value(this.ruleDirection === netFirewall.NetFirewallRuleDirection.RULE_OUT ? '出站' : '入站')
          .fontColor(FormControlUtils.text(this.currentTheme))
          .font({ size: AppStyles.FONT_SIZE_BODY })
          .width('100%')
          .height(40)
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .onSelect((index: number) => { this.ruleDirection = index + 1 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_IP) {
        Column({ space: 6 }) {
          Text('协议')
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          Select([
            { value: 'TCP' },
            { value: 'UDP' },
            { value: 'ICMP' }
          ])
            .selected(this.protocol === 17 ? 1 : this.protocol === 1 ? 2 : 0)
            .value(this.protocol === 17 ? 'UDP' : this.protocol === 1 ? 'ICMP' : 'TCP')
            .fontColor(FormControlUtils.text(this.currentTheme))
            .font({ size: AppStyles.FONT_SIZE_BODY })
            .width('100%')
            .height(40)
            .backgroundColor(FormControlUtils.background(this.currentTheme))
            .borderRadius(AppStyles.RADIUS_MD)
            .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
            .onSelect((index: number) => {
              let protocols: number[] = [6, 17, 1]
              this.protocol = protocols[index]
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
          .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .onChange((value: string) => { this.remoteAddress = value })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_IP) {
        Column({ space: 6 }) {
          Text('本地端口')
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          TextInput({ text: this.localPort, placeholder: '例如 443' })
            .height(40)
            .fontColor(FormControlUtils.text(this.currentTheme))
            .placeholderColor(FormControlUtils.placeholder(this.currentTheme))
            .backgroundColor(FormControlUtils.background(this.currentTheme))
            .borderRadius(AppStyles.RADIUS_MD)
            .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
            .type(InputType.Number)
            .onChange((value: string) => { this.localPort = value })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Column({ space: 6 }) {
          Text('远端端口')
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          TextInput({ text: this.remotePort, placeholder: '例如 443' })
            .height(40)
            .fontColor(FormControlUtils.text(this.currentTheme))
            .placeholderColor(FormControlUtils.placeholder(this.currentTheme))
            .backgroundColor(FormControlUtils.background(this.currentTheme))
            .borderRadius(AppStyles.RADIUS_MD)
            .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
            .type(InputType.Number)
            .onChange((value: string) => { this.remotePort = value })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      Column({ space: 6 }) {
        Text('动作')
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        Select([
          { value: '允许' },
          { value: '阻止' }
        ])
          .selected(this.action)
          .value(this.action === netFirewall.FirewallRuleAction.RULE_DENY ? '阻止' : '允许')
          .fontColor(FormControlUtils.text(this.currentTheme))
          .font({ size: AppStyles.FONT_SIZE_BODY })
          .width('100%')
          .height(40)
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .onSelect((index: number) => { this.action = index })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row({ space: 16 }) {
        Button('取消')
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: 1, color: AppColors.getColors(this.currentTheme).BORDER, style: BorderStyle.Solid })
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
    .padding(32)
    .constraintSize({ maxWidth: 600 })
    .width('90%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_XL)
  }
}
