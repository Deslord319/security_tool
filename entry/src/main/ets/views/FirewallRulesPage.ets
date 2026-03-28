import { AppColors, AppStyles } from '../constants/AppConstants'
import { CommonStrings } from '../constants/CommonStrings'
import { FirewallStrings } from '../constants/modules/FirewallStrings'
import { FirewallService } from '../services/FirewallService'
import { FirewallCustomRuleService } from '../services/FirewallCustomRuleService'
import { FirewallModeService } from '../services/FirewallModeService'
import { AddRuleDialog } from '../components/AddRuleDialog'
import { BackNavButton } from '../components/BackNavButton'
import { DirectionCard } from '../components/DirectionCard'
import { netFirewall } from '@kit.NetworkKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { common } from '@kit.AbilityKit'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { FirewallPresetMode } from '../models/DataModels'
import { DialogService } from '../utils/DialogService'

const TAG = 'FirewallRulesPage'

@Component
export struct FirewallRulesPage {
  @Prop currentMode: FirewallPresetMode = 'custom'
  @State rules: netFirewall.NetFirewallRule[] = []
  @State conflictNotice: string = ''
  @State currentTab: number = 0
  @State isLoading: boolean = false
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

  aboutToAppear() {
    if (this.currentMode !== 'custom') {
      void DialogService.openFailure(this.getUIContext(), FirewallStrings.rulesOnlyCustomMode)
      this.onBack()
      return
    }
    this.loadRules()
  }

  async loadRules() {
    this.isLoading = true
    let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    this.rules = await FirewallCustomRuleService.listRules(context)
    this.updateConflictNotice()
    this.isLoading = false
  }

  private async persistRules(nextRules: netFirewall.NetFirewallRule[], successMessage: string): Promise<void> {
    let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    let previousRules = this.rules.map((rule: netFirewall.NetFirewallRule) => FirewallService.cloneRuleForCreate(rule))
    let result = await FirewallModeService.applyCustomRules(context, nextRules)
    if (!result.success) {
      void DialogService.openFailure(
        this.getUIContext(),
        result.errorMessage?.length ? result.errorMessage : FirewallStrings.customRulesApplyFailed
      )
      return
    }
    let saved = await FirewallCustomRuleService.replaceAllRules(context, nextRules)
    if (!saved) {
      let rollbackResult = await FirewallModeService.applyCustomRules(context, previousRules)
      if (!rollbackResult.success) {
        void DialogService.openFailure(this.getUIContext(), FirewallStrings.customRulesLocalSaveFailed)
        return
      }
      await this.loadRules()
      void DialogService.openFailure(this.getUIContext(), FirewallStrings.customRulesRollbackSuccess)
      return
    }
    await this.loadRules()
    hilog.info(0x0001, TAG, `persistRules success: ${successMessage}`)
  }

  async handleAddRule(rule: netFirewall.NetFirewallRule) {
    let conflict = FirewallService.findRuleConflict(this.rules, rule)
    if (conflict) {
      if (conflict.kind === 'duplicate') {
        void DialogService.openFailure(this.getUIContext(), FirewallStrings.duplicateRule)
        return
      }
      if (conflict.kind === 'hard_conflict') {
        let conflictRule = conflict.existingRule
        void DialogService.openConfirm(this.getUIContext(), {
          title: FirewallStrings.conflictRuleTitle,
          message: FirewallStrings.conflictRuleReplaceMessage,
          confirmText: CommonStrings.actionOverride,
          cancelText: CommonStrings.actionCancel,
          onConfirm: () => {
            this.replaceConflictRule(conflictRule, rule, false)
          }
        })
        return
      }
      if (conflict.kind === 'overlap_conflict') {
        void DialogService.openConfirm(this.getUIContext(), {
          title: FirewallStrings.overlapRuleTitle,
          message: FirewallStrings.overlapRuleAddMessage,
          confirmText: CommonStrings.actionContinue,
          cancelText: CommonStrings.actionCancel,
          onConfirm: () => {
            this.addRuleDirectly(rule)
          }
        })
        return
      }
    }
    await this.addRuleDirectly(rule)
  }

