import { AppColors, AppStyles } from '../constants/AppConstants'
import { FirewallService } from '../services/FirewallService'
import { AddRuleDialog } from '../components/AddRuleDialog'
import { netFirewall } from '@kit.NetworkKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { promptAction } from '@kit.ArkUI'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'

const TAG = 'FirewallRulesPage'

@Component
export struct FirewallRulesPage {
  @State rules: netFirewall.NetFirewallRule[] = []
  @State currentTab: number = 0
  @State isLoading: boolean = false
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
      promptAction.showToast({ message: '规则添加失败，请检查权限' })
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

  getRuleTypeLabel(type: netFirewall.NetFirewallRuleType): string {
    switch (type) {
      case netFirewall.NetFirewallRuleType.RULE_IP:
        return 'IP'
      case netFirewall.NetFirewallRuleType.RULE_DOMAIN:
        return '域名'
      case netFirewall.NetFirewallRuleType.RULE_DNS:
        return 'DNS'
      default:
        return '未知'
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
    return '-'
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

  @Builder
  tabBuilder(title: string, index: number) {
    Text(title)
      .fontSize(AppStyles.FONT_SIZE_BODY)
      .fontWeight(this.currentTab === index ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.currentTab === index ? AppColors.BRAND_PRIMARY : AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
      .opacity(this.currentTab === index ? 1 : AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
  }

  build() {
    Column() {
      // 页面头部
      Row() {
        Row({ space: 8 }) {
          Text('<')
            .fontSize(20)
            .fontColor(AppColors.BRAND_PRIMARY)
            .onClick(() => {
              this.onBack()
            })
          Text('防火墙规则')
            .fontSize(AppStyles.FONT_SIZE_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        }
        .layoutWeight(1)

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
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_LG })

      // Tab 切换
      Tabs({ barPosition: BarPosition.Start }) {
        TabContent() {
          this.ruleListBuilder()
        }.tabBar(this.tabBuilder('全部规则', 0))

        TabContent() {
          this.ruleListBuilder()
        }.tabBar(this.tabBuilder('IP 规则', 1))

        TabContent() {
          this.ruleListBuilder()
        }.tabBar(this.tabBuilder('域名规则', 2))

        TabContent() {
          this.ruleListBuilder()
        }.tabBar(this.tabBuilder('DNS 规则', 3))
      }
      .barMode(BarMode.Fixed)
      .barWidth('100%')
      .onChange((index: number) => {
        this.currentTab = index
      })
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }

  @Builder
  ruleListBuilder() {
    Column() {
      if (this.getFilteredRules().length === 0) {
        Column({ space: 12 }) {
          Text('暂无规则')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        // 表头
        Row() {
          Text('规则名称').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(2)
          Text('类型').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
          Text('方向').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
          Text('协议').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
          Text('地址').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(2)
          Text('端口').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
          Text('策略').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
          Text('操作').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
        .borderRadius({ topLeft: AppStyles.RADIUS_LG, topRight: AppStyles.RADIUS_LG })

        // 数据列表
        List() {
          ForEach(this.getFilteredRules(), (rule: netFirewall.NetFirewallRule) => {
            ListItem() {
              Row() {
                Text(rule.name ?? '-')
                  .fontSize(AppStyles.FONT_SIZE_SMALL)
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                  .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
                  .layoutWeight(2)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text(this.getRuleTypeLabel(rule.type))
                  .fontSize(AppStyles.FONT_SIZE_CAPTION)
                  .fontColor(this.getRuleTypeTextColor(rule.type))
                  .backgroundColor(this.getRuleTypeBgColor(rule.type))
                  .borderRadius(4)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .layoutWeight(1)

                Text(this.getDirectionLabel(rule.direction))
                  .fontSize(AppStyles.FONT_SIZE_SMALL)
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                  .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
                  .layoutWeight(1)

                Text(this.getProtocolLabel(rule))
                  .fontSize(AppStyles.FONT_SIZE_SMALL)
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                  .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
                  .layoutWeight(1)

                Text(this.getRuleAddress(rule))
                  .fontSize(AppStyles.FONT_SIZE_SMALL)
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                  .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
                  .layoutWeight(2)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text(this.getRulePort(rule))
                  .fontSize(AppStyles.FONT_SIZE_SMALL)
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                  .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
                  .layoutWeight(1)

                Text(this.getActionLabel(rule.action))
                  .fontSize(AppStyles.FONT_SIZE_CAPTION)
                  .fontColor(this.getActionTextColor(rule.action))
                  .backgroundColor(this.getActionBgColor(rule.action))
                  .borderRadius(4)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .layoutWeight(1)

                Text('删除')
                  .fontSize(AppStyles.FONT_SIZE_CAPTION)
                  .fontColor(AppColors.DANGER)
                  .layoutWeight(1)
                  .onClick(() => {
                    if (rule.id !== undefined) {
                      this.handleDeleteRule(rule.id)
                    }
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .divider({ strokeWidth: 1, color: AppColors.getColors(this.currentTheme).BORDER, startMargin: 0, endMargin: 0 })
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD })
  }
}
