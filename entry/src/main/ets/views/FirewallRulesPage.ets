import { LogUtils } from '../utils/LogUtils'
import { ActionButtonStyles, AppColors, AppStyles } from '../constants/AppConstants'
import { CommonStrings } from '../constants/CommonStrings'
import { CommonLabelStrings, EmptyStateStrings, FirewallDialogStrings, FirewallRuleLabelStrings, LoadingStrings } from '../constants/modules/DialogStrings'
import { FirewallStrings } from '../constants/modules/FirewallStrings'
import { FirewallService } from '../services/FirewallService'
import { FirewallCustomRuleService } from '../services/FirewallCustomRuleService'
import { FirewallModeService } from '../services/FirewallModeService'
import { AddRuleDialog } from '../components/AddRuleDialog'
import { UserFirewallControlDialog } from '../components/UserFirewallControlDialog'
import { SubPageHeader } from '../components/SubPageHeader'
import { CompactSummaryCard } from '../components/CompactSummaryCard'
import { netFirewall } from '@kit.NetworkKit'

import { common } from '@kit.AbilityKit'
import { ThemeMode } from '../theme/ThemeColors'
import { FirewallPresetMode, FirewallUserApplyMode } from '../models/DataModels'
import { DialogService } from '../utils/DialogService'
import { UserFirewallModeService } from '../services/UserFirewallModeService'

const TAG = 'FirewallRulesPage'

@ComponentV2
export struct FirewallRulesPage {
  @Param currentMode: FirewallPresetMode = 'custom'
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Local rules: netFirewall.NetFirewallRule[] = []
  @Local conflictNotice: string = ''
  @Local currentTab: number = 0
  @Local isLoading: boolean = false
  @Event onBack: () => void = () => {}
  private userFirewallDialogController?: CustomDialogController

  private addRuleDialogController: CustomDialogController = new CustomDialogController({
    builder: AddRuleDialog({
      currentTheme: this.currentTheme,
      onClose: () => {
        this.addRuleDialogController.close()
      },
      onConfirm: (rule: netFirewall.NetFirewallRule) => {
        this.handleAddRule(rule)
      }
    }),
    autoCancel: false,
    customStyle: true,
    alignment: DialogAlignment.Center
  })

  aboutToAppear() {
    LogUtils.info(TAG, 'aboutToAppear')
    if (this.currentMode !== 'custom') {
      DialogService.openFailure(this.getUIContext(), FirewallStrings.rulesOnlyCustomMode)
      this.onBack()
      return
    }
    this.loadRules()
  }

  aboutToDisappear(): void {
    LogUtils.info(TAG, 'aboutToDisappear')
    this.closeUserFirewallDialog()
  }

  async loadRules() {
    this.isLoading = true
    let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    this.rules = await FirewallCustomRuleService.listRules(context)
    this.updateConflictNotice()
    LogUtils.info(TAG, `loadRules finished: count=${this.rules.length}`)
    this.isLoading = false
  }

  private async persistRules(nextRules: netFirewall.NetFirewallRule[], successMessage: string): Promise<void> {
    let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    let previousRules = this.rules.map((rule: netFirewall.NetFirewallRule) => FirewallService.cloneRuleForCreate(rule))
    LogUtils.info(TAG, `persistRules start: nextCount=${nextRules.length}, previousCount=${previousRules.length}`)
    let result = await FirewallModeService.applyCustomRules(context, nextRules)
    if (!result.success) {
      DialogService.openFailure(
        this.getUIContext(),
        result.errorMessage?.length ? result.errorMessage : FirewallStrings.customRulesApplyFailed
      )
      return
    }
    let saved = await FirewallCustomRuleService.replaceAllRules(context, nextRules)
    if (!saved) {
      let rollbackResult = await FirewallModeService.applyCustomRules(context, previousRules)
      if (!rollbackResult.success) {
      DialogService.openFailure(this.getUIContext(), FirewallStrings.customRulesLocalSaveFailed)
        return
      }
      await this.loadRules()
      DialogService.openFailure(this.getUIContext(), FirewallStrings.customRulesRollbackSuccess)
      return
    }
    LogUtils.info(TAG, `persistRules local template saved: count=${nextRules.length}`)
    let reapplySummary = await UserFirewallModeService.reapplyBindings(context, nextRules)
    await this.loadRules()
    LogUtils.info(TAG,
      `persistRules success: ${successMessage}, reapply total=${reapplySummary.totalUsers}, success=${reapplySummary.successCount}, failed=${reapplySummary.failedCount}`
    )
    if (reapplySummary.failedCount > 0) {
      await DialogService.openFailure(
        this.getUIContext(),
        FirewallStrings.buildReapplyPartialFailedMessage(reapplySummary.successCount, reapplySummary.failedCount)
      )
      return
    }
  }

