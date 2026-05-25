import { AppColors, AppStyles } from '../../../constants/AppConstants'
import { netFirewall } from '@kit.NetworkKit'
import { DialogService } from '../../../utils/DialogService'
import { ThemeMode } from '../../../theme/ThemeColors'
import { ActionText } from '../../../constants/StringCatalog'
import { FirewallDialogStrings, FirewallRuleLabelStrings, FirewallUserStrings } from '../../../constants/modules/FirewallStrings'
import { DetailDialogShell } from '../../DetailDialogShell'
import { StyledSelect } from '../../StyledSelect'
import { StyledTextInput } from '../../StyledTextInput'
import { MultiCheckSelect } from '../../MultiCheckSelect'
import {
  FIREWALL_PROTOCOL_TCP,
  FIREWALL_RULE_PROTOCOL_OPTIONS,
  FIREWALL_RULE_TYPE_OPTIONS,
  normalizeFirewallRuleUserIds,
  UserFirewallOption
} from '../../../services/firewall/FirewallModels'
import { FirewallRuleFormModel, FirewallRuleFormState } from './FirewallRuleFormModel'

@CustomDialog
export struct AddRuleDialog {
  controller: CustomDialogController
  onConfirm: (rule: netFirewall.NetFirewallRule) => Promise<boolean> = async (_rule: netFirewall.NetFirewallRule) => true
  onClose: () => void = () => {}
  initialRule?: netFirewall.NetFirewallRule
  isEditMode: boolean = false
  currentTheme: ThemeMode = ThemeMode.LIGHT
  userOptions: UserFirewallOption[] = []
  isSubmitting: boolean = false

  @State ruleName: string = ''
  @State ruleType: number = netFirewall.NetFirewallRuleType.RULE_IP
  @State ruleDirection: number = netFirewall.NetFirewallRuleDirection.RULE_IN
  @State protocol: number = FIREWALL_PROTOCOL_TCP
  @State remoteAddress: string = ''
  @State standbyDns: string = ''
  @State localPort: string = ''
  @State remotePort: string = ''
  @State action: number = netFirewall.FirewallRuleAction.RULE_ALLOW
  @State selectedUserIds: number[] = []
  @State submitting: boolean = false
  private readonly ruleTypeOptions: SelectOption[] = [
    { value: FirewallRuleLabelStrings.IP_RULE },
    { value: FirewallRuleLabelStrings.DOMAIN_RULE },
    { value: FirewallRuleLabelStrings.DNS_RULE }
  ]
  private readonly ruleTypeValues: number[] = FIREWALL_RULE_TYPE_OPTIONS
  private readonly directionOptions: SelectOption[] = [
    { value: FirewallDialogStrings.DIRECTION_INBOUND },
    { value: FirewallDialogStrings.DIRECTION_OUTBOUND }
  ]
  private readonly directionValues: number[] = [
    netFirewall.NetFirewallRuleDirection.RULE_IN,
    netFirewall.NetFirewallRuleDirection.RULE_OUT
  ]
  private readonly protocolOptions: SelectOption[] = [
    { value: FirewallDialogStrings.PROTOCOL_TCP },
    { value: FirewallDialogStrings.PROTOCOL_UDP },
    { value: FirewallDialogStrings.PROTOCOL_ICMP }
  ]
  private readonly protocolValues: number[] = FIREWALL_RULE_PROTOCOL_OPTIONS
  private readonly actionOptions: SelectOption[] = [
    { value: FirewallDialogStrings.ACTION_ALLOW },
    { value: FirewallDialogStrings.ACTION_DENY }
  ]
  private readonly actionValues: number[] = [
    netFirewall.FirewallRuleAction.RULE_ALLOW,
    netFirewall.FirewallRuleAction.RULE_DENY
  ]

  aboutToAppear(): void {
    this.applyFormState(FirewallRuleFormModel.buildInitialState(this.initialRule, this.userOptions))
  }

  private applyFormState(state: FirewallRuleFormState): void {
    this.ruleName = state.ruleName
    this.ruleType = state.ruleType
    this.ruleDirection = state.ruleDirection
    this.protocol = state.protocol
    this.remoteAddress = state.remoteAddress
    this.standbyDns = state.standbyDns
    this.localPort = state.localPort
    this.remotePort = state.remotePort
    this.action = state.action
    this.selectedUserIds = state.selectedUserIds
  }

  private getFormState(): FirewallRuleFormState {
    return {
      ruleName: this.ruleName,
      ruleType: this.ruleType,
      ruleDirection: this.ruleDirection,
      protocol: this.protocol,
      remoteAddress: this.remoteAddress,
      standbyDns: this.standbyDns,
      localPort: this.localPort,
      remotePort: this.remotePort,
      action: this.action,
      selectedUserIds: this.selectedUserIds
    }
  }

