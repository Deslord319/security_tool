import { LogUtils } from '../../../utils/LogUtils'
import { ActionButtonStyles, AppColors, AppStyles } from '../../../constants/AppConstants'
import { ActionText, LabelText } from '../../../constants/StringCatalog'
import { EmptyStateStrings, FirewallDialogStrings, FirewallRuleLabelStrings, LoadingStrings } from '../../../constants/modules/DialogStrings'
import {
  FirewallPageStrings,
  FirewallRuleStrings,
  buildFirewallReapplyPartialFailedMessage,
  buildFirewallRuleCountText
} from '../../../constants/modules/FirewallStrings'
import { AddRuleDialog } from '../../../components/firewall/rules/AddRuleDialog'
import { UserFirewallControlDialog } from '../../../components/firewall/user-dispatch/UserFirewallControlDialog'
import { IconTextActionButton } from '../../../components/IconTextActionButton'
import { SubPageHeader } from '../../../components/SubPageHeader'
import { BaseCard } from '../../../components/BaseCard'
import { CompactSummaryCard } from '../../../components/CompactSummaryCard'
import { netFirewall } from '@kit.NetworkKit'

import { common } from '@kit.AbilityKit'
import { ThemeMode } from '../../../theme/ThemeColors'
import { getScrollBarColor, SCROLL_BAR_WIDTH_DEFAULT, SCROLL_BAR_WIDTH_HOVER } from '../../../utils/ScrollBarStyleUtils'
import { FirewallPresetMode, FirewallUserApplyMode } from '../../../models/DataModels'
import { DialogService } from '../../../utils/DialogService'
import { FirewallRulesViewModel } from '../../../viewmodels/firewall/rules/FirewallRulesViewModel'

const TAG = 'FirewallRulesPage'
const RULE_CARD_WIDTH_PERCENT = '100%'