  async handleAddRule(rule: netFirewall.NetFirewallRule) {
    let conflict = FirewallService.findRuleConflict(this.rules, rule)
    if (conflict) {
      if (conflict.kind === 'duplicate') {
      DialogService.openFailure(this.getUIContext(), FirewallStrings.duplicateRule)
        return
      }
      if (conflict.kind === 'hard_conflict') {
        let conflictRule = conflict.existingRule
      DialogService.openConfirm(this.getUIContext(), {
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
      DialogService.openConfirm(this.getUIContext(), {
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
        currentTheme: this.currentTheme,
        onClose: () => {
          dialogController.close()
        },
        initialRule: rule,
        isEditMode: true,
        onConfirm: (updatedRule: netFirewall.NetFirewallRule) => {
          this.handleEditRule(updatedRule)
        }
      }),
      autoCancel: false,
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
      DialogService.openFailure(this.getUIContext(), FirewallStrings.duplicateRule)
        return
      }
      if (conflict.kind === 'hard_conflict') {
        let conflictRule = conflict.existingRule
      DialogService.openConfirm(this.getUIContext(), {
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
      DialogService.openConfirm(this.getUIContext(), {
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
      DialogService.openConfirm(this.getUIContext(), {
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
        return FirewallRuleLabelStrings.IP_RULE
      case netFirewall.NetFirewallRuleType.RULE_DOMAIN:
        return FirewallRuleLabelStrings.DOMAIN_RULE
      case netFirewall.NetFirewallRuleType.RULE_DNS:
        return FirewallRuleLabelStrings.DNS_RULE
      default:
        return CommonLabelStrings.UNKNOWN
    }
  }

  getRuleTypeBgColor(type: netFirewall.NetFirewallRuleType): string {
    switch (type) {
      case netFirewall.NetFirewallRuleType.RULE_IP:
        return ActionButtonStyles.getPrimaryBackground(this.currentTheme, false) as string
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
    return dir === netFirewall.NetFirewallRuleDirection.RULE_IN
      ? FirewallDialogStrings.DIRECTION_INBOUND
      : FirewallDialogStrings.DIRECTION_OUTBOUND
  }

  getActionLabel(action: netFirewall.FirewallRuleAction): string {
    return action === netFirewall.FirewallRuleAction.RULE_ALLOW ? FirewallDialogStrings.ACTION_ALLOW : FirewallDialogStrings.ACTION_DENY
  }

  getActionBgColor(action: netFirewall.FirewallRuleAction): string {
    return action === netFirewall.FirewallRuleAction.RULE_ALLOW
      ? AppColors.getColors(this.currentTheme).TAG_GREEN_BG
      : ActionButtonStyles.getDangerBackground(this.currentTheme, false) as string
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
        .padding({ left: AppStyles.SPACING_CHIP, right: AppStyles.SPACING_CHIP, top: AppStyles.SPACING_CHIP / 2, bottom: AppStyles.SPACING_CHIP / 2 })
        .backgroundColor(this.currentTab === index ? AppColors.BRAND_PRIMARY : AppColors.getColors(this.currentTheme).BG_COMPONENT)
        .borderRadius(10)
    }
    .padding({ left: AppStyles.SPACING_TAB_BAR_PADDING, right: AppStyles.SPACING_TAB_BAR_PADDING, top: AppStyles.SPACING_CHIP, bottom: AppStyles.SPACING_CHIP })
    .backgroundColor(this.currentTab === index ? AppColors.getColors(this.currentTheme).BG_CARD : Color.Transparent)
    .borderRadius(AppStyles.RADIUS_MD)
  }

  build() {
    Column() {
      SubPageHeader({
        title: FirewallStrings.customModeTitle,
        subtitle: FirewallStrings.customRulesSubtitle,
        currentTheme: this.currentTheme,
        onBack: () => this.onBack(),
        actions: () => {
          this.headerActions()
        }
      })

      Scroll() {
        Column({ space: 18 }) {
        if (this.conflictNotice.length > 0) {
          Row({ space: 8 }) {
            Text(FirewallStrings.conflictWarningLabel)
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.WARNING)
              .padding({ left: AppStyles.SPACING_CHIP, right: AppStyles.SPACING_CHIP, top: AppStyles.PADDING_XS, bottom: AppStyles.PADDING_XS })
              .backgroundColor(AppColors.FIREWALL_CONFLICT_BG)
              .borderRadius(AppStyles.RADIUS_CHIP)

            Text(this.conflictNotice)
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontColor(AppColors.WARNING)
              .layoutWeight(1)
          }
          .width('100%')
          .padding(AppStyles.PADDING_MD)
          .backgroundColor(AppColors.FIREWALL_CONFLICT_PANEL_BG)
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: 1, color: AppColors.FIREWALL_CONFLICT_BORDER })
        }

        Row({ space: AppStyles.PADDING_LG }) {
          CompactSummaryCard({
            title: FirewallStrings.inboundRules,
            valueText: FirewallStrings.buildRuleCountText(this.countRulesByDirection(netFirewall.NetFirewallRuleDirection.RULE_IN)),
            description: FirewallStrings.inboundCustomRulesDescription,
            accentStart: AppColors.WARNING,
            accentEnd: AppColors.GRADIENT_IDENTITY_END,
            icon: $r('app.media.arrow_down'),
            currentTheme: this.currentTheme
          })
            .layoutWeight(1)

          CompactSummaryCard({
            title: FirewallStrings.outboundRules,
            valueText: FirewallStrings.buildRuleCountText(this.countRulesByDirection(netFirewall.NetFirewallRuleDirection.RULE_OUT)),
            description: FirewallStrings.outboundCustomRulesDescription,
            accentStart: AppColors.BRAND_PRIMARY,
            accentEnd: AppColors.GRADIENT_FIREWALL_END,
            icon: $r('app.media.arrow_up'),
            currentTheme: this.currentTheme
          })
            .layoutWeight(1)
        }
        .width('100%')

        Tabs({ barPosition: BarPosition.Start }) {
          TabContent() {
            this.ruleListBuilder()
          }.tabBar(this.tabBuilder(FirewallRuleLabelStrings.ALL_RULES, 0))

          TabContent() {
            this.ruleListBuilder()
          }.tabBar(this.tabBuilder(FirewallRuleLabelStrings.IP_RULE, 1))

          TabContent() {
            this.ruleListBuilder()
          }.tabBar(this.tabBuilder(FirewallRuleLabelStrings.DOMAIN_RULE, 2))

          TabContent() {
            this.ruleListBuilder()
          }.tabBar(this.tabBuilder(FirewallRuleLabelStrings.DNS_RULE, 3))
        }
        .barMode(BarMode.Scrollable)
        .barBackgroundColor(Color.Transparent)
        .divider(null)
        .onChange((index: number) => {
          this.currentTab = index
        })
        .layoutWeight(1)
        }
        .padding({
          left: AppStyles.PADDING_LG,
          right: AppStyles.PADDING_LG,
          top: AppStyles.PADDING_MD,
          bottom: AppStyles.PADDING_LG
        })
        .width('100%')
      }
      .width('100%')
      .layoutWeight(1)
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
          Text(LoadingStrings.LOADING_RULES)
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.getFilteredRules().length === 0) {
        Column({ space: 10 }) {
          Text(EmptyStateStrings.NO_RULES)
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
                        .padding({ left: AppStyles.SPACING_CHIP, right: AppStyles.SPACING_CHIP, top: AppStyles.PADDING_XS, bottom: AppStyles.PADDING_XS })

                      Text(this.getDirectionLabel(rule.direction))
                        .fontSize(AppStyles.FONT_SIZE_CAPTION)
                        .fontColor(ActionButtonStyles.getPrimaryForeground(this.currentTheme))
                        .backgroundColor(ActionButtonStyles.getPrimaryBackground(this.currentTheme, false))
                        .borderRadius(10)
                        .padding({ left: AppStyles.SPACING_CHIP, right: AppStyles.SPACING_CHIP, top: AppStyles.PADDING_XS, bottom: AppStyles.PADDING_XS })

                      Text(this.getActionLabel(rule.action))
                        .fontSize(AppStyles.FONT_SIZE_CAPTION)
                        .fontColor(this.getActionTextColor(rule.action))
                        .backgroundColor(this.getActionBgColor(rule.action))
                        .borderRadius(10)
                        .padding({ left: AppStyles.SPACING_CHIP, right: AppStyles.SPACING_CHIP, top: AppStyles.PADDING_XS, bottom: AppStyles.PADDING_XS })
                    }
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  Row({ space: 8 }) {
                    Button(CommonStrings.actionDelete)
                      .fontSize(AppStyles.FONT_SIZE_CAPTION)
                      .fontColor(AppColors.DANGER)
                      .backgroundColor(ActionButtonStyles.getDangerBackground(this.currentTheme, false))
                      .borderRadius(AppStyles.RADIUS_SM)
                      .height(30)
                      .onClick(() => {
                        this.handleDeleteRule(rule)
                      })
                  }
                }
                .width('100%')

                Column({ space: 10 }) {
                  this.detailRow(FirewallDialogStrings.REMOTE_ADDRESS, this.getRuleAddress(rule))
                  this.detailRow(FirewallDialogStrings.LOCAL_PORT, this.getRuleLocalPort(rule))
                  this.detailRow(FirewallDialogStrings.REMOTE_PORT, this.getRuleRemotePort(rule))
                  this.detailRow(FirewallDialogStrings.PROTOCOL, this.getProtocolLabel(rule))
                }
                .width('100%')
              }
              .width('100%')
              .padding(AppStyles.PADDING_XL)
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

  @Builder
  private headerActions() {
    Row({ space: 12 }) {
      Button(FirewallStrings.userIdControlButton)
        .type(ButtonType.Normal)
        .height(36)
        .padding({ left: 14, right: 14 })
        .fontSize(AppStyles.FONT_SIZE_SMALL)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.BRAND_PRIMARY)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .borderRadius(AppStyles.RADIUS_MD)
        .border({
          width: 1,
          color: AppColors.getColors(this.currentTheme).BORDER
        })
        .onClick(() => {
          this.openUserFirewallDialog()
        })

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
  }

  private openUserFirewallDialog(): void {
    LogUtils.info(TAG, 'openUserFirewallDialog')
    this.closeUserFirewallDialog()
    this.userFirewallDialogController = new CustomDialogController({
      builder: UserFirewallControlDialog({
        controller: this.userFirewallDialogController,
        currentTheme: this.currentTheme,
        onActionCompleted: async (_userId: number, _mode: FirewallUserApplyMode): Promise<void> => {
          await this.loadRules()
        }
      }),
      alignment: DialogAlignment.Center,
      autoCancel: true,
      customStyle: true
    })
    this.userFirewallDialogController.open()
  }

  private closeUserFirewallDialog(): void {
    try {
      this.userFirewallDialogController?.close()
    } catch (_err) {
    } finally {
      this.userFirewallDialogController = undefined
    }
  }
}