  private getIpFieldLabel(): string {
    return this.ruleDirection === netFirewall.NetFirewallRuleDirection.RULE_IN
      ? FirewallDialogStrings.LOCAL_ADDRESS
      : FirewallDialogStrings.REMOTE_ADDRESS
  }

  private validateForm(): string {
    return FirewallRuleFormModel.validate(this.getFormState())
  }

  private async handleSubmit(): Promise<void> {
    if (this.submitting || this.isSubmitting) {
      return
    }
    let validationMessage = this.validateForm()
    if (validationMessage.length > 0) {
      DialogService.openFailure(this.getUIContext(), validationMessage)
      return
    }

    let rule = FirewallRuleFormModel.buildRule(this.getFormState(), this.initialRule, this.isEditMode)
    this.submitting = true
    try {
      let shouldClose = await this.onConfirm(rule)
      if (shouldClose) {
        this.closeDialog()
      }
    } finally {
      this.submitting = false
    }
  }

  private closeDialog(): void {
    this.onClose()
  }

  private getPrimaryButtonText(): string {
    return this.isEditMode ? ActionText.SAVE : ActionText.ADD
  }

  private getTertiaryButtonBackground(): ResourceColor {
    return this.currentTheme === ThemeMode.DARK
      ? AppColors.INTERACTIVE_SECONDARY_BG_DARK
      : AppColors.getColors(this.currentTheme).BG_PAGE
  }

  private getSelectedProtocolIndex(): number {
    const protocolIndex = this.protocolValues.indexOf(this.protocol)
    return protocolIndex >= 0 ? protocolIndex : 0
  }

  private getSelectedProtocolLabel(): string {
    return (this.protocolOptions[this.getSelectedProtocolIndex()]?.value as string) ?? FirewallDialogStrings.PROTOCOL_TCP
  }

  private getSelectedRuleTypeIndex(): number {
    let index = this.ruleTypeValues.indexOf(this.ruleType)
    return index >= 0 ? index : 0
  }

  private getSelectedRuleTypeLabel(): string {
    return (this.ruleTypeOptions[this.getSelectedRuleTypeIndex()]?.value as string) ?? FirewallRuleLabelStrings.IP_RULE
  }

  private getSelectedDirectionIndex(): number {
    let index = this.directionValues.indexOf(this.ruleDirection)
    return index >= 0 ? index : 0
  }

  private getSelectedDirectionLabel(): string {
    return (this.directionOptions[this.getSelectedDirectionIndex()]?.value as string) ?? FirewallDialogStrings.DIRECTION_INBOUND
  }

  private getSelectedActionIndex(): number {
    let index = this.actionValues.indexOf(this.action)
    return index >= 0 ? index : 0
  }

  private getSelectedActionLabel(): string {
    return (this.actionOptions[this.getSelectedActionIndex()]?.value as string) ?? FirewallDialogStrings.ACTION_ALLOW
  }