  private async addRuleDirectly(rule: netFirewall.NetFirewallRule): Promise<void> {
    let nextRules = [...this.rules, rule]
    await this.persistRules(nextRules, FirewallStrings.addRuleSuccess)
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
    let currentRuleId = this.getLocalRuleId(rule)
    let comparableRules = this.rules.filter((item: netFirewall.NetFirewallRule) => this.getLocalRuleId(item) !== currentRuleId)
    let conflict = FirewallService.findRuleConflict(comparableRules, rule)
    if (conflict) {
      if (conflict.kind === 'duplicate') {
        void DialogService.openFailure(this.getUIContext(), FirewallStrings.duplicateRule)
        return
      }
      if (conflict.kind === 'hard_conflict') {
        let conflictRule = conflict.existingRule
        void DialogService.openConfirm(this.getUIContext(), {
          title: FirewallStrings.conflictRuleTitle,
          message: FirewallStrings.conflictRuleReplaceAndSaveMessage,
          confirmText: CommonStrings.actionOverride,
          cancelText: CommonStrings.actionCancel,
          onConfirm: () => {
            this.replaceConflictRule(conflictRule, rule, true)
          }
        })
        return
      }
      if (conflict.kind === 'overlap_conflict') {
        void DialogService.openConfirm(this.getUIContext(), {
          title: FirewallStrings.overlapRuleTitle,
          message: FirewallStrings.overlapRuleEditMessage,
          confirmText: CommonStrings.actionContinue,
          cancelText: CommonStrings.actionCancel,
          onConfirm: () => {
            this.updateRuleDirectly(rule)
          }
        })
        return
      }
    }
    await this.updateRuleDirectly(rule)
  }

  private async updateRuleDirectly(rule: netFirewall.NetFirewallRule): Promise<void> {
    let localRuleId = this.getLocalRuleId(rule)
    let nextRules = this.rules.map((item: netFirewall.NetFirewallRule) =>
      this.getLocalRuleId(item) === localRuleId ? rule : item
    )
    await this.persistRules(nextRules, FirewallStrings.updateRuleSuccess)
  }

  private async replaceConflictRule(
    conflictRule: netFirewall.NetFirewallRule,
    nextRule: netFirewall.NetFirewallRule,
    isEditMode: boolean
  ): Promise<void> {
    let conflictRuleId = this.getLocalRuleId(conflictRule)
    let nextRules = this.rules.filter((item: netFirewall.NetFirewallRule) => this.getLocalRuleId(item) !== conflictRuleId)
    if (isEditMode) {
      let currentRuleId = this.getLocalRuleId(nextRule)
      nextRules = nextRules.map((item: netFirewall.NetFirewallRule) =>
        this.getLocalRuleId(item) === currentRuleId ? nextRule : item
      )
    } else {
      nextRules.push(nextRule)
    }
    await this.persistRules(nextRules, isEditMode ? FirewallStrings.replaceRuleSuccess : FirewallStrings.overwriteRuleSuccess)
  }

  async handleDeleteRule(rule: netFirewall.NetFirewallRule) {
    void DialogService.openConfirm(this.getUIContext(), {
      title: FirewallStrings.deleteRuleTitle,
      message: FirewallStrings.deleteRuleMessage,
      confirmText: CommonStrings.actionDelete,
      cancelText: CommonStrings.actionCancel,
      onConfirm: () => {
        this.deleteRuleDirectly(rule)
      }
    })
  }

  private async deleteRuleDirectly(rule: netFirewall.NetFirewallRule): Promise<void> {
    let localRuleId = this.getLocalRuleId(rule)
    let nextRules = this.rules.filter((item: netFirewall.NetFirewallRule) => this.getLocalRuleId(item) !== localRuleId)
    await this.persistRules(nextRules, FirewallStrings.deleteRuleSuccess)
  }

