import { LogUtils } from '../../../utils/LogUtils'
import { AppColors, AppStyles } from '../../../constants/AppConstants'
import { AppResources } from '../../../constants/AppResources'
import { ActionText } from '../../../constants/StringCatalog'
import {
  FirewallRuleLabelStrings,
  FirewallPageStrings,
  FirewallRuleStrings
} from '../../../constants/modules/FirewallStrings'
import { AddRuleDialog } from '../../../components/firewall/rules/AddRuleDialog'
import { FirewallRuleList } from '../../../components/firewall/rules/FirewallRuleList'
import { FirewallRulesSummaryCards } from '../../../components/firewall/rules/FirewallRulesSummaryCards'
import { UserFirewallControlDialog } from '../../../components/firewall/user-dispatch/UserFirewallControlDialog'
import { IconTextActionButton } from '../../../components/IconTextActionButton'
import { SubPageHeader } from '../../../components/SubPageHeader'
import { netFirewall } from '@kit.NetworkKit'

import { common } from '@kit.AbilityKit'
import { ThemeMode } from '../../../theme/ThemeColors'
import {
  FirewallPresetMode,
  FirewallUserPolicyMode
} from '../../../services/firewall/FirewallModels'
import { DialogService } from '../../../utils/DialogService'
import { FirewallRulesViewModel } from '../../../viewmodels/firewall/rules/FirewallRulesViewModel'

const TAG = 'FirewallRulesPage'

@ComponentV2
export struct FirewallRulesPage {
  @Param currentMode: FirewallPresetMode = 'custom'
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Param rulesViewModel: FirewallRulesViewModel = new FirewallRulesViewModel()
  @Event onBack: () => void = () => {}
  private userFirewallDialogController?: CustomDialogController
  private addRuleDialogController?: CustomDialogController

  aboutToAppear() {
    LogUtils.info(TAG, 'aboutToAppear')
    if (this.currentMode !== 'custom') {
      DialogService.openFailure(this.getUIContext(), FirewallRuleStrings.ONLY_CUSTOM_MODE)
      this.onBack()
      return
    }
    let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    this.rulesViewModel.initialize(context, this.currentMode)
  }

  aboutToDisappear(): void {
    LogUtils.info(TAG, 'aboutToDisappear')
    this.closeAddRuleDialog()
    this.closeUserFirewallDialog()
  }

  async loadRules() {
    let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    const result = await this.rulesViewModel.loadRules(context)
    LogUtils.info(TAG, `loadRules finished: count=${this.rulesViewModel.rules.length}, success=${result.success}`)
  }

