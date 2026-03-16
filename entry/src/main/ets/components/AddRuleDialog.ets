import { AppColors, AppStyles } from '../constants/AppConstants'
import { netFirewall } from '@kit.NetworkKit'
import { promptAction } from '@kit.ArkUI'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { FormControlUtils } from '../utils/FormControlUtils'

@CustomDialog
export struct AddRuleDialog {
  controller: CustomDialogController
  onConfirm: (rule: netFirewall.NetFirewallRule) => void = () => {}

  @State ruleName: string = ''
  @State ruleType: number = 1 // 1=IP, 2=DOMAIN, 3=DNS
  @State ruleDirection: number = 1 // 1=IN, 2=OUT
  @State protocol: number = 6 // 6=TCP, 17=UDP, 1=ICMP
  @State remoteAddress: string = ''
  @State remotePort: string = ''
  @State action: number = 0 // 0=ALLOW, 1=DENY
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

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
    let remotePort = this.remotePort.trim()

    if (ruleName.length === 0) {
      return '请输入规则名称'
    }

    if (remoteAddress.length === 0) {
      if (this.ruleType === 2) {
        return '请输入域名'
      }
      if (this.ruleType === 3) {
        return '请输入 DNS 地址'
      }
      return '请输入 IP 地址或 CIDR'
    }

    if (this.ruleType === 1 && !this.isValidIpv4OrCidr(remoteAddress)) {
      return '请输入合法的 IP 地址或 CIDR'
    }

    if (this.ruleType === 1 && remotePort.length > 0 && !this.isValidPort(remotePort)) {
      return '端口范围应为 1-65535'
    }

    if (this.ruleType === 2 && !this.isValidDomain(remoteAddress)) {
      return '请输入合法的域名'
    }

    if (this.ruleType === 3 && !this.isValidIpv4Address(remoteAddress)) {
      return '请输入合法的 DNS 地址'
    }

    return ''
  }

  private handleSubmit(): void {
    let validationMessage = this.validateForm()
    if (validationMessage.length > 0) {
      promptAction.showToast({ message: validationMessage })
      return
    }

    let rule = this.buildRule()
    this.onConfirm(rule)
    this.controller.close()
  }

  buildRule(): netFirewall.NetFirewallRule {
    let ruleName = this.ruleName.trim()
    let remoteAddress = this.remoteAddress.trim()
    let remotePort = this.remotePort.trim()
    let rule: netFirewall.NetFirewallRule = {
      userId: 100,
      name: ruleName,
      direction: this.ruleDirection as netFirewall.NetFirewallRuleDirection,
      action: this.action as netFirewall.FirewallRuleAction,
      type: this.ruleType as netFirewall.NetFirewallRuleType,
      isEnabled: true
    }

    if (this.ruleType === 1) {
      // IP 规则
      if (remoteAddress) {
        let parts = remoteAddress.split('/')
        let ip: netFirewall.NetFirewallIpParams = {
          type: parts.length > 1 ? 1 : 1,
          family: 1,
          address: parts[0].trim(),
          mask: parts.length > 1 ? parseInt(parts[1].trim(), 10) : 32
        }
        rule.remoteIps = [ip]
      }
      if (remotePort) {
        let portNum = parseInt(remotePort, 10)
        rule.remotePorts = [{ startPort: portNum, endPort: portNum }]
      }
      rule.protocol = this.protocol
    } else if (this.ruleType === 2) {
      // 域名规则
      if (remoteAddress) {
        rule.domains = [{ domain: remoteAddress, isWildcard: remoteAddress.includes('*') }]
      }
    } else if (this.ruleType === 3) {
      // DNS 规则
      if (remoteAddress) {
        rule.dns = { primaryDns: remoteAddress }
      }
    }

    return rule
  }

  build() {
    Column({ space: 16 }) {
      // 标题 + 关闭按钮
      Row() {
        Text('添加防火墙规则')
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
            this.controller.close()
          })
      }
      .width('100%')

      // 规则名称
      Column({ space: 6 }) {
        Text('规则名称')
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        TextInput({ placeholder: '输入规则名称' })
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

      // 规则类型
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
          .selected(0)
          .value('IP 规则')
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

      // 方向
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
          .selected(0)
          .value('入站')
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

      // 协议（仅 IP 规则显示）
      if (this.ruleType === 1) {
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
            .selected(0)
            .value('TCP')
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

      // 远程地址
      Column({ space: 6 }) {
        Text(this.ruleType === 2 ? '域名' : this.ruleType === 3 ? 'DNS 服务器' : '远程地址')
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        TextInput({
          placeholder: this.ruleType === 2 ? '例: *.example.com' :
            this.ruleType === 3 ? '例: 8.8.8.8' : '例: 0.0.0.0/0'
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

      // 远程端口（仅 IP 规则显示）
      if (this.ruleType === 1) {
        Column({ space: 6 }) {
          Text('远程端口')
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          TextInput({ placeholder: '例: 443' })
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

      // 策略
      Column({ space: 6 }) {
        Text('策略')
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        Select([
          { value: '允许' },
          { value: '拒绝' }
        ])
          .selected(0)
          .value('允许')
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

      // 按钮区域
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
            this.controller.close()
          })
        Button('添加')
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