@ComponentV2
export struct FirewallRulesPage {
  @Param currentMode: FirewallPresetMode = 'custom'
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Param rulesViewModel: FirewallRulesViewModel = new FirewallRulesViewModel()
  @Event onBack: () => void = () => {}
  private userFirewallDialogController?: CustomDialogController
  @Local private listScrollBarWidth: number = SCROLL_BAR_WIDTH_DEFAULT

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
      DialogService.openFailure(this.getUIContext(), FirewallRuleStrings.ONLY_CUSTOM_MODE)
      this.onBack()
      return
    }
    let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    void this.rulesViewModel.initialize(context, this.currentMode)
  }

  aboutToDisappear(): void {
    LogUtils.info(TAG, 'aboutToDisappear')
    this.closeUserFirewallDialog()
  }

  async loadRules() {
    let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    const result = await this.rulesViewModel.loadRules(context)
    LogUtils.info(TAG, `loadRules finished: count=${this.rulesViewModel.rules.length}, success=${result.success}`)
  }

  private async persistRules(nextRules: netFirewall.NetFirewallRule[], successMessage: string): Promise<void> {
    let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    LogUtils.info(TAG, `persistRules start: nextCount=${nextRules.length}, currentCount=${this.rulesViewModel.rules.length}`)
    let result = await this.rulesViewModel.saveRules(context, nextRules, successMessage)
    if (!result.success) {
      DialogService.openFailure(
        this.getUIContext(),
        result.errorMessage?.length ? result.errorMessage : FirewallRuleStrings.APPLY_FAILED
      )
      return
    }
    LogUtils.info(TAG,
      `persistRules success: ${successMessage}, reapply total=${result.reapplyTotalUsers ?? 0}, success=${result.reapplySuccessCount ?? 0}, failed=${result.reapplyFailedCount ?? 0}`
    )
    if ((result.reapplyFailedCount ?? 0) > 0) {
      await DialogService.openFailure(
        this.getUIContext(),
        buildFirewallReapplyPartialFailedMessage(result.reapplySuccessCount ?? 0, result.reapplyFailedCount ?? 0)
      )
      return
    }
  }

  async handleAddRule(rule: netFirewall.NetFirewallRule) {
    let conflict = this.rulesViewModel.findConflict(rule)
    if (conflict) {
      if (conflict.kind === 'duplicate') {
        DialogService.openFailure(this.getUIContext(), FirewallRuleStrings.DUPLICATE)
        return
      }
      if (conflict.kind === 'hard_conflict') {
        let conflictRule = conflict.existingRule
        if (!conflictRule) {
          DialogService.openFailure(this.getUIContext(), FirewallRuleStrings.APPLY_FAILED)
          return
        }
        const conflictRuleValue: netFirewall.NetFirewallRule = conflictRule
        DialogService.openConfirm(this.getUIContext(), {
          title: FirewallRuleStrings.CONFLICT_TITLE,
          message: FirewallRuleStrings.CONFLICT_REPLACE_MESSAGE,
      confirmText: ActionText.OVERRIDE,
      cancelText: ActionText.CANCEL,
          onConfirm: () => {
            this.replaceConflictRule(conflictRuleValue, rule, false)
          }
        })
        return
      }
      if (conflict.kind === 'overlap_conflict') {
        DialogService.openConfirm(this.getUIContext(), {
          title: FirewallRuleStrings.OVERLAP_TITLE,
          message: FirewallRuleStrings.OVERLAP_ADD_MESSAGE,
      confirmText: ActionText.CONTINUE,
      cancelText: ActionText.CANCEL,
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
    let nextRules = [...this.rulesViewModel.rules, rule]
    await this.persistRules(nextRules, FirewallRuleStrings.ADD_SUCCESS)
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
    let currentRuleId = this.rulesViewModel.getLocalRuleId(rule)
    let comparableRules = this.rulesViewModel.rules.filter((item: netFirewall.NetFirewallRule) => this.rulesViewModel.getLocalRuleId(item) !== currentRuleId)
    let conflict = this.rulesViewModel.findConflict(rule, comparableRules)
    if (conflict) {
      if (conflict.kind === 'duplicate') {
        DialogService.openFailure(this.getUIContext(), FirewallRuleStrings.DUPLICATE)
        return
      }
      if (conflict.kind === 'hard_conflict') {
        let conflictRule = conflict.existingRule
        if (!conflictRule) {
          DialogService.openFailure(this.getUIContext(), FirewallRuleStrings.APPLY_FAILED)
          return
        }
        const conflictRuleValue: netFirewall.NetFirewallRule = conflictRule
        DialogService.openConfirm(this.getUIContext(), {
          title: FirewallRuleStrings.CONFLICT_TITLE,
          message: FirewallRuleStrings.CONFLICT_REPLACE_AND_SAVE_MESSAGE,
      confirmText: ActionText.OVERRIDE,
      cancelText: ActionText.CANCEL,
          onConfirm: () => {
            this.replaceConflictRule(conflictRuleValue, rule, true)
          }
        })
        return
      }
      if (conflict.kind === 'overlap_conflict') {
        DialogService.openConfirm(this.getUIContext(), {
          title: FirewallRuleStrings.OVERLAP_TITLE,
          message: FirewallRuleStrings.OVERLAP_EDIT_MESSAGE,
      confirmText: ActionText.CONTINUE,
      cancelText: ActionText.CANCEL,
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
    let localRuleId = this.rulesViewModel.getLocalRuleId(rule)
    let nextRules = this.rulesViewModel.rules.map((item: netFirewall.NetFirewallRule) =>
      this.rulesViewModel.getLocalRuleId(item) === localRuleId ? rule : item
    )
    await this.persistRules(nextRules, FirewallRuleStrings.UPDATE_SUCCESS)
  }

  private async replaceConflictRule(
    conflictRule: netFirewall.NetFirewallRule,
    nextRule: netFirewall.NetFirewallRule,
    isEditMode: boolean
  ): Promise<void> {
    let conflictRuleId = this.rulesViewModel.getLocalRuleId(conflictRule)
    let nextRules = this.rulesViewModel.rules.filter((item: netFirewall.NetFirewallRule) => this.rulesViewModel.getLocalRuleId(item) !== conflictRuleId)
    if (isEditMode) {
      let currentRuleId = this.rulesViewModel.getLocalRuleId(nextRule)
      nextRules = nextRules.map((item: netFirewall.NetFirewallRule) =>
        this.rulesViewModel.getLocalRuleId(item) === currentRuleId ? nextRule : item
      )
    } else {
      nextRules.push(nextRule)
    }
    await this.persistRules(nextRules, isEditMode ? FirewallRuleStrings.REPLACE_SUCCESS : FirewallRuleStrings.OVERWRITE_SUCCESS)
  }

  async handleDeleteRule(rule: netFirewall.NetFirewallRule) {
    DialogService.openConfirm(this.getUIContext(), {
      title: FirewallRuleStrings.DELETE_TITLE,
      message: FirewallRuleStrings.DELETE_MESSAGE,
      confirmText: ActionText.DELETE,
      cancelText: ActionText.CANCEL,
      onConfirm: () => {
        this.deleteRuleDirectly(rule)
      }
    })
  }

  private async deleteRuleDirectly(rule: netFirewall.NetFirewallRule): Promise<void> {
    let localRuleId = this.rulesViewModel.getLocalRuleId(rule)
    let nextRules = this.rulesViewModel.rules.filter((item: netFirewall.NetFirewallRule) => this.rulesViewModel.getLocalRuleId(item) !== localRuleId)
    await this.persistRules(nextRules, FirewallRuleStrings.DELETE_SUCCESS)
  }

  countRulesByType(type: netFirewall.NetFirewallRuleType): number {
    return this.rulesViewModel.countRulesByType(type)
  }

  countRulesByDirection(direction: netFirewall.NetFirewallRuleDirection): number {
    return this.rulesViewModel.countRulesByDirection(direction)
  }

  getRulesByTab(tabIndex: number): netFirewall.NetFirewallRule[] {
    return this.rulesViewModel.getRulesByTab(tabIndex)
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
      return LabelText.UNKNOWN
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
        return FirewallDialogStrings.PROTOCOL_TCP
      case 17:
        return FirewallDialogStrings.PROTOCOL_UDP
      case 1:
        return FirewallDialogStrings.PROTOCOL_ICMP
      default:
        return 'ALL'
    }
  }

  @Builder
  tabBuilder(title: string, index: number) {
    Column() {
      Text(title)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(this.rulesViewModel.currentTab === index ? FontWeight.Bold : FontWeight.Regular)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(this.rulesViewModel.currentTab === index
          ? AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY
          : AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
    }
    .padding({
      left: AppStyles.SPACING_TAB_BAR_ITEM_HORIZONTAL,
      right: AppStyles.SPACING_TAB_BAR_ITEM_HORIZONTAL,
      top: AppStyles.SPACING_TAB_BAR_ITEM_VERTICAL,
      bottom: AppStyles.SPACING_TAB_BAR_ITEM_VERTICAL
    })
  }

  build() {
    Column() {
      SubPageHeader({
        title: FirewallRuleStrings.CUSTOM_MODE_TITLE,
        subtitle: FirewallRuleStrings.CUSTOM_RULES_SUBTITLE,
        currentTheme: this.currentTheme,
        onBack: () => this.onBack(),
        actions: () => {
          this.headerActions()
        }
      })

      Column({ space: 14 }) {
        if (this.rulesViewModel.conflictNotice.length > 0) {
          Row({ space: 8 }) {
            Text(FirewallRuleStrings.WARNING_LABEL)
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.WARNING)
              .padding({ left: AppStyles.SPACING_CHIP, right: AppStyles.SPACING_CHIP, top: AppStyles.PADDING_XS, bottom: AppStyles.PADDING_XS })
              .backgroundColor(AppColors.FIREWALL_CONFLICT_BG)
              .borderRadius(AppStyles.RADIUS_CHIP)

            Text(this.rulesViewModel.conflictNotice)
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
            title: FirewallRuleStrings.INBOUND,
            valueText: buildFirewallRuleCountText(this.countRulesByDirection(netFirewall.NetFirewallRuleDirection.RULE_IN)),
            description: FirewallRuleStrings.INBOUND_DESCRIPTION,
            accentStart: AppColors.WARNING,
            accentEnd: AppColors.GRADIENT_IDENTITY_END,
            icon: $r('app.media.arrow_down'),
            currentTheme: this.currentTheme
          })
            .layoutWeight(1)

          CompactSummaryCard({
            title: FirewallRuleStrings.OUTBOUND,
            valueText: buildFirewallRuleCountText(this.countRulesByDirection(netFirewall.NetFirewallRuleDirection.RULE_OUT)),
            description: FirewallRuleStrings.OUTBOUND_DESCRIPTION,
            accentStart: AppColors.BRAND_PRIMARY,
            accentEnd: AppColors.GRADIENT_FIREWALL_END,
            icon: $r('app.media.arrow_up'),
            currentTheme: this.currentTheme
          })
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG })

        Tabs({ barPosition: BarPosition.Start }) {
          TabContent() {
            this.ruleListBuilder(0)
          }.tabBar(this.tabBuilder(FirewallRuleLabelStrings.ALL_RULES, 0))

          TabContent() {
            this.ruleListBuilder(1)
          }.tabBar(this.tabBuilder(FirewallRuleLabelStrings.IP_RULE, 1))

          TabContent() {
            this.ruleListBuilder(2)
          }.tabBar(this.tabBuilder(FirewallRuleLabelStrings.DOMAIN_RULE, 2))

          TabContent() {
            this.ruleListBuilder(3)
          }.tabBar(this.tabBuilder(FirewallRuleLabelStrings.DNS_RULE, 3))
        }
        .barMode(BarMode.Scrollable)
        .barBackgroundColor(Color.Transparent)
        .divider(null)
        .onChange((index: number) => {
          this.rulesViewModel.setCurrentTab(index)
        })
        .layoutWeight(1)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({
        top: AppStyles.PADDING_SM,
        bottom: AppStyles.PADDING_MD
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }

  @Builder
  ruleListBuilder(tabIndex: number) {
    Column() {
      if (this.rulesViewModel.isLoading) {
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
      } else if (this.getRulesByTab(tabIndex).length === 0) {
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
          ForEach(this.getRulesByTab(tabIndex), (rule: netFirewall.NetFirewallRule) => {
            ListItem() {
              Row() {
                Column() {
                  BaseCard({
                    useAutoHeight: true,
                    clickable: true,
                    currentTheme: this.currentTheme,
                    onPress: () => {
                      this.openEditRuleDialog(rule)
                    }
                  }) {
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
      Button(ActionText.DELETE)
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
                  }
                }
                .width(RULE_CARD_WIDTH_PERCENT)
              }
              .width('100%')
              .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG })
              .justifyContent(FlexAlign.Center)
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .scrollBarColor(getScrollBarColor(this.currentTheme))
        .scrollBarWidth(this.listScrollBarWidth)
        .onHover((isHover: boolean) => {
          this.listScrollBarWidth = isHover ? SCROLL_BAR_WIDTH_HOVER : SCROLL_BAR_WIDTH_DEFAULT
        })
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: AppStyles.PADDING_SM, bottom: 0 })
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
      IconTextActionButton({
        label: FirewallPageStrings.USER_ID_CONTROL_BUTTON,
        icon: $r('app.media.globe'),
        kind: 'primary',
        currentTheme: this.currentTheme,
        onTap: () => {
          this.openUserFirewallDialog()
        }
      })

      IconTextActionButton({
        label: FirewallRuleStrings.ADD_BUTTON,
        icon: $r('app.media.firewall'),
        kind: 'primary',
        currentTheme: this.currentTheme,
        onTap: () => {
          this.addRuleDialogController.open()
        }
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
