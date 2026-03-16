import { AppColors, AppStyles } from '../constants/AppConstants'
import { FirewallService } from '../services/FirewallService'
import { AddRuleDialog } from '../components/AddRuleDialog'
import { UserFirewallControlDialog } from '../components/UserFirewallControlDialog'
import { BackNavButton } from '../components/BackNavButton'
import { DirectionCard } from '../components/DirectionCard'
import { netFirewall } from '@kit.NetworkKit'
import { promptAction } from '@kit.ArkUI'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { HoverUtils } from '../utils/HoverUtils'

@Component
export struct FirewallRulesPage {
  @State rules: netFirewall.NetFirewallRule[] = []
  @State currentTab: number = 0
  @State isLoading: boolean = false
  @State hoveredRuleIndex: number = -1
  onBack: () => void = () => {}
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  private addRuleDialogController: CustomDialogController = new CustomDialogController({
    builder: AddRuleDialog({
      onConfirm: (rule: netFirewall.NetFirewallRule) => {
        this.handleAddRule(rule)
      }
    }),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Center
  })

  private userFirewallControlDialogController: CustomDialogController = new CustomDialogController({
    builder: UserFirewallControlDialog({
      onActionCompleted: () => {
        this.loadRules()
      }
    }),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Center
  })

  aboutToAppear() {
    this.loadRules()
  }

  async loadRules() {
    this.isLoading = true
    this.rules = await FirewallService.getAllRules()
    this.isLoading = false
  }

  async handleAddRule(rule: netFirewall.NetFirewallRule) {
    let ruleId = await FirewallService.addRule(rule)
    if (ruleId > 0) {
      promptAction.showToast({ message: '规则添加成功' })
      this.loadRules()
    } else {
      let errorKind = FirewallService.getLastErrorKind()
      if (errorKind === 'invalid_argument') {
        promptAction.showToast({ message: '规则参数不合法，请检查输入' })
        return
      }
      if (errorKind === 'permission') {
        promptAction.showToast({ message: '规则添加失败，请检查权限和企业管理员状态' })
        return
      }
      promptAction.showToast({ message: '规则添加失败，请稍后重试' })
    }
  }

  async handleDeleteRule(ruleId: number) {
    let success = await FirewallService.removeRule(ruleId)
    if (success) {
      promptAction.showToast({ message: '规则已删除' })
      this.loadRules()
    } else {
      promptAction.showToast({ message: '删除失败' })
    }
  }

  getFilteredRules(): netFirewall.NetFirewallRule[] {
    if (this.currentTab === 0) {
      return this.rules
    }
    let typeMap: netFirewall.NetFirewallRuleType[] = [
      netFirewall.NetFirewallRuleType.RULE_IP,
      netFirewall.NetFirewallRuleType.RULE_IP,
      netFirewall.NetFirewallRuleType.RULE_DOMAIN,
      netFirewall.NetFirewallRuleType.RULE_DNS
    ]
    return this.rules.filter((r: netFirewall.NetFirewallRule) => r.type === typeMap[this.currentTab])
  }

  countRulesByType(type: netFirewall.NetFirewallRuleType): number {
    return this.rules.filter((r: netFirewall.NetFirewallRule) => r.type === type).length
  }

  countRulesByDirection(direction: netFirewall.NetFirewallRuleDirection): number {
    return this.rules.filter((r: netFirewall.NetFirewallRule) => r.direction === direction).length
  }

  getRuleTypeLabel(type: netFirewall.NetFirewallRuleType): string {
    switch (type) {
      case netFirewall.NetFirewallRuleType.RULE_IP:
        return 'IP 规则'
      case netFirewall.NetFirewallRuleType.RULE_DOMAIN:
        return '域名规则'
      case netFirewall.NetFirewallRuleType.RULE_DNS:
        return 'DNS 规则'
      default:
        return '未知规则'
    }
  }

  getRuleTypeBgColor(type: netFirewall.NetFirewallRuleType): string {
    switch (type) {
      case netFirewall.NetFirewallRuleType.RULE_IP:
        return AppColors.getColors(this.currentTheme).TAG_BLUE_BG
      case netFirewall.NetFirewallRuleType.RULE_DOMAIN:
        return AppColors.getColors(this.currentTheme).TAG_PURPLE_BG
      case netFirewall.NetFirewallRuleType.RULE_DNS:
        return AppColors.getColors(this.currentTheme).TAG_GREEN_BG
      default:
        return AppColors.getColors(this.currentTheme).TAG_GRAY_BG
    }
  }

