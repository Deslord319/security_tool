import { AppColors, AppStyles } from '../../../constants/AppConstants'
import { AppResources } from '../../../constants/AppResources'
import { ActionText, ModuleText } from '../../../constants/StringCatalog'
import { IdentityFormStrings } from '../../../constants/modules/IdentityStrings'
import { PASSWORD_LENGTH_OPTIONS } from '../../../models/IdentityModels'
import { ThemeMode } from '../../../theme/ThemeColors'
import { SectionCard } from '../../../components/SettingsSectionCard'
import {
  SectionSelectInputRow,
  SectionSelectRow,
  SectionToggleRow
} from '../../../components/SectionRows'
import { IconTextActionButton } from '../../../components/IconTextActionButton'
import { LoadingStatePanel } from '../../../components/LoadingStatePanel'
import { DialogService } from '../../../utils/DialogService'
import { SubPageHeader } from '../../../components/SubPageHeader'
import {
  CUSTOM_VALIDITY_OPTION_INDEX,
  IdentitySettingsActionRequest,
  IdentitySettingsViewModel
} from '../../../viewmodels/identity/settings/IdentitySettingsViewModel'

@ComponentV2
export struct IdentityPage {
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Param viewModel: IdentitySettingsViewModel = new IdentitySettingsViewModel()
  @Event onBack: () => void = () => {}

  private lengthOptions: SelectOption[] = PASSWORD_LENGTH_OPTIONS.map((value: number): SelectOption => ({
    value: IdentityFormStrings.buildLengthOption(value)
  } as SelectOption))

  private validityOptions: SelectOption[] = [
    { value: $r('app.string.identity_form_half_year_option') } as SelectOption,
    { value: $r('app.string.identity_form_one_year_option') } as SelectOption,
    { value: $r('app.string.identity_form_permanent_option') } as SelectOption,
    { value: $r('app.string.identity_form_custom_option') } as SelectOption
  ]

  private async saveConfig(skipImmediateExpiryConfirm: boolean = false): Promise<void> {
    let request = this.viewModel.requestSave(skipImmediateExpiryConfirm)
    if (request.kind === 'none') {
      return
    }
    if (request.kind === 'confirm' && request.title) {
      await DialogService.openConfirm(this.getUIContext(), {
        title: request.title,
        message: request.message,
        onConfirm: () => {
          this.saveConfig(true)
        }
      })
      return
    }

    this.showSaveResult(request)
  }

  private getSelectedMinLengthLabel(): string {
    return this.lengthOptions[this.viewModel.state.minLengthIndex].value as string
  }

  private getSelectedValidityLabel(): string {
    return this.validityOptions[this.viewModel.state.validityPeriodIndex].value as string
  }

  private showSaveResult(request: IdentitySettingsActionRequest): void {
    if (request.kind !== 'result' || !request.status) {
      return
    }
    DialogService.openResult(this.getUIContext(), {
      status: request.status,
      message: request.message
    })
  }

  private getSaveButtonLabel(): string {
    return ActionText.SAVE_CONFIG
  }

  build() {
    Column() {
      SubPageHeader({
        title: $r('app.string.common_module_identity'),
        subtitle: $r('app.string.identity_page_subtitle'),
        currentTheme: this.currentTheme,
        onBack: () => this.onBack(),
        actions: () => {
          this.headerActions()
        }
      })

      Scroll() {
        Column({ space: 24 }) {
          SectionCard({
            title: $r('app.string.identity_section_password_complexity'),
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
      label: this.getSaveButtonLabel(),
      icon: AppResources.SAVE_ICON,
      kind: 'primary',
      isEnabled: this.viewModel.state.canSave,
      currentTheme: this.currentTheme,
      onTap: () => {
        this.saveConfig()
      }
    })
  }

  @Builder
  private passwordComplexityContent() {
    if (!this.viewModel.state.initialized) {
      LoadingStatePanel({
        indicatorSize: 24,
        currentTheme: this.currentTheme
      })
        .height(96)
    } else {
      SectionSelectRow({
      title: $r('app.string.identity_section_min_password_length'),
      description: $r('app.string.identity_section_min_password_length_desc'),
      options: this.lengthOptions,
      selectedIndex: this.viewModel.state.minLengthIndex,
      value: this.getSelectedMinLengthLabel(),
      selectWidth: AppStyles.SELECT_WIDTH_DEFAULT,
      currentTheme: this.currentTheme,
      onSelect: (index: number) => {
        this.viewModel.setMinLengthIndex(index)
      }
    })

    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    SectionToggleRow({
      title: $r('app.string.identity_section_require_uppercase'),
      description: $r('app.string.identity_section_require_uppercase_desc'),
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
      title: $r('app.string.identity_section_require_lowercase'),
      description: $r('app.string.identity_section_require_lowercase_desc'),
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
      title: $r('app.string.identity_section_require_digit'),
      description: $r('app.string.identity_section_require_digit_desc'),
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
      title: $r('app.string.identity_section_require_special_char'),
      description: $r('app.string.identity_section_require_special_char_desc'),
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
      title: $r('app.string.identity_section_password_validity_period'),
      description: $r('app.string.identity_section_password_validity_period_desc'),
      options: this.validityOptions,
      selectedIndex: this.viewModel.state.validityPeriodIndex,
      value: this.getSelectedValidityLabel(),
      selectWidth: AppStyles.SELECT_WIDTH_DEFAULT,
      showInput: this.viewModel.state.validityPeriodIndex === CUSTOM_VALIDITY_OPTION_INDEX,
      inputText: this.viewModel.state.customValidityPeriodText,
      inputPlaceholder: $r('app.string.identity_form_custom_days_placeholder'),
      inputWidth: 112,
      inputSuffix: $r('app.string.identity_form_day_unit'),
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

}
