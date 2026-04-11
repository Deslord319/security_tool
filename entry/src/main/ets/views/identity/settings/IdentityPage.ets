import { AppColors, AppStyles } from '../../../constants/AppConstants'
import { ActionText, ModuleText } from '../../../constants/StringCatalog'
import {
  IdentityActionStrings,
  IdentityFormStrings,
  IdentityMessageStrings,
  IdentityPageStrings,
  IdentitySectionStrings
} from '../../../constants/modules/IdentityStrings'
import {
  AdminActivationState,
  PASSWORD_LENGTH_OPTIONS,
  PASSWORD_VALIDITY_OPTIONS
} from '../../../models/DataModels'

import { ThemeMode } from '../../../theme/ThemeColors'
import { EnterpriseAdminService } from '../../../services/admin/activation/EnterpriseAdminService'
import { IdentityService } from '../../../services/identity/settings/IdentityService'
import { SectionCard } from '../../../components/SettingsSectionCard'
import { SectionSelectInputRow, SectionSelectRow, SectionToggleRow } from '../../../components/SectionRows'
import { IconTextActionButton } from '../../../components/IconTextActionButton'
import { DialogService } from '../../../utils/DialogService'
import { SubPageHeader } from '../../../components/SubPageHeader'
import {
  CUSTOM_VALIDITY_OPTION_INDEX,
  PERMANENT_VALIDITY_OPTION_INDEX,
  IdentitySettingsViewModel
} from '../../../viewmodels/identity/settings/IdentitySettingsViewModel'

@ComponentV2
export struct IdentityPage {
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Event onBack: () => void = () => {}
  @Local adminState: AdminActivationState = {
    activated: false,
    enableCommand: EnterpriseAdminService.buildEnableCommand(),
    adminType: EnterpriseAdminService.DEFAULT_ADMIN_TYPE
  }
  @Local viewModel: IdentitySettingsViewModel = new IdentitySettingsViewModel()

  private lengthOptions: SelectOption[] = PASSWORD_LENGTH_OPTIONS.map((value: number): SelectOption => ({
    value: `${value} ${IdentityFormStrings.BYTE_UNIT_SUFFIX}`
  } as SelectOption))

  private validityOptions: SelectOption[] = [
    ...PASSWORD_VALIDITY_OPTIONS.map((value: number): SelectOption => ({
      value: `${value} ${IdentityFormStrings.DAY_UNIT}`
    } as SelectOption)),
    { value: IdentityFormStrings.PERMANENT_OPTION } as SelectOption,
    { value: IdentityFormStrings.CUSTOM_OPTION } as SelectOption
  ]

  aboutToAppear() {
    this.refreshAdminActivationState()
    this.loadCurrentPolicy()
  }

  private refreshAdminActivationState(): void {
    this.adminState = EnterpriseAdminService.probeActivation()
  }

  private loadCurrentPolicy(): void {
    if (!this.adminState.activated) {
      this.viewModel.reset()
      return
    }

    let result = IdentityService.getPasswordPolicyWithResult()
    if (!result.success) {
      this.viewModel.reset()
      return
    }
    this.viewModel.initialize(result.data)
  }

  private async saveConfig(): Promise<void> {
    this.refreshAdminActivationState()
    if (!this.adminState.activated) {
      DialogService.openFailure(
        this.getUIContext(),
        this.adminState.errorMessage?.trim().length ?
          this.adminState.errorMessage :
          `${IdentityActionStrings.SAVE}${IdentityMessageStrings.ADMIN_REQUIRED_WITH_ACTION_SUFFIX}`
      )
      return
    }

    if (this.viewModel.shouldWarnImmediateExpiry()) {
      await DialogService.openConfirm(this.getUIContext(), {
        title: IdentityMessageStrings.IMMEDIATE_EXPIRY_RISK_TITLE,
        message: IdentityMessageStrings.IMMEDIATE_EXPIRY_RISK_MESSAGE,
        onConfirm: () => {
          this.executeSave()
        }
      })
      return
    }

    this.executeSave()
  }

  private executeSave(): void {
    let result = this.viewModel.save()
    DialogService.openResult(this.getUIContext(), {
      status: result.success ? 'success' : 'failure',
      message: result.message
    })
  }

  private getSelectedMinLengthLabel(): string {
    return this.lengthOptions[this.viewModel.state.minLengthIndex].value as string
  }

  private getSelectedValidityLabel(): string {
    return this.validityOptions[this.viewModel.state.validityPeriodIndex].value as string
  }