  getRuleTypeTextColor(type: netFirewall.NetFirewallRuleType): string {
    switch (type) {
      case netFirewall.NetFirewallRuleType.RULE_IP:
        return AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT
      case netFirewall.NetFirewallRuleType.RULE_DOMAIN:
        return AppColors.getColors(this.currentTheme).TAG_PURPLE_TEXT
      case netFirewall.NetFirewallRuleType.RULE_DNS:
        return AppColors.getColors(this.currentTheme).TAG_GREEN_TEXT
      default:
        return AppColors.getColors(this.currentTheme).TAG_GRAY_TEXT
    }
  }

  getRuleIcon(type: netFirewall.NetFirewallRuleType): Resource {
    switch (type) {
      case netFirewall.NetFirewallRuleType.RULE_IP:
        return $r('app.media.network')
      case netFirewall.NetFirewallRuleType.RULE_DOMAIN:
        return $r('app.media.globe')
      case netFirewall.NetFirewallRuleType.RULE_DNS:
        return $r('app.media.server')
      default:
        return $r('app.media.firewall')
    }
  }

  getDirectionLabel(dir: netFirewall.NetFirewallRuleDirection): string {
    return dir === netFirewall.NetFirewallRuleDirection.RULE_IN ? '入站' : '出站'
  }

  getActionLabel(action: netFirewall.FirewallRuleAction): string {
    return action === netFirewall.FirewallRuleAction.RULE_ALLOW ? '允许' : '拒绝'
  }

  getActionBgColor(action: netFirewall.FirewallRuleAction): string {
    return action === netFirewall.FirewallRuleAction.RULE_ALLOW ? AppColors.getColors(this.currentTheme).TAG_GREEN_BG : AppColors.getColors(this.currentTheme).TAG_RED_BG
  }

  getActionTextColor(action: netFirewall.FirewallRuleAction): string {
    return action === netFirewall.FirewallRuleAction.RULE_ALLOW ? AppColors.getColors(this.currentTheme).TAG_GREEN_TEXT : AppColors.getColors(this.currentTheme).TAG_RED_TEXT
  }

  getRuleAddress(rule: netFirewall.NetFirewallRule): string {
    if (rule.type === netFirewall.NetFirewallRuleType.RULE_IP && rule.remoteIps && rule.remoteIps.length > 0) {
      let ip = rule.remoteIps[0]
      return ip.mask !== undefined && ip.mask < 32 ? `${ip.address}/${ip.mask}` : (ip.address ?? '-')
    }
    if (rule.type === netFirewall.NetFirewallRuleType.RULE_DOMAIN && rule.domains && rule.domains.length > 0) {
      return rule.domains[0].domain ?? '-'
    }
    if (rule.type === netFirewall.NetFirewallRuleType.RULE_DNS && rule.dns) {
      return rule.dns.primaryDns ?? '-'
    }
    return '-'
  }

  getRulePort(rule: netFirewall.NetFirewallRule): string {
    if (rule.remotePorts && rule.remotePorts.length > 0) {
      let port = rule.remotePorts[0]
      return port.startPort === port.endPort ? `${port.startPort}` : `${port.startPort}-${port.endPort}`
    }
    return 'ALL'
  }

  getProtocolLabel(rule: netFirewall.NetFirewallRule): string {
    if (rule.protocol === undefined || rule.protocol === null) {
      return 'ALL'
    }
    switch (rule.protocol) {
      case 6:
        return 'TCP'
      case 17:
        return 'UDP'
      case 1:
        return 'ICMP'
      default:
        return 'ALL'
    }
  }

  getTabCount(index: number): number {
    switch (index) {
      case 0:
        return this.rules.length
      case 1:
        return this.countRulesByType(netFirewall.NetFirewallRuleType.RULE_IP)
      case 2:
        return this.countRulesByType(netFirewall.NetFirewallRuleType.RULE_DOMAIN)
      case 3:
        return this.countRulesByType(netFirewall.NetFirewallRuleType.RULE_DNS)
      default:
        return 0
    }
  }

