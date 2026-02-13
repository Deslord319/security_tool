import { AppColors, AppStyles } from '../constants/AppConstants'
import { netFirewall } from '@kit.NetworkKit'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'

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

  buildRule(): netFirewall.NetFirewallRule {
    let rule: netFirewall.NetFirewallRule = {
      userId: 100,
      name: this.ruleName,
      direction: this.ruleDirection as netFirewall.NetFirewallRuleDirection,
      action: this.action as netFirewall.FirewallRuleAction,
      type: this.ruleType as netFirewall.NetFirewallRuleType,
      isEnabled: true
    }

    if (this.ruleType === 1) {
      // IP 规则
      if (this.remoteAddress) {
        let parts = this.remoteAddress.split('/')
        let ip: netFirewall.NetFirewallIpParams = {
          type: parts.length > 1 ? 1 : 1,
          family: 1,
          address: parts[0],
          mask: parts.length > 1 ? parseInt(parts[1]) : 32
        }
        rule.remoteIps = [ip]
      }
      if (this.remotePort) {
        let portNum = parseInt(this.remotePort)
        if (!isNaN(portNum)) {
          rule.remotePorts = [{ startPort: portNum, endPort: portNum }]
        }
      }
      rule.protocol = this.protocol
    } else if (this.ruleType === 2) {
      // 域名规则
      if (this.remoteAddress) {
        rule.domains = [{ domain: this.remoteAddress, isWildcard: this.remoteAddress.includes('*') }]
      }
    } else if (this.ruleType === 3) {
      // DNS 规则
      if (this.remoteAddress) {
        rule.dns = { primaryDns: this.remoteAddress }
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
        Text('\u00D7')
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
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: 1, color: AppColors.getColors(this.currentTheme).BORDER, style: BorderStyle.Solid })
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
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .font({ size: AppStyles.FONT_SIZE_BODY })
          .width('100%')
          .height(40)
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
          .borderRadius(AppStyles.RADIUS_MD)
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
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .font({ size: AppStyles.FONT_SIZE_BODY })
          .width('100%')
          .height(40)
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
          .borderRadius(AppStyles.RADIUS_MD)
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
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .font({ size: AppStyles.FONT_SIZE_BODY })
            .width('100%')
            .height(40)
            .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
            .borderRadius(AppStyles.RADIUS_MD)
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
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: 1, color: AppColors.getColors(this.currentTheme).BORDER, style: BorderStyle.Solid })
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
            .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
            .borderRadius(AppStyles.RADIUS_MD)
            .border({ width: 1, color: AppColors.getColors(this.currentTheme).BORDER, style: BorderStyle.Solid })
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
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .font({ size: AppStyles.FONT_SIZE_BODY })
          .width('100%')
          .height(40)
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
          .borderRadius(AppStyles.RADIUS_MD)
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
            if (this.ruleName) {
              let rule = this.buildRule()
              this.onConfirm(rule)
              this.controller.close()
            }
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
