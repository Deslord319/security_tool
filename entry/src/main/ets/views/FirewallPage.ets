import { AppColors, AppStyles, Routes } from '../constants/AppConstants'
import { RuleTypeItem } from '../components/RuleTypeItem'
import { DirectionCard } from '../components/DirectionCard'
import { BackNavButton } from '../components/BackNavButton'
import { FirewallService } from '../services/FirewallService'
import { FirewallToggleAuthService } from '../services/FirewallToggleAuthService'
import { netFirewall } from '@kit.NetworkKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { FirewallToggleRejectReason } from '../models/DataModels'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'

const TAG = 'FirewallPage'

@Component
export struct FirewallPage {
  @Prop firewallEnabled: boolean = false
  @State rules: netFirewall.NetFirewallRule[] = []
  @State ipCount: number = 0
  @State domainCount: number = 0
  @State dnsCount: number = 0
  @State inCount: number = 0
  @State outCount: number = 0
  @State isLoading: boolean = false
  @State isToggleProcessing: boolean = false
  @State firewallSwitchValue: boolean = false
  @State serviceErrorText: string = ''
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  onFirewallToggle: (enabled: boolean) => void = () => {}
  onNavigateToRules: (filterType?: number) => void = () => {}
  onBack: () => void = () => {}

  aboutToAppear() {
    this.firewallSwitchValue = this.firewallEnabled
    this.loadData()
  }

  async loadData() {
    this.isLoading = true
    this.serviceErrorText = ''
    try {
      let status = await FirewallService.getFirewallStatus()
      this.firewallSwitchValue = status
      let statusError = FirewallService.getLastErrorText()
      if (statusError.length > 0) {
        this.serviceErrorText = statusError
      }
      if (status !== this.firewallEnabled) {
        this.onFirewallToggle(status)
      }
      this.rules = await FirewallService.getAllRules()
      let rulesError = FirewallService.getLastErrorText()
      if (rulesError.length > 0) {
        this.serviceErrorText = rulesError
      }
      this.updateCounts()
    } catch (err) {
      hilog.error(0x0001, TAG, `loadData failed: ${JSON.stringify(err)}`)
      this.serviceErrorText = '读取防火墙数据失败'
    }
    if (this.serviceErrorText.length > 0) {
      promptAction.showToast({ message: `防火墙服务异常：${this.serviceErrorText}` })
    }
    this.isLoading = false
  }

  updateCounts() {
    this.ipCount = FirewallService.countByType(this.rules, netFirewall.NetFirewallRuleType.RULE_IP)
    this.domainCount = FirewallService.countByType(this.rules, netFirewall.NetFirewallRuleType.RULE_DOMAIN)
    this.dnsCount = FirewallService.countByType(this.rules, netFirewall.NetFirewallRuleType.RULE_DNS)
    this.inCount = FirewallService.countByDirection(this.rules, netFirewall.NetFirewallRuleDirection.RULE_IN)
    this.outCount = FirewallService.countByDirection(this.rules, netFirewall.NetFirewallRuleDirection.RULE_OUT)
  }

  async handleToggle(isOn: boolean) {
    let success = await FirewallService.setFirewallEnabled(isOn)
    if (success) {
      this.onFirewallToggle(isOn)
      this.serviceErrorText = ''
      return
    }
    let error = FirewallService.getLastErrorText()
    this.serviceErrorText = error.length > 0 ? error : '设置防火墙状态失败'
    promptAction.showToast({ message: `防火墙操作失败：${this.serviceErrorText}` })
  }

  async handleToggleWithAuth(isOn: boolean) {
    if (this.isToggleProcessing) {
      this.firewallSwitchValue = this.firewallEnabled
      return
    }
    let currentEnabled = this.firewallEnabled
    if (isOn === currentEnabled) {
      this.firewallSwitchValue = currentEnabled
      return
    }

    this.isToggleProcessing = true
    try {
      let context = getContext(this) as common.UIAbilityContext
      let result = await FirewallToggleAuthService.executeToggle(context, currentEnabled, isOn)
      if (result.success) {
        this.firewallSwitchValue = isOn
        this.onFirewallToggle(isOn)
        this.serviceErrorText = ''
        return
      }

      this.firewallSwitchValue = currentEnabled
      this.onFirewallToggle(currentEnabled)
      this.serviceErrorText = this.buildToggleFailedMessage(result.reason, result.lockRemainingSec)
      promptAction.showToast({ message: this.serviceErrorText })
    } catch (err) {
      this.firewallSwitchValue = currentEnabled
      this.onFirewallToggle(currentEnabled)
      this.serviceErrorText = '防火墙状态更新失败'
      promptAction.showToast({ message: this.serviceErrorText })
      hilog.error(0x0001, TAG, `handleToggleWithAuth failed: ${JSON.stringify(err)}`)
    } finally {
      this.isToggleProcessing = false
    }
  }

