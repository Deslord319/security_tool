import { AppColors, AppStyles, Routes } from '../constants/AppConstants'
import { RuleTypeItem } from '../components/RuleTypeItem'
import { DirectionCard } from '../components/DirectionCard'
import { FirewallService } from '../services/FirewallService'
import { netFirewall } from '@kit.NetworkKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

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
  onFirewallToggle: (enabled: boolean) => void = () => {}
  onNavigateToRules: (filterType?: number) => void = () => {}

  aboutToAppear() {
    this.loadData()
  }

  async loadData() {
    this.isLoading = true
    try {
      let status = await FirewallService.getFirewallStatus()
      if (status !== this.firewallEnabled) {
        this.onFirewallToggle(status)
      }
      this.rules = await FirewallService.getAllRules()
      this.updateCounts()
    } catch (err) {
      hilog.error(0x0001, TAG, `loadData failed: ${JSON.stringify(err)}`)
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
    }
  }

  build() {
    Scroll() {
      Column({ space: 24 }) {
        // 页面头部：标题 + 开关
        Row() {
          Column({ space: 4 }) {
            Text('防火墙')
              .fontSize(AppStyles.FONT_SIZE_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.TEXT_PRIMARY)
              .opacity(AppColors.TEXT_PRIMARY_OPACITY)
            Text('通过 netFirewall API 管控网络入站/出站流量，支持 IP、域名、DNS 三种规则类型')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.TEXT_PRIMARY)
              .opacity(AppColors.TEXT_TERTIARY_OPACITY)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Toggle({ type: ToggleType.Switch, isOn: this.firewallEnabled })
            .selectedColor(AppColors.BRAND_PRIMARY)
            .switchPointColor(Color.White)
            .onChange((isOn: boolean) => {
              this.handleToggle(isOn)
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        // 规则类型区域
        Column({ space: 0 }) {
          Text('规则类型')
            .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
            .opacity(AppColors.TEXT_PRIMARY_OPACITY)
            .margin({ bottom: 12 })

          Column() {
            RuleTypeItem({
              label: 'IP 规则',
              description: '基于 IP 地址和端口的访问控制',
              count: this.ipCount,
              iconColor: AppColors.BRAND_PRIMARY,
              iconText: 'IP',
              onPress: () => { this.onNavigateToRules(1) }
            })

            Divider()
              .color(AppColors.BORDER)
              .opacity(AppColors.BORDER_OPACITY)
              .margin({ left: 68 })

            RuleTypeItem({
              label: '域名规则',
              description: '基于域名的访问控制',
              count: this.domainCount,
              iconColor: '#5856D6',
              iconText: '域',
              onPress: () => { this.onNavigateToRules(2) }
            })

            Divider()
              .color(AppColors.BORDER)
              .opacity(AppColors.BORDER_OPACITY)
              .margin({ left: 68 })

            RuleTypeItem({
              label: 'DNS 规则',
              description: '基于 DNS 的访问控制',
              count: this.dnsCount,
              iconColor: '#34C759',
              iconText: 'DN',
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
            .fontColor(AppColors.TEXT_PRIMARY)
            .opacity(AppColors.TEXT_PRIMARY_OPACITY)

          Row({ space: 16 }) {
            DirectionCard({
              label: '入站规则 (RULE_IN)',
              count: this.inCount,
              gradientStart: '#FF9500',
              gradientEnd: '#FFCC00',
              iconText: '入'
            })
              .layoutWeight(1)

            DirectionCard({
              label: '出站规则 (RULE_OUT)',
              count: this.outCount,
              gradientStart: '#0A84FF',
              gradientEnd: '#00C6FF',
              iconText: '出'
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
    .backgroundColor(AppColors.BG_PAGE)
  }
}