  private getLocalRuleId(rule: netFirewall.NetFirewallRule): number | undefined {
    return FirewallService.getRulePrimaryKey(rule)
  }

  private updateConflictNotice(): void {
    let summary = FirewallService.summarizeConflicts(this.rules)
    this.conflictNotice = FirewallStrings.buildConflictNotice(
      summary.duplicates,
      summary.hardConflicts,
      summary.overlapConflicts
    )
  }

  getFilteredRules(): netFirewall.NetFirewallRule[] {
    if (this.currentTab === 0) {
      return this.rules
    }

    const targetType = (() => {
      switch (this.currentTab) {
        case 1: return netFirewall.NetFirewallRuleType.RULE_IP
        case 2: return netFirewall.NetFirewallRuleType.RULE_DOMAIN
        case 3: return netFirewall.NetFirewallRuleType.RULE_DNS
        default: return null
      }
    })()

    if (!targetType) {
      return this.rules
    }
    return this.rules.filter((rule: netFirewall.NetFirewallRule) => rule.type === targetType)
  }

  countRulesByType(type: netFirewall.NetFirewallRuleType): number {
    return this.rules.filter((rule: netFirewall.NetFirewallRule) => rule.type === type).length
  }

  countRulesByDirection(direction: netFirewall.NetFirewallRuleDirection): number {
    return this.rules.filter((rule: netFirewall.NetFirewallRule) => rule.direction === direction).length
  }