  build() {
    Column() {
      SubPageHeader({
        title: ModuleText.IDENTITY,
        subtitle: IdentityPageStrings.SUBTITLE,
        currentTheme: this.currentTheme,
        onBack: () => this.onBack(),
        actions: () => {
          this.headerActions()
        }
      })

      Scroll() {
        Column({ space: 24 }) {
          SectionCard({
            title: IdentitySectionStrings.PASSWORD_COMPLEXITY,
            currentTheme: this.currentTheme,
            content: () => {
              this.passwordComplexityContent()
            }
          })
        }
        .width('100%')
        .padding({
          left: AppStyles.PADDING_LG,
          right: AppStyles.PADDING_LG,
          top: AppStyles.PADDING_MD,
          bottom: AppStyles.PADDING_LG
        })
        .justifyContent(FlexAlign.Start)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }

  @Builder
  private headerActions() {
    IconTextActionButton({
      label: ActionText.SAVE_CONFIG,
      icon: $r('app.media.save'),
      kind: 'primary',
      currentTheme: this.currentTheme,
      onTap: () => {
        void this.saveConfig()
      }
    })
  }

  @Builder
  private passwordComplexityContent() {
    SectionSelectRow({
      title: IdentitySectionStrings.MIN_PASSWORD_LENGTH,
      description: IdentitySectionStrings.MIN_PASSWORD_LENGTH_DESC,
      options: this.lengthOptions,
      selectedIndex: this.viewModel.state.minLengthIndex,
      value: this.getSelectedMinLengthLabel(),
      selectWidth: 140,
      currentTheme: this.currentTheme,
      onSelect: (index: number) => {
        this.viewModel.setMinLengthIndex(index)
      }
    })

    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    SectionToggleRow({
      title: IdentitySectionStrings.REQUIRE_UPPERCASE,
      description: IdentitySectionStrings.REQUIRE_UPPERCASE_DESC,
      isOn: this.viewModel.state.requireUppercase,
      currentTheme: this.currentTheme,
      onChange: (value: boolean) => {
        this.viewModel.setRequirement('requireUppercase', value)
      }
    })

    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    SectionToggleRow({
      title: IdentitySectionStrings.REQUIRE_LOWERCASE,
      description: IdentitySectionStrings.REQUIRE_LOWERCASE_DESC,
      isOn: this.viewModel.state.requireLowercase,
      currentTheme: this.currentTheme,
      onChange: (value: boolean) => {
        this.viewModel.setRequirement('requireLowercase', value)
      }
    })

    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    SectionToggleRow({
      title: IdentitySectionStrings.REQUIRE_DIGIT,
      description: IdentitySectionStrings.REQUIRE_DIGIT_DESC,
      isOn: this.viewModel.state.requireDigit,
      currentTheme: this.currentTheme,
      onChange: (value: boolean) => {
        this.viewModel.setRequirement('requireDigit', value)
      }
    })

    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    SectionToggleRow({
      title: IdentitySectionStrings.REQUIRE_SPECIAL_CHAR,
      description: IdentitySectionStrings.REQUIRE_SPECIAL_CHAR_DESC,
      isOn: this.viewModel.state.requireSpecialChar,
      currentTheme: this.currentTheme,
      onChange: (value: boolean) => {
        this.viewModel.setRequirement('requireSpecialChar', value)
      }
    })

    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    SectionSelectInputRow({
      title: IdentitySectionStrings.PASSWORD_VALIDITY_PERIOD,
      description: IdentitySectionStrings.PASSWORD_VALIDITY_PERIOD_DESC,
      options: this.validityOptions,
      selectedIndex: this.viewModel.state.validityPeriodIndex,
      value: this.getSelectedValidityLabel(),
      selectWidth: 140,
      showInput: this.viewModel.state.validityPeriodIndex === CUSTOM_VALIDITY_OPTION_INDEX,
      inputText: this.viewModel.state.customValidityPeriodText,
      inputPlaceholder: IdentityFormStrings.CUSTOM_DAYS_PLACEHOLDER,
      inputWidth: 112,
      inputSuffix: IdentityFormStrings.DAY_UNIT,
      currentTheme: this.currentTheme,
      onSelect: (index: number) => {
        this.viewModel.setValidityPeriodIndex(index)
      },
      onInputChange: (value: string) => {
        this.viewModel.setCustomValidityPeriodText(value)
      }
    })
  }
}
