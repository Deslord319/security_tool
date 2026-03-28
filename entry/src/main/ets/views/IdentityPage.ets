import { AppColors, AppStyles } from '../constants/AppConstants'
import { IdentityStrings } from '../constants/modules/IdentityStrings'
import {
  AdminActivationState,
  PASSWORD_LENGTH_OPTIONS,
  PASSWORD_VALIDITY_OPTIONS
} from '../models/DataModels'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { SymbolGlyphModifier, TextModifier } from '@kit.ArkUI'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { EnterpriseAdminService } from '../services/EnterpriseAdminService'
import { IdentityService } from '../services/IdentityService'
import { BackNavButton } from '../components/BackNavButton'
import { SectionCard } from '../components/SettingsSectionCard'
import { SectionSelectRow, SectionToggleRow } from '../components/SectionRows'
import { FormControlUtils } from '../utils/FormControlUtils'
import { ResultMessageBox, ResultMessageStatus } from '../components/ResultMessageBox'
import { ResultDialogHelper } from '../utils/ResultDialogHelper'
import {
  CUSTOM_VALIDITY_OPTION_INDEX,
  IdentitySettingsViewModel
} from '../viewmodels/IdentitySettingsViewModel'

const TAG = 'IdentityPage'
const DOMAIN = 0x0011

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
  private resultDialogController: CustomDialogController = new CustomDialogController({
    builder: ResultMessageBox({
      onConfirm: () => {
      }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: false,
    customStyle: true
  })

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

  private showResultDialog(status: ResultMessageStatus, message: string): void {
    ResultDialogHelper.prepareResultDialog(status, message)
    try {
      this.resultDialogController.close()
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `Failed to close result dialog: ${JSON.stringify(err)}`)
    }
    this.resultDialogController.open()
  }

  private refreshAdminActivationState(): void {
    this.adminState = EnterpriseAdminService.probeActivation()
  }

  private ensureAdminReady(action: string): boolean {
    this.refreshAdminActivationState()
    if (this.adminState.activated) {
      return true
    }
    this.showResultDialog(
      'failure',
      ResultDialogHelper.displayReason(
        this.adminState.errorMessage,
        `${action}${IdentityStrings.adminRequiredWithActionSuffix}`
      )
    )
    return false
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
    if (!this.ensureAdminReady(IdentityStrings.saveAction)) {
      return
    }

    let result = this.viewModel.save()
    this.showResultDialog(result.success ? 'success' : 'failure', result.message)
  }

  private getSelectedMinLengthLabel(): string {
    return this.lengthOptions[this.viewModel.state.minLengthIndex].value as string
  }

  private getSelectedValidityLabel(): string {
    return this.validityOptions[this.viewModel.state.validityPeriodIndex].value as string
  }

  build() {
    Column() {
      Row() {
        Row({ space: 8 }) {
          BackNavButton({
            onBack: () => {
              this.onBack()
            }
          })

          Column({ space: 4 }) {
            Text(IdentityStrings.pageTitle)
              .fontSize(AppStyles.FONT_SIZE_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
            Text(IdentityStrings.pageSubtitle)
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Top)

        this.saveButton()
      }
      .width('100%')
      .padding({
        left: AppStyles.PADDING_LG,
        right: AppStyles.PADDING_LG,
        top: AppStyles.PADDING_LG
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
  private saveButton() {
    Button() {
      Row({ space: 6 }) {
        Image($r('app.media.save'))
          .width(14)
          .height(14)
          .fillColor(Color.White)
          .draggable(false)

        Text(IdentityStrings.saveButton)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(Color.White)
      }
      .alignItems(VerticalAlign.Center)
    }
    .type(ButtonType.Normal)
    .backgroundColor(AppColors.BRAND_PRIMARY)
    .borderRadius(AppStyles.RADIUS_SM)
    .height(32)
    .padding({ left: 10, right: 10 })
    .onClick(() => {
      this.saveConfig()
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
        this.viewModel.setRequireUppercase(value)
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
        this.viewModel.setRequireLowercase(value)
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
        this.viewModel.setRequireDigit(value)
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
        this.viewModel.setRequireSpecialChar(value)
      }
    })

    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    Row() {
      Column({ space: 2 }) {
        Text(IdentityStrings.passwordValidityPeriod)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        Text(IdentityStrings.passwordValidityPeriodDesc)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Row({ space: 8 }) {
        Select(this.validityOptions)
          .selected(this.viewModel.state.validityPeriodIndex)
          .value(this.getSelectedValidityLabel())
          .font({ size: AppStyles.FONT_SIZE_BODY })
          .fontColor(FormControlUtils.text(this.currentTheme))
          .textModifier(new TextModifier().fontColor(FormControlUtils.text(this.currentTheme)))
          .arrowModifier(new SymbolGlyphModifier().fontColor([FormControlUtils.selectArrow(this.currentTheme)]))
          .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
          .optionFont({ size: AppStyles.FONT_SIZE_BODY })
          .width(140)
          .height(36)
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_SM)
          .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .onSelect((index: number) => {
            this.viewModel.setValidityPeriodIndex(index)
          })

        if (this.viewModel.state.validityPeriodIndex === CUSTOM_VALIDITY_OPTION_INDEX) {
          Row({ space: 6 }) {
            TextInput({
              placeholder: IdentityStrings.customDaysPlaceholder,
              text: this.viewModel.state.customValidityPeriodText
            })
              .type(InputType.Number)
              .width(112)
              .height(36)
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(FormControlUtils.text(this.currentTheme))
              .placeholderColor(FormControlUtils.placeholder(this.currentTheme))
              .backgroundColor(FormControlUtils.background(this.currentTheme))
              .borderRadius(AppStyles.RADIUS_SM)
              .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
              .onChange((value: string) => {
                this.viewModel.setCustomValidityPeriodText(value)
              })
            Text(IdentityStrings.dayUnit)
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          }
        }
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 16 })
  }
}