  getRuleTypeLabel(type: netFirewall.NetFirewallRuleType): string {
    switch (type) {
      case netFirewall.NetFirewallRuleType.RULE_IP:
        return 'IP'
      case netFirewall.NetFirewallRuleType.RULE_DOMAIN:
        return FirewallStrings.typeDomain
      case netFirewall.NetFirewallRuleType.RULE_DNS:
        return 'DNS'
      default:
        return FirewallStrings.typeUnknown
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
    return dir === netFirewall.NetFirewallRuleDirection.RULE_IN ? FirewallStrings.directionInbound : FirewallStrings.directionOutbound
  }

  getActionLabel(action: netFirewall.FirewallRuleAction): string {
    return action === netFirewall.FirewallRuleAction.RULE_ALLOW ? FirewallStrings.actionAllow : FirewallStrings.actionDeny
  }

  getActionBgColor(action: netFirewall.FirewallRuleAction): string {
    return action === netFirewall.FirewallRuleAction.RULE_ALLOW
      ? AppColors.getColors(this.currentTheme).TAG_GREEN_BG
      : AppColors.getColors(this.currentTheme).TAG_RED_BG
  }

  getActionTextColor(action: netFirewall.FirewallRuleAction): string {
    return action === netFirewall.FirewallRuleAction.RULE_ALLOW
      ? AppColors.getColors(this.currentTheme).TAG_GREEN_TEXT
      : AppColors.getColors(this.currentTheme).TAG_RED_TEXT
  }

  getRuleAddress(rule: netFirewall.NetFirewallRule): string {
    if (rule.type === netFirewall.NetFirewallRuleType.RULE_IP) {
      let ip = rule.remoteIps?.[0]
      if (!ip?.address) {
        return '-'
      }
      return ip.mask !== undefined && ip.mask < 32 ? `${ip.address}/${ip.mask}` : ip.address
    }
    if (rule.type === netFirewall.NetFirewallRuleType.RULE_DOMAIN) {
      return rule.domains?.[0]?.domain ?? '-'
    }
    if (rule.type === netFirewall.NetFirewallRuleType.RULE_DNS) {
      return rule.dns?.primaryDns ?? '-'
    }
    return '-'
  }

  getRuleLocalPort(rule: netFirewall.NetFirewallRule): string {
    let port = rule.localPorts?.[0]
    if (!port) {
      return 'ALL'
    }
    return port.startPort === port.endPort ? `${port.startPort}` : `${port.startPort}-${port.endPort}`
  }

  getRuleRemotePort(rule: netFirewall.NetFirewallRule): string {
    let port = rule.remotePorts?.[0]
    if (!port) {
      return 'ALL'
    }
    return port.startPort === port.endPort ? `${port.startPort}` : `${port.startPort}-${port.endPort}`
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
              Text(FirewallStrings.customModeTitle)
                .fontSize(AppStyles.FONT_SIZE_TITLE)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            }

            Text(FirewallStrings.customRulesSubtitle)
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Button(FirewallStrings.addRuleButton)
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
            Text(FirewallStrings.conflictWarningLabel)
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
            label: FirewallStrings.inboundRules,
            count: this.countRulesByDirection(netFirewall.NetFirewallRuleDirection.RULE_IN),
            gradientStart: '#FF9500',
            gradientEnd: '#FFCC00',
            icon: $r('app.media.arrow_down')
          })
            .layoutWeight(1)

          DirectionCard({
            label: FirewallStrings.outboundRules,
            count: this.countRulesByDirection(netFirewall.NetFirewallRuleDirection.RULE_OUT),
            gradientStart: '#0A84FF',
            gradientEnd: '#00C6FF',
            icon: $r('app.media.arrow_up')
          })
            .layoutWeight(1)
        }
        .width('100%')

        Tabs({ barPosition: BarPosition.Start }) {
          TabContent() {
            this.ruleListBuilder()
          }.tabBar(this.tabBuilder(FirewallStrings.tabAllRules, 0))

          TabContent() {
            this.ruleListBuilder()
          }.tabBar(this.tabBuilder(FirewallStrings.tabIpRules, 1))

          TabContent() {
            this.ruleListBuilder()
          }.tabBar(this.tabBuilder(FirewallStrings.tabDomainRules, 2))

          TabContent() {
            this.ruleListBuilder()
          }.tabBar(this.tabBuilder(FirewallStrings.tabDnsRules, 3))
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
          Text(FirewallStrings.loadingRules)
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.getFilteredRules().length === 0) {
        Column({ space: 10 }) {
          Text(FirewallStrings.emptyRules)
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
          ForEach(this.getFilteredRules(), (rule: netFirewall.NetFirewallRule) => {
            ListItem() {
              Column({ space: 14 }) {
                Row({ space: 12 }) {
                  Column() {
                    Image(this.getRuleIcon(rule.type))
                      .width(18)
                      .height(18)
                      .fillColor(Color.White)
                      .draggable(false)
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

                  Row({ space: 8 }) {
                    Button(CommonStrings.actionDelete)
                      .fontSize(AppStyles.FONT_SIZE_CAPTION)
                      .fontColor(AppColors.DANGER)
                      .backgroundColor(AppColors.getColors(this.currentTheme).TAG_RED_BG)
                      .borderRadius(AppStyles.RADIUS_SM)
                      .height(30)
                      .onClick(() => {
                        this.handleDeleteRule(rule)
                      })
                  }
                }
                .width('100%')

                Column({ space: 10 }) {
                  this.detailRow(FirewallStrings.detailRemoteAddress, this.getRuleAddress(rule))
                  this.detailRow(FirewallStrings.detailLocalPort, this.getRuleLocalPort(rule))
                  this.detailRow(FirewallStrings.detailRemotePort, this.getRuleRemotePort(rule))
                  this.detailRow(FirewallStrings.detailProtocol, this.getProtocolLabel(rule))
                }
                .width('100%')
              }
              .width('100%')
              .padding(18)
              .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
              .borderRadius(AppStyles.RADIUS_LG)
              .border({
                width: 1,
                color: AppColors.getColors(this.currentTheme).BORDER
              })
              .onClick(() => {
                this.openEditRuleDialog(rule)
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