  @Builder
  tabBuilder(title: string, index: number) {
    Row({ space: 8 }) {
      Text(title)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(this.currentTab === index ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.currentTab === index ? AppColors.BRAND_PRIMARY : AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(this.currentTab === index ? 1 : AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)

      Text(`${this.getTabCount(index)}`)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.currentTab === index ? Color.White : AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(this.currentTab === index ? 1 : AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .padding({ left: 8, right: 8, top: 2, bottom: 2 })
        .backgroundColor(this.currentTab === index ? AppColors.BRAND_PRIMARY : AppColors.getColors(this.currentTheme).BG_COMPONENT)
        .borderRadius(10)
    }
    .padding({ left: 14, right: 14, top: 8, bottom: 8 })
    .backgroundColor(this.currentTab === index ? AppColors.getColors(this.currentTheme).BG_CARD : Color.Transparent)
    .borderRadius(AppStyles.RADIUS_MD)
  }

  @Builder
  summaryCard(index: number, label: string, value: string, icon: Resource, color: string) {
    Blank()
      .width(0)
      .height(0)
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Row() {
          Column({ space: 4 }) {
            Row({ space: 8 }) {
              BackNavButton({
                onBack: () => {
                  this.onBack()
                }
              })
              Text('防火墙规则')
                .fontSize(AppStyles.FONT_SIZE_TITLE)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            }

            Text('按规则类型快速筛选，并直接查看方向、协议、地址与端口。')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Button('\u6309\u7528\u6237ID\u63a7\u5236')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.BRAND_PRIMARY)
            .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
            .borderRadius(AppStyles.RADIUS_MD)
            .border({ width: 1, color: AppColors.BRAND_PRIMARY })
            .height(36)
            .margin({ right: 8 })
            .onClick(() => {
              this.userFirewallControlDialogController.open()
            })

          Button('+ 添加规则')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(Color.White)
            .backgroundColor(AppColors.BRAND_PRIMARY)
            .borderRadius(AppStyles.RADIUS_MD)
            .height(36)
            .onClick(() => {
              this.addRuleDialogController.open()
            })
        }
        .width('100%')

        Row({ space: 16 }) {
          DirectionCard({
            label: '入站规则 (RULE_IN)',
            count: this.countRulesByDirection(netFirewall.NetFirewallRuleDirection.RULE_IN),
            gradientStart: '#FF9500',
            gradientEnd: '#FFCC00',
            icon: $r('app.media.arrow_down')
          })
            .layoutWeight(1)

          DirectionCard({
            label: '出站规则 (RULE_OUT)',
            count: this.countRulesByDirection(netFirewall.NetFirewallRuleDirection.RULE_OUT),
            gradientStart: '#0A84FF',
            gradientEnd: '#00C6FF',
            icon: $r('app.media.arrow_up')
          })
            .layoutWeight(1)
        }
        .width('100%')

        GridRow({ columns: 4, gutter: 14 }) {
          GridCol() {
            this.summaryCard(0, '全部规则', this.rules.length.toString(), $r('app.media.firewall'), AppColors.BRAND_PRIMARY)
          }
          GridCol() {
            this.summaryCard(1, 'IP 规则', this.countRulesByType(netFirewall.NetFirewallRuleType.RULE_IP).toString(),
              $r('app.media.network'), AppColors.BRAND_PRIMARY)
          }
          GridCol() {
            this.summaryCard(2, '域名规则', this.countRulesByType(netFirewall.NetFirewallRuleType.RULE_DOMAIN).toString(),
              $r('app.media.globe'), '#5856D6')
          }
          GridCol() {
            this.summaryCard(3, 'DNS 规则', this.countRulesByType(netFirewall.NetFirewallRuleType.RULE_DNS).toString(),
              $r('app.media.server'), AppColors.SUCCESS)
          }
        }
        .width('100%')
        .height(0)
        .visibility(Visibility.None)

        Tabs({ barPosition: BarPosition.Start }) {
          TabContent() {
            this.ruleListBuilder()
          }.tabBar(this.tabBuilder('全部', 0))

          TabContent() {
            this.ruleListBuilder()
          }.tabBar(this.tabBuilder('IP', 1))

          TabContent() {
            this.ruleListBuilder()
          }.tabBar(this.tabBuilder('域名', 2))

          TabContent() {
            this.ruleListBuilder()
          }.tabBar(this.tabBuilder('DNS', 3))
        }
        .barMode(BarMode.Scrollable)
        .barBackgroundColor(Color.Transparent)
        .divider(null)
        .onChange((index: number) => {
          this.currentTab = index
        })
        .layoutWeight(1)
      }
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_LG, bottom: AppStyles.PADDING_LG })
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }

  @Builder
  ruleListBuilder() {
    Column() {
      if (this.isLoading) {
        Column({ space: 10 }) {
          LoadingProgress()
            .width(42)
            .height(42)
          Text('加载规则中...')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.getFilteredRules().length === 0) {
        Column({ space: 10 }) {
          Text('当前筛选下暂无规则')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        List({ space: 12 }) {
          ForEach(this.getFilteredRules(), (rule: netFirewall.NetFirewallRule, index: number) => {
            ListItem() {
              Column({ space: 14 }) {
                Row({ space: 12 }) {
                  Column() {
                    Image(this.getRuleIcon(rule.type))
                      .width(18)
                      .height(18)
                      .fillColor(Color.White)
                  }
                  .width(40)
                  .height(40)
                  .borderRadius(12)
                  .justifyContent(FlexAlign.Center)
                  .alignItems(HorizontalAlign.Center)
                  .backgroundColor(this.getRuleTypeTextColor(rule.type))

                  Column({ space: 6 }) {
                    Text(rule.name ?? '-')
                      .fontSize(AppStyles.FONT_SIZE_BODY)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    Row({ space: 8 }) {
                      Text(this.getRuleTypeLabel(rule.type))
                        .fontSize(AppStyles.FONT_SIZE_CAPTION)
                        .fontColor(this.getRuleTypeTextColor(rule.type))
                        .backgroundColor(this.getRuleTypeBgColor(rule.type))
                        .borderRadius(10)
                        .padding({ left: 8, right: 8, top: 4, bottom: 4 })

                      Text(this.getDirectionLabel(rule.direction))
                        .fontSize(AppStyles.FONT_SIZE_CAPTION)
                        .fontColor(AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT)
                        .backgroundColor(AppColors.getColors(this.currentTheme).TAG_BLUE_BG)
                        .borderRadius(10)
                        .padding({ left: 8, right: 8, top: 4, bottom: 4 })

                      Text(this.getActionLabel(rule.action))
                        .fontSize(AppStyles.FONT_SIZE_CAPTION)
                        .fontColor(this.getActionTextColor(rule.action))
                        .backgroundColor(this.getActionBgColor(rule.action))
                        .borderRadius(10)
                        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    }
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  Button('删除')
                    .fontSize(AppStyles.FONT_SIZE_CAPTION)
                    .fontColor(AppColors.DANGER)
                    .backgroundColor(AppColors.getColors(this.currentTheme).TAG_RED_BG)
                    .borderRadius(AppStyles.RADIUS_SM)
                    .height(30)
                    .onClick(() => {
                      if (rule.id !== undefined) {
                        this.handleDeleteRule(rule.id)
                      }
                    })
                }
                .width('100%')

                Column({ space: 10 }) {
                  this.detailRow('地址 / 域名', this.getRuleAddress(rule))
                  this.detailRow('端口', this.getRulePort(rule))
                  this.detailRow('协议', this.getProtocolLabel(rule))
                }
                .width('100%')
              }
              .width('100%')
              .padding(18)
              .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
              .borderRadius(AppStyles.RADIUS_LG)
              .border({
                width: 1,
                color: this.hoveredRuleIndex === index ? this.getRuleTypeTextColor(rule.type) : AppColors.getColors(this.currentTheme).BORDER
              })
              .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredRuleIndex === index, true))
              .translate({ y: HoverUtils.getTranslateY(this.hoveredRuleIndex === index, 4) })
              .onHover((isHover: boolean) => {
                HoverUtils.animate(() => {
                  this.hoveredRuleIndex = isHover ? index : -1
                })
              })
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: AppStyles.PADDING_MD, bottom: 2 })
  }

  @Builder
  detailRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        .width(92)

      Text(value)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}