  private getRuleTypeLabel(): string {
    if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_DOMAIN) {
      return FirewallRuleLabelStrings.DOMAIN_RULE
    }
    if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_DNS) {
      return FirewallDialogStrings.PRIMARY_DNS
    }
    return this.getIpFieldLabel()
  }

  private getRuleTypePlaceholder(): string {
    if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_DOMAIN) {
      return FirewallDialogStrings.DOMAIN_PLACEHOLDER
    }
    if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_DNS) {
      return FirewallDialogStrings.DNS_PLACEHOLDER
    }
    return FirewallDialogStrings.IP_PLACEHOLDER
  }

  @Builder
  private formContent() {
    Column({ space: 16 }) {
      Column({ space: 6 }) {
        Text(FirewallDialogStrings.RULE_NAME)
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        StyledTextInput({
          text: this.ruleName,
          placeholder: FirewallDialogStrings.RULE_NAME_PLACEHOLDER,
          currentTheme: this.currentTheme,
          onChange: (value: string) => { this.ruleName = value }
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 6 }) {
        Text(FirewallDialogStrings.RULE_TYPE)
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        StyledSelect({
          options: this.ruleTypeOptions,
          selectedIndex: this.getSelectedRuleTypeIndex(),
          value: this.getSelectedRuleTypeLabel(),
          currentTheme: this.currentTheme,
          onSelect: (index: number) => { this.ruleType = this.ruleTypeValues[index] ?? this.ruleTypeValues[0] }
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 6 }) {
        Text(FirewallDialogStrings.RULE_DIRECTION)
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        StyledSelect({
          options: this.directionOptions,
          selectedIndex: this.getSelectedDirectionIndex(),
          value: this.getSelectedDirectionLabel(),
          currentTheme: this.currentTheme,
          onSelect: (index: number) => {
            let nextDirection = this.directionValues[index] ?? this.directionValues[0]
            if (nextDirection === this.ruleDirection) {
              return
            }
            let currentPort = this.ruleDirection === netFirewall.NetFirewallRuleDirection.RULE_IN ? this.localPort : this.remotePort
            this.ruleDirection = nextDirection
            if (this.ruleDirection === netFirewall.NetFirewallRuleDirection.RULE_IN) {
              this.localPort = currentPort
              this.remotePort = ''
              return
            }
            this.remotePort = currentPort
            this.localPort = ''
          }
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_IP) {
        Column({ space: 6 }) {
          Text(FirewallDialogStrings.PROTOCOL)
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          StyledSelect({
            options: this.protocolOptions,
            selectedIndex: this.getSelectedProtocolIndex(),
            value: this.getSelectedProtocolLabel(),
            currentTheme: this.currentTheme,
            onSelect: (index: number) => {
              this.protocol = this.protocolValues[index] ?? this.protocolValues[0]
            }
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      Column({ space: 6 }) {
        Text(this.getRuleTypeLabel())
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        StyledTextInput({
          text: this.remoteAddress,
          placeholder: this.getRuleTypePlaceholder(),
          currentTheme: this.currentTheme,
          onChange: (value: string) => { this.remoteAddress = value }
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_DNS) {
        Column({ space: 6 }) {
          Text(FirewallDialogStrings.STANDBY_DNS)
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          StyledTextInput({
            text: this.standbyDns,
            placeholder: FirewallDialogStrings.STANDBY_DNS_PLACEHOLDER,
            currentTheme: this.currentTheme,
            onChange: (value: string) => { this.standbyDns = value }
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      if (this.ruleType === netFirewall.NetFirewallRuleType.RULE_IP) {
        Column({ space: 6 }) {
          Text(this.ruleDirection === netFirewall.NetFirewallRuleDirection.RULE_IN
            ? FirewallDialogStrings.LOCAL_PORT
            : FirewallDialogStrings.REMOTE_PORT)
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          StyledTextInput({
            text: this.ruleDirection === netFirewall.NetFirewallRuleDirection.RULE_IN ? this.localPort : this.remotePort,
            placeholder: FirewallDialogStrings.PORT_PLACEHOLDER,
            currentTheme: this.currentTheme,
            onChange: (value: string) => {
              if (this.ruleDirection === netFirewall.NetFirewallRuleDirection.RULE_IN) {
                this.localPort = value
                this.remotePort = ''
                return
              }
              this.remotePort = value
              this.localPort = ''
            }
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      Column({ space: 6 }) {
        Text(FirewallDialogStrings.USER_SCOPE)
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)

        if (this.userOptions.length === 0) {
          Text(FirewallUserStrings.NO_ACTIVATED_USERS)
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
            .width('100%')
        } else {
          MultiCheckSelect({
            options: this.userOptions,
            selectedValues: this.selectedUserIds,
            placeholder: FirewallDialogStrings.USER_SCOPE_PLACEHOLDER,
            allLabel: FirewallDialogStrings.ALL_VALUE,
            currentTheme: this.currentTheme,
            onChange: (selectedUserIds: number[]) => {
              this.selectedUserIds = normalizeFirewallRuleUserIds(selectedUserIds)
            }
          })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 6 }) {
        Text(FirewallDialogStrings.ACTION)
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        StyledSelect({
          options: this.actionOptions,
          selectedIndex: this.getSelectedActionIndex(),
          value: this.getSelectedActionLabel(),
          currentTheme: this.currentTheme,
          onSelect: (index: number) => { this.action = this.actionValues[index] ?? this.actionValues[0] }
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row({ space: 16 }) {
        Button(ActionText.CANCEL)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .backgroundColor(this.getTertiaryButtonBackground())
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: AppStyles.DIVIDER_HEIGHT, color: AppColors.getColors(this.currentTheme).BORDER, style: BorderStyle.Solid })
          .layoutWeight(1)
          .height(AppStyles.BUTTON_HEIGHT)
          .enabled(!this.submitting && !this.isSubmitting)
          .opacity(!this.submitting && !this.isSubmitting ? 1 : 0.5)
          .onClick(() => {
            this.closeDialog()
          })
        Button(this.getPrimaryButtonText())
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(Color.White)
          .backgroundColor(AppColors.BRAND_PRIMARY)
          .borderRadius(AppStyles.RADIUS_MD)
          .layoutWeight(1)
          .height(AppStyles.BUTTON_HEIGHT)
          .enabled(!this.submitting && !this.isSubmitting)
          .opacity(!this.submitting && !this.isSubmitting ? 1 : 0.5)
          .onClick(() => {
            this.handleSubmit()
          })
      }
      .width('100%')
    }
    .margin({ top: 8 })
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    DetailDialogShell({
      dialogWidth: AppStyles.DIALOG_WIDTH_MEDIUM,
      maxBodyHeight: AppStyles.DIALOG_BODY_MAX_HEIGHT_LARGE,
      currentTheme: this.currentTheme,
      showHeader: false,
      showCloseAction: false,
      onClose: () => {
        this.closeDialog()
      },
      content: () => {
        this.formContent()
      }
    })
  }
}
