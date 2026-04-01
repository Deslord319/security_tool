import { LogUtils } from '../utils/LogUtils'
import { AppColors, AppStyles } from '../constants/AppConstants'
import { IdentityStrings } from '../constants/modules/IdentityStrings'
import {
  AdminActivationState,
  PASSWORD_LENGTH_OPTIONS,
  PASSWORD_VALIDITY_OPTIONS
} from '../models/DataModels'

import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { EnterpriseAdminService } from '../services/EnterpriseAdminService'
import { IdentityService } from '../services/IdentityService'
import { SectionCard } from '../components/SettingsSectionCard'
import { SectionSelectInputRow, SectionSelectRow, SectionToggleRow } from '../components/SectionRows'
import { IconTextActionButton } from '../components/IconTextActionButton'
import { DialogService } from '../utils/DialogService'
import { SubPageHeader } from '../components/SubPageHeader'
import {
  CUSTOM_VALIDITY_OPTION_INDEX,
  IdentitySettingsViewModel
} from '../viewmodels/IdentitySettingsViewModel'

const TAG = 'IdentityPage'

@Component
export struct IdentityPage {
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  onBack: () => void = () => {}
  @State adminState: AdminActivationState = {
    activated: false,
    enableCommand: EnterpriseAdminService.buildEnableCommand(),
    adminType: EnterpriseAdminService.DEFAULT_ADMIN_TYPE
  }
  @State viewModel: IdentitySettingsViewModel = new IdentitySettingsViewModel()

  private lengthOptions: SelectOption[] = PASSWORD_LENGTH_OPTIONS.map((value: number): SelectOption => ({
    value: `${value} ${IdentityStrings.byteUnitSuffix}`
  } as SelectOption))

  private validityOptions: SelectOption[] = [
    ...PASSWORD_VALIDITY_OPTIONS.map((value: number): SelectOption => ({
      value: value === 0 ? IdentityStrings.permanentOption : `${value} ${IdentityStrings.dayUnit}`
    } as SelectOption)),
    { value: IdentityStrings.customOption } as SelectOption
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

  private saveConfig(): void {
    this.refreshAdminActivationState()
    if (!this.adminState.activated) {
      DialogService.openFailure(
        this.getUIContext(),
        this.adminState.errorMessage?.trim().length ? this.adminState.errorMessage : `${IdentityStrings.saveAction}${IdentityStrings.adminRequiredWithActionSuffix}`
      )
      return
    }

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
        title: IdentityStrings.pageTitle,
        subtitle: IdentityStrings.pageSubtitle,
        currentTheme: this.currentTheme,
        onBack: () => this.onBack(),
        actions: () => {
          this.headerActions()
        }
      })

      Scroll() {
        Column({ space: 24 }) {
          SectionCard({
            title: IdentityStrings.sectionPasswordComplexity,
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
      label: IdentityStrings.saveButton,
      icon: $r('app.media.save'),
      kind: 'primary',
      onTap: () => {
        this.saveConfig()
      }
    })
  }

  @Builder
  private passwordComplexityContent() {
    SectionSelectRow({
      title: IdentityStrings.minPasswordLength,
      description: IdentityStrings.minPasswordLengthDesc,
      options: this.lengthOptions,
      selectedIndex: this.viewModel.state.minLengthIndex,
      value: this.getSelectedMinLengthLabel(),
      selectWidth: 140,
      onSelect: (index: number) => {
        this.viewModel.setMinLengthIndex(index)
      }
    })

    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    SectionToggleRow({
      title: IdentityStrings.requireUppercase,
      description: IdentityStrings.requireUppercaseDesc,
      isOn: this.viewModel.state.requireUppercase,
      onChange: (value: boolean) => {
        this.viewModel.setRequirement('requireUppercase', value)
      }
    })

    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    SectionToggleRow({
      title: IdentityStrings.requireLowercase,
      description: IdentityStrings.requireLowercaseDesc,
      isOn: this.viewModel.state.requireLowercase,
      onChange: (value: boolean) => {
        this.viewModel.setRequirement('requireLowercase', value)
      }
    })

    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    SectionToggleRow({
      title: IdentityStrings.requireDigit,
      description: IdentityStrings.requireDigitDesc,
      isOn: this.viewModel.state.requireDigit,
      onChange: (value: boolean) => {
        this.viewModel.setRequirement('requireDigit', value)
      }
    })

    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    SectionToggleRow({
      title: IdentityStrings.requireSpecialChar,
      description: IdentityStrings.requireSpecialCharDesc,
      isOn: this.viewModel.state.requireSpecialChar,
      onChange: (value: boolean) => {
        this.viewModel.setRequirement('requireSpecialChar', value)
      }
    })

    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    SectionSelectInputRow({
      title: IdentityStrings.passwordValidityPeriod,
      description: IdentityStrings.passwordValidityPeriodDesc,
      options: this.validityOptions,
      selectedIndex: this.viewModel.state.validityPeriodIndex,
      value: this.getSelectedValidityLabel(),
      selectWidth: 140,
      showInput: this.viewModel.state.validityPeriodIndex === CUSTOM_VALIDITY_OPTION_INDEX,
      inputText: this.viewModel.state.customValidityPeriodText,
      inputPlaceholder: IdentityStrings.customDaysPlaceholder,
      inputWidth: 112,
      inputSuffix: IdentityStrings.dayUnit,
      onSelect: (index: number) => {
        this.viewModel.setValidityPeriodIndex(index)
      },
      onInputChange: (value: string) => {
        this.viewModel.setCustomValidityPeriodText(value)
      }
    })
  }
}