  async handleAddRule(rule: netFirewall.NetFirewallRule): Promise<boolean> {
    let userScopeResult = await this.rulesViewModel.validateRuleUserScopeForSubmit(rule)
    if (!userScopeResult.success) {
      DialogService.openFailure(this.getUIContext(), userScopeResult.errorMessage ?? FirewallRuleStrings.APPLY_FAILED)
      return false
    }
    let conflict = this.rulesViewModel.findConflict(rule)
    if (conflict) {
      if (conflict.kind === 'duplicate') {
        DialogService.openFailure(this.getUIContext(), FirewallRuleStrings.DUPLICATE)
        return false
      }
      if (conflict.kind === 'hard_conflict') {
        let conflictRule = conflict.existingRule
        if (!conflictRule) {
          DialogService.openFailure(this.getUIContext(), FirewallRuleStrings.APPLY_FAILED)
          return false
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
        return true
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
        return true
      }
    }
    return await this.addRuleDirectly(rule)
  }

  private async addRuleDirectly(rule: netFirewall.NetFirewallRule): Promise<boolean> {
    let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    let result = await this.rulesViewModel.addRule(context, rule)
    if (!result.success) {
      DialogService.openFailure(this.getUIContext(), result.errorMessage ?? FirewallRuleStrings.APPLY_FAILED)
    }
    return result.success || (result.successDeployments?.length ?? 0) > 0
  }

  private async openAddRuleDialog(): Promise<void> {
    this.closeAddRuleDialog()
    let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    let result = await this.rulesViewModel.prepareRuleEditor(context)
    if (!result.success) {
      DialogService.openFailure(this.getUIContext(), result.errorMessage ?? FirewallRuleStrings.APPLY_FAILED)
      return
    }
    this.addRuleDialogController = new CustomDialogController({
      builder: AddRuleDialog({
        currentTheme: this.currentTheme,
        userOptions: this.rulesViewModel.userOptions,
        isSubmitting: this.rulesViewModel.isLoading,
        onClose: () => {
          this.closeAddRuleDialog()
        },
        onConfirm: async (rule: netFirewall.NetFirewallRule): Promise<boolean> => {
          return await this.handleAddRule(rule)
        }
      }),
      autoCancel: false,
      customStyle: true,
      alignment: DialogAlignment.Center
    })
    this.addRuleDialogController.open()
  }

  private closeAddRuleDialog(): void {
    try {
      this.addRuleDialogController?.close()
    } catch (_err) {
    } finally {
      this.addRuleDialogController = undefined
    }
  }

  private async openEditRuleDialog(rule: netFirewall.NetFirewallRule): Promise<void> {
    let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    let result = await this.rulesViewModel.prepareRuleEditor(context)
    if (!result.success) {
      DialogService.openFailure(this.getUIContext(), result.errorMessage ?? FirewallRuleStrings.APPLY_FAILED)
      return
    }
    let dialogController = new CustomDialogController({
      builder: AddRuleDialog({
        currentTheme: this.currentTheme,
        userOptions: this.rulesViewModel.userOptions,
        isSubmitting: this.rulesViewModel.isLoading,
        onClose: () => {
          dialogController.close()
        },
        initialRule: rule,
        isEditMode: true,
        onConfirm: async (updatedRule: netFirewall.NetFirewallRule): Promise<boolean> => {
          return await this.handleEditRule(updatedRule)
        }
      }),
      autoCancel: false,
      customStyle: true,
      alignment: DialogAlignment.Center
    })
    dialogController.open()
  }

  async handleEditRule(rule: netFirewall.NetFirewallRule): Promise<boolean> {
    let userScopeResult = await this.rulesViewModel.validateRuleUserScopeForSubmit(rule)
    if (!userScopeResult.success) {
      DialogService.openFailure(this.getUIContext(), userScopeResult.errorMessage ?? FirewallRuleStrings.APPLY_FAILED)
      return false
    }
    let currentRuleId = this.rulesViewModel.getLocalRuleId(rule)
    let comparableRules = this.rulesViewModel.rules.filter((item: netFirewall.NetFirewallRule) => this.rulesViewModel.getLocalRuleId(item) !== currentRuleId)
    let conflict = this.rulesViewModel.findConflict(rule, comparableRules)
    if (conflict) {
      if (conflict.kind === 'duplicate') {
        DialogService.openFailure(this.getUIContext(), FirewallRuleStrings.DUPLICATE)
        return false
      }
      if (conflict.kind === 'hard_conflict') {
        let conflictRule = conflict.existingRule
        if (!conflictRule) {
          DialogService.openFailure(this.getUIContext(), FirewallRuleStrings.APPLY_FAILED)
          return false
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
        return true
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
        return true
      }
    }
    return await this.updateRuleDirectly(rule)
  }

  private async updateRuleDirectly(rule: netFirewall.NetFirewallRule): Promise<boolean> {
    let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    let result = await this.rulesViewModel.updateRule(context, rule)
    if (!result.success) {
      DialogService.openFailure(this.getUIContext(), result.errorMessage ?? FirewallRuleStrings.APPLY_FAILED)
    }
    return result.success || (result.successDeployments?.length ?? 0) > 0
  }

  private async replaceConflictRule(
    conflictRule: netFirewall.NetFirewallRule,
    nextRule: netFirewall.NetFirewallRule,
    isEditMode: boolean
  ): Promise<void> {
    let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    let result = await this.rulesViewModel.replaceConflictRule(context, conflictRule, nextRule, isEditMode)
    if (!result.success) {
      DialogService.openFailure(this.getUIContext(), result.errorMessage ?? FirewallRuleStrings.APPLY_FAILED)
    }
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
    let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    let result = await this.rulesViewModel.deleteRule(context, rule)
    if (!result.success) {
      DialogService.openFailure(this.getUIContext(), result.errorMessage ?? FirewallRuleStrings.APPLY_FAILED)
    }
  }

  countRulesByDirection(direction: netFirewall.NetFirewallRuleDirection): number {
    return this.rulesViewModel.countRulesByDirection(direction)
  }

  getRulesByTab(tabIndex: number): netFirewall.NetFirewallRule[] {
    return this.rulesViewModel.getRulesByTab(tabIndex)
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

      Column({ space: 6 }) {
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
          .border({ width: AppStyles.DIVIDER_HEIGHT, color: AppColors.FIREWALL_CONFLICT_BORDER })
        }

        FirewallRulesSummaryCards({
          defaultPolicyItems: this.rulesViewModel.defaultPolicyItems,
          inboundRuleCount: this.countRulesByDirection(netFirewall.NetFirewallRuleDirection.RULE_IN),
          outboundRuleCount: this.countRulesByDirection(netFirewall.NetFirewallRuleDirection.RULE_OUT),
          currentTheme: this.currentTheme
        })

        Tabs({ barPosition: BarPosition.Start, index: this.rulesViewModel.currentTab }) {
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
        top: AppStyles.PADDING_XS,
        bottom: AppStyles.PADDING_MD
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }

  @Builder
  ruleListBuilder(tabIndex: number) {
    FirewallRuleList({
      rules: this.getRulesByTab(tabIndex),
      isLoading: this.rulesViewModel.isLoading,
      currentTheme: this.currentTheme,
      getUserScopeLabel: (rule: netFirewall.NetFirewallRule): string => this.rulesViewModel.getRuleUserScopeLabel(rule),
      onEditRule: (rule: netFirewall.NetFirewallRule) => {
        this.openEditRuleDialog(rule)
      },
      onDeleteRule: (rule: netFirewall.NetFirewallRule) => {
        this.handleDeleteRule(rule)
      }
    })
  }

  @Builder
  private headerActions() {
    Row({ space: 12 }) {
      IconTextActionButton({
        label: FirewallPageStrings.USER_ID_CONTROL_BUTTON,
        icon: AppResources.GLOBE_ICON,
        kind: 'primary',
        currentTheme: this.currentTheme,
        onTap: () => {
          this.openUserFirewallDialog()
        }
      })

      IconTextActionButton({
        label: FirewallRuleStrings.ADD_BUTTON,
        icon: AppResources.FIREWALL_ICON,
        kind: 'primary',
        currentTheme: this.currentTheme,
        onTap: () => {
          this.openAddRuleDialog()
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
        onActionCompleted: async (_userId: number, _mode: FirewallUserPolicyMode): Promise<void> => {
          await this.loadRules()
        }
      }),
      alignment: DialogAlignment.Center,
      autoCancel: false,
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