  private buildToggleFailedMessage(
    reason: FirewallToggleRejectReason | undefined,
    lockRemainingSec: number | undefined
  ): string {
    switch (reason) {
      case 'lockout':
        return `PIN认证失败次数过多，请在${lockRemainingSec ?? 60}秒后重试`
      case 'pin_unavailable':
        return '系统PIN不可用，请先在系统设置中启用PIN码'
      case 'pin_failed':
        return 'PIN认证失败，已取消防火墙状态变更'
      case 'policy_apply_failed': {
        let error = FirewallService.getLastErrorText()
        return error.length > 0 ? error : '防火墙策略下发失败'
      }
      default:
        return '防火墙状态更新失败'
    }
  }

  build() {
    Scroll() {
      Column({ space: 24 }) {
        // 页面头部：标题 + 开关
        Row() {
          Row({ space: 8 }) {
            BackNavButton({
              onBack: () => {
                this.onBack()
              }
            })

            Column({ space: 4 }) {
              Text('防火墙管理')
                .fontSize(AppStyles.FONT_SIZE_TITLE)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
              Text('管控网络入站/出站流量，支持 IP、域名和DNS 三种规则类型配置')
                .fontSize(AppStyles.FONT_SIZE_BODY)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .layoutWeight(1)
          .alignItems(VerticalAlign.Top)

          Toggle({ type: ToggleType.Switch, isOn: this.firewallSwitchValue })
            .selectedColor(AppColors.BRAND_PRIMARY)
            .switchPointColor(Color.White)
            .enabled(!this.isToggleProcessing)
            .onChange((isOn: boolean) => {
              this.handleToggleWithAuth(isOn)
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        if (this.serviceErrorText.length > 0) {
          Row({ space: 8 }) {
            Text('⚠')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.WARNING)
            Text(`防火墙服务异常：${this.serviceErrorText}`)
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontColor(AppColors.getColors(this.currentTheme).TAG_ORANGE_TEXT)
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .backgroundColor(AppColors.getColors(this.currentTheme).TAG_ORANGE_BG)
          .borderRadius(AppStyles.RADIUS_MD)
        }

        // 规则类型区域
        Column({ space: 0 }) {
          Text('规则类型')
            .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
            .margin({ bottom: 12 })

          Column() {
            RuleTypeItem({
              label: 'IP 规则',
              description: '基于 IP 地址和端口的访问控制',
              count: this.ipCount,
              iconColor: AppColors.BRAND_PRIMARY,
              icon: $r('app.media.network'),
              onPress: () => { this.onNavigateToRules(1) }
            })

            Divider()
              .color(AppColors.getColors(this.currentTheme).BORDER)
              .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
              .margin({ left: 68 })

            RuleTypeItem({
              label: '域名规则',
              description: '基于域名的访问控制',
              count: this.domainCount,
              iconColor: '#5856D6',
              icon: $r('app.media.globe'),
              onPress: () => { this.onNavigateToRules(2) }
            })

            Divider()
              .color(AppColors.getColors(this.currentTheme).BORDER)
              .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
              .margin({ left: 68 })

            RuleTypeItem({
              label: 'DNS 规则',
              description: '基于 DNS 的访问控制',
              count: this.dnsCount,
              iconColor: '#34C759',
              icon: $r('app.media.server'),
              onPress: () => { this.onNavigateToRules(3) }
            })
          }
          .borderRadius(AppStyles.RADIUS_LG)
          .clip(true)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        // 流量方向区域
        Column({ space: 12 }) {
          Text('流量方向')
            .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

          Row({ space: 16 }) {
            DirectionCard({
              label: '入站规则 (RULE_IN)',
              count: this.inCount,
              gradientStart: '#FF9500',
              gradientEnd: '#FFCC00',
              icon: $r('app.media.arrow_down')
            })
              .layoutWeight(1)

            DirectionCard({
              label: '出站规则 (RULE_OUT)',
              count: this.outCount,
              gradientStart: '#0A84FF',
              gradientEnd: '#00C6FF',
              icon: $r('app.media.arrow_up')
            })
              .layoutWeight(1)
          }
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .padding(AppStyles.PADDING_LG)
      .width('100%')
    }
    .align(Alignment.Top)
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }
}
