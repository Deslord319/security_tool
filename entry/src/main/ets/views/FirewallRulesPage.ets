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
  @State conflictNotice: string = ''
  @State currentTab: number = 0
  @State isLoading: boolean = false
  @State hoveredRuleIndex: number = -1
  onBack: () => void = () => {}
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  private addRuleDialogController: CustomDialogController = new CustomDialogController({
    builder: AddRuleDialog({
      onClose: () => {
        this.addRuleDialogController.close()
      },
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
    this.updateConflictNotice()
    this.isLoading = false
  }

  async handleAddRule(rule: netFirewall.NetFirewallRule) {
    let conflict = FirewallService.findRuleConflict(this.rules, rule)
    if (conflict) {
      if (conflict.kind === 'duplicate') {
        promptAction.showToast({ message: '\u89c4\u5219\u5df2\u5b58\u5728\uff0c\u65e0\u9700\u91cd\u590d\u6dfb\u52a0' })
        return
      }
      let existingRuleId = FirewallService.getRulePrimaryKey(conflict.existingRule)
      if (conflict.kind === 'hard_conflict' && existingRuleId !== undefined) {
        this.showReplaceRuleConfirm(existingRuleId, rule)
        return
      }
      if (conflict.kind === 'overlap_conflict') {
        this.showOverlapRiskConfirm(rule)
        return
      }
    }
    await this.addRuleDirectly(rule)
  }

  private openEditRuleDialog(rule: netFirewall.NetFirewallRule): void {
    let dialogController = new CustomDialogController({
      builder: AddRuleDialog({
        onClose: () => {
          dialogController.close()
        },
        initialRule: rule,
        isEditMode: true,
        onConfirm: (updatedRule: netFirewall.NetFirewallRule) => {
          this.handleEditRule(updatedRule)
        }
      }),
      autoCancel: true,
      customStyle: true,
      alignment: DialogAlignment.Center
    })
    dialogController.open()
  }

  async handleEditRule(rule: netFirewall.NetFirewallRule) {
    let currentRuleId = FirewallService.getRulePrimaryKey(rule)
    let conflict = FirewallService.findRuleConflict(this.rules, rule, currentRuleId)
    if (conflict) {
      if (conflict.kind === 'duplicate') {
        promptAction.showToast({ message: '规则已存在，无需重复保存' })
        return
      }
      let existingRuleId = FirewallService.getRulePrimaryKey(conflict.existingRule)
      if (conflict.kind === 'hard_conflict' && existingRuleId !== undefined) {
        this.showReplaceRuleConfirm(existingRuleId, rule, true)
        return
      }
      if (conflict.kind === 'overlap_conflict') {
        this.showOverlapRiskConfirm(rule, true)
        return
      }
    }
    await this.updateRuleDirectly(rule)
  }

  private async addRuleDirectly(
    rule: netFirewall.NetFirewallRule,
    successMessage: string = '\u89c4\u5219\u6dfb\u52a0\u6210\u529f'
  ) {
    let ruleId = await FirewallService.addRule(rule)
    if (ruleId > 0) {
      promptAction.showToast({ message: successMessage })
      this.loadRules()
      return
    }
    let errorKind = FirewallService.getLastErrorKind()
    if (errorKind === 'invalid_argument') {
      promptAction.showToast({ message: '\u89c4\u5219\u53c2\u6570\u4e0d\u5408\u6cd5\uff0c\u8bf7\u68c0\u67e5\u8f93\u5165' })
      return
    }
    if (errorKind === 'permission') {
      promptAction.showToast({ message: '\u89c4\u5219\u6dfb\u52a0\u5931\u8d25\uff0c\u8bf7\u68c0\u67e5\u6743\u9650\u548c\u4f01\u4e1a\u7ba1\u7406\u5458\u72b6\u6001' })
      return
    }
    promptAction.showToast({ message: '\u89c4\u5219\u6dfb\u52a0\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5' })
  }

  private async updateRuleDirectly(rule: netFirewall.NetFirewallRule): Promise<void> {
    let success = await FirewallService.updateRule(rule)
    if (success) {
      promptAction.showToast({ message: '规则更新成功' })
      this.loadRules()
      return
    }
    let errorKind = FirewallService.getLastErrorKind()
    if (errorKind === 'invalid_argument') {
      promptAction.showToast({ message: '规则参数不合法，请检查输入' })
      return
    }
    if (errorKind === 'permission') {
      promptAction.showToast({ message: '规则更新失败，请检查权限和企业管理员状态' })
      return
    }
    promptAction.showToast({ message: '规则更新失败，请稍后重试' })
  }

  private showReplaceRuleConfirm(
    oldRuleId: number,
    newRule: netFirewall.NetFirewallRule,
    isEditMode: boolean = false
  ): void {
    AlertDialog.show({
      title: '\u5b58\u5728\u51b2\u7a81\u89c4\u5219',
      message: isEditMode
        ? '检测到同一目标和方向下已存在相反动作的规则。覆盖后将删除冲突旧规则，并保存当前编辑结果。'
        : '\u68c0\u6d4b\u5230\u540c\u4e00\u76ee\u6807\u548c\u65b9\u5411\u4e0b\u5df2\u5b58\u5728\u76f8\u53cd\u52a8\u4f5c\u7684\u89c4\u5219\u3002\u8986\u76d6\u540e\u5c06\u5220\u9664\u65e7\u89c4\u5219\u5e76\u4fdd\u5b58\u65b0\u89c4\u5219\u3002',
      primaryButton: {
        value: '\u8986\u76d6',
        action: () => {
          if (isEditMode) {
            this.replaceRuleWhileEditing(oldRuleId, newRule)
          } else {
            this.replaceRule(oldRuleId, newRule)
          }
        }
      },
      secondaryButton: {
        value: '\u53d6\u6d88',
        action: () => {}
      }
    })
  }

  private showOverlapRiskConfirm(rule: netFirewall.NetFirewallRule, isEditMode: boolean = false): void {
    AlertDialog.show({
      title: '\u5b58\u5728\u91cd\u53e0\u89c4\u5219',
      message: '\u65b0\u89c4\u5219\u4e0e\u73b0\u6709\u89c4\u5219\u7684\u547d\u4e2d\u8303\u56f4\u5b58\u5728\u91cd\u53e0\uff0c\u5b9e\u9645\u751f\u6548\u7ed3\u679c\u53ef\u80fd\u53d7\u7cfb\u7edf\u89c4\u5219\u4f18\u5148\u7ea7\u5f71\u54cd\u3002\u662f\u5426\u7ee7\u7eed\u4fdd\u5b58\uff1f',
      primaryButton: {
        value: '\u7ee7\u7eed\u4fdd\u5b58',
        action: () => {
          if (isEditMode) {
            this.updateRuleDirectly(rule)
          } else {
            this.addRuleDirectly(rule)
          }
        }
      },
      secondaryButton: {
        value: '\u53d6\u6d88',
        action: () => {}
      }
    })
  }

  private async replaceRule(oldRuleId: number, newRule: netFirewall.NetFirewallRule): Promise<void> {
    let ruleId = await FirewallService.replaceRule(oldRuleId, newRule)
    if (ruleId > 0) {
      promptAction.showToast({ message: '\u89c4\u5219\u5df2\u8986\u76d6\u5e76\u751f\u6548' })
      this.loadRules()
      return
    }
    promptAction.showToast({ message: '\u89c4\u5219\u8986\u76d6\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5' })
  }

  private async replaceRuleWhileEditing(oldRuleId: number, updatedRule: netFirewall.NetFirewallRule): Promise<void> {
    let removed = await FirewallService.removeRule(oldRuleId)
    if (!removed) {
      promptAction.showToast({ message: '规则覆盖失败，请稍后重试' })
      return
    }
    await this.updateRuleDirectly(updatedRule)
  }

  private updateConflictNotice(): void {
    let summary = FirewallService.summarizeConflicts(this.rules)
    let parts: string[] = []
    if (summary.duplicates > 0) {
      parts.push(`\u91cd\u590d ${summary.duplicates} \u7ec4`)
    }
    if (summary.hardConflicts > 0) {
      parts.push(`\u786c\u51b2\u7a81 ${summary.hardConflicts} \u7ec4`)
    }
    if (summary.overlapConflicts > 0) {
      parts.push(`\u91cd\u53e0\u51b2\u7a81 ${summary.overlapConflicts} \u7ec4`)
    }
    this.conflictNotice = parts.length > 0
      ? `\u68c0\u6d4b\u5230\u5386\u53f2\u89c4\u5219\u5b58\u5728${parts.join('\u3001')}\uff0c\u5efa\u8bae\u6e05\u7406\u540e\u518d\u7ee7\u7eed\u914d\u7f6e\u3002`
      : ''
  }
  async handleDeleteRule(ruleId: number) {
    let success = await FirewallService.removeRule(ruleId)
    if (success) {
      promptAction.showToast({ message: '\u89c4\u5219\u5df2\u5220\u9664' })
      this.loadRules()
    } else {
      promptAction.showToast({ message: '\u5220\u9664\u5931\u8d25' })
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
        return '\u0049\u0050\u89c4\u5219'
      case netFirewall.NetFirewallRuleType.RULE_DOMAIN:
        return '\u57df\u540d\u89c4\u5219'
      case netFirewall.NetFirewallRuleType.RULE_DNS:
        return '\u0044\u004e\u0053\u89c4\u5219'
      default:
        return '\u672a\u77e5\u89c4\u5219'
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
    return dir === netFirewall.NetFirewallRuleDirection.RULE_IN ? '\u5165\u7ad9' : '\u51fa\u7ad9'
  }

  getActionLabel(action: netFirewall.FirewallRuleAction): string {
    return action === netFirewall.FirewallRuleAction.RULE_ALLOW ? '\u5141\u8bb8' : '\u62d2\u7edd'
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
              Text('\u9632\u706b\u5899\u89c4\u5219')
                .fontSize(AppStyles.FONT_SIZE_TITLE)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            }

            Text('\u67e5\u770b\u3001\u6dfb\u52a0\u548c\u5220\u9664\u9632\u706b\u5899\u89c4\u5219\uff0c\u6ce8\u610f\u907f\u514d\u5bf9\u540c\u4e00\u76ee\u6807\u914d\u7f6e\u76f8\u4e92\u51b2\u7a81\u7684\u52a8\u4f5c\u3002')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Button('\u6309\u7528\u6237\u63a7\u5236')
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

          Button('+ \u6dfb\u52a0\u89c4\u5219')
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

        if (this.conflictNotice.length > 0) {
          Row({ space: 8 }) {
            Text('\u98ce\u9669\u63d0\u793a')
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontWeight(FontWeight.Medium)
              .fontColor('#8A5200')
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor('#FFE8B3')
              .borderRadius(10)

            Text(this.conflictNotice)
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontColor('#8A5200')
              .layoutWeight(1)
          }
          .width('100%')
          .padding(12)
          .backgroundColor('#FFF7E6')
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: 1, color: '#FFD591' })
        }
        Row({ space: 16 }) {
          DirectionCard({
            label: '\u5165\u7ad9\u89c4\u5219 (RULE_IN)',
            count: this.countRulesByDirection(netFirewall.NetFirewallRuleDirection.RULE_IN),
            gradientStart: '#FF9500',
            gradientEnd: '#FFCC00',
            icon: $r('app.media.arrow_down')
          })
            .layoutWeight(1)

          DirectionCard({
            label: '\u51fa\u7ad9\u89c4\u5219 (RULE_OUT)',
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
            this.summaryCard(0, '\u5168\u90e8\u89c4\u5219', this.rules.length.toString(), $r('app.media.firewall'), AppColors.BRAND_PRIMARY)
          }
          GridCol() {
            this.summaryCard(1, '\u0049\u0050\u89c4\u5219', this.countRulesByType(netFirewall.NetFirewallRuleType.RULE_IP).toString(),
              $r('app.media.network'), AppColors.BRAND_PRIMARY)
          }
          GridCol() {
            this.summaryCard(2, '\u57df\u540d\u89c4\u5219', this.countRulesByType(netFirewall.NetFirewallRuleType.RULE_DOMAIN).toString(),
              $r('app.media.globe'), '#5856D6')
          }
          GridCol() {
            this.summaryCard(3, '\u0044\u004e\u0053\u89c4\u5219', this.countRulesByType(netFirewall.NetFirewallRuleType.RULE_DNS).toString(),
              $r('app.media.server'), AppColors.SUCCESS)
          }
        }
        .width('100%')
        .height(0)
        .visibility(Visibility.None)

        Tabs({ barPosition: BarPosition.Start }) {
          TabContent() {
            this.ruleListBuilder()
          }.tabBar(this.tabBuilder('\u5168\u90e8', 0))

          TabContent() {
            this.ruleListBuilder()
          }.tabBar(this.tabBuilder('IP', 1))

          TabContent() {
            this.ruleListBuilder()
          }.tabBar(this.tabBuilder('\u57df\u540d', 2))

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
          Text('\u6b63\u5728\u52a0\u8f7d\u89c4\u5219...')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.getFilteredRules().length === 0) {
        Column({ space: 10 }) {
          Text('\u5f53\u524d\u7c7b\u578b\u4e0b\u6682\u65e0\u89c4\u5219')
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

                  Button('\u5220\u9664')
                    .fontSize(AppStyles.FONT_SIZE_CAPTION)
                    .fontColor(AppColors.DANGER)
                    .backgroundColor(AppColors.getColors(this.currentTheme).TAG_RED_BG)
                    .borderRadius(AppStyles.RADIUS_SM)
                    .height(30)
                    .onClick(() => {
                      let ruleId = FirewallService.getRulePrimaryKey(rule)
                      if (ruleId !== undefined) {
                        this.handleDeleteRule(ruleId)
                      }
                    })
                }
                .width('100%')

                Column({ space: 10 }) {
                  this.detailRow('\u5730\u5740 / \u57df\u540d', this.getRuleAddress(rule))
                  this.detailRow('\u7aef\u53e3', this.getRulePort(rule))
                  this.detailRow('\u534f\u8bae', this.getProtocolLabel(rule))
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
              .onClick(() => {
                this.openEditRuleDialog(rule)
              })
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
