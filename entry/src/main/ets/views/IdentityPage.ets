import { AppColors, AppStyles } from '../constants/AppConstants'
import { IdentityStrings } from '../constants/modules/IdentityStrings'
import { IdentityService } from '../services/IdentityService'
import {
  AdminActivationState,
  OperationResult,
  PasswordComplexityConfig,
  PASSWORD_LENGTH_OPTIONS,
  PASSWORD_VALIDITY_OPTIONS
} from '../models/DataModels'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { SymbolGlyphModifier, TextModifier } from '@kit.ArkUI'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { EnterpriseAdminService } from '../services/EnterpriseAdminService'
import { BackNavButton } from '../components/BackNavButton'
import { HoverUtils } from '../utils/HoverUtils'
import { FormControlUtils } from '../utils/FormControlUtils'
import { ResultMessageBox, ResultMessageStatus } from '../components/ResultMessageBox'
import { ResultDialogHelper } from '../utils/ResultDialogHelper'

const TAG = 'IdentityPage'
const DOMAIN = 0x0011
const CUSTOM_VALIDITY_OPTION_INDEX = PASSWORD_VALIDITY_OPTIONS.length

@Component
export struct IdentityPage {
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  onBack: () => void = () => {}
  @State hoveredCardIndex: number = -1
  @State adminState: AdminActivationState = {
    activated: false,
    enableCommand: EnterpriseAdminService.buildEnableCommand(),
    adminType: EnterpriseAdminService.DEFAULT_ADMIN_TYPE
  }

  @State minLengthIndex: number = 1
  @State requireUppercase: boolean = true
  @State requireLowercase: boolean = true
  @State requireDigit: boolean = true
  @State requireSpecialChar: boolean = true
  @State validityPeriodIndex: number = 0
  @State customValidityPeriodText: string = ''
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

  private showFailureDialog<T>(action: string, result: OperationResult<T>): void {
    let dialogMessage = result.isAdminMissing
      ? ResultDialogHelper.displayReason(result.errorMessage, IdentityStrings.adminRequired)
      : ResultDialogHelper.displayReason(result.errorMessage, `${action}${IdentityStrings.actionRetrySuffix}`)
    this.showResultDialog('failure', dialogMessage)
  }

  private loadCurrentPolicy(): void {
    if (!this.adminState.activated) {
      return
    }

    let pwdPolicyResult = IdentityService.getPasswordPolicyWithResult()
    if (!pwdPolicyResult.success || !pwdPolicyResult.data) {
      return
    }

    if (pwdPolicyResult.data.complexityRegex) {
      hilog.info(DOMAIN, TAG, `Loaded password policy regex=${pwdPolicyResult.data.complexityRegex}`)
      this.parseRegexToConfig(pwdPolicyResult.data.complexityRegex)
    }
    hilog.info(DOMAIN, TAG, `Loaded password policy validityPeriod=${pwdPolicyResult.data.validityPeriod ?? 0}`)
    this.applyValidityPeriod(pwdPolicyResult.data.validityPeriod)
  }

  private parseRegexToConfig(regex: string): void {
    this.requireLowercase = regex.indexOf('(?=.*[a-z])') >= 0
    this.requireUppercase = regex.indexOf('(?=.*[A-Z])') >= 0
    this.requireDigit = regex.indexOf('(?=.*\\d)') >= 0
    this.requireSpecialChar = regex.indexOf('(?=.*[!@#$%^&*])') >= 0

    let lenMatch = regex.match(/\{(\d+),\}\$/)
    if (!lenMatch || !lenMatch[1]) {
      return
    }

    let length = parseInt(lenMatch[1])
    let index = PASSWORD_LENGTH_OPTIONS.indexOf(length)
    if (index >= 0) {
      this.minLengthIndex = index
    }
  }

  private applyValidityPeriod(validityPeriod: number | undefined): void {
    let normalized = typeof validityPeriod === 'number' && validityPeriod >= 0 ? validityPeriod : 0
    let index = PASSWORD_VALIDITY_OPTIONS.indexOf(normalized)
    if (index >= 0) {
      this.validityPeriodIndex = index
      this.customValidityPeriodText = ''
      return
    }

    this.validityPeriodIndex = CUSTOM_VALIDITY_OPTION_INDEX
    this.customValidityPeriodText = `${normalized}`
  }

  private isCustomValiditySelected(): boolean {
    return this.validityPeriodIndex === CUSTOM_VALIDITY_OPTION_INDEX
  }

  private resolveValidityPeriod(): number | null {
    if (!this.isCustomValiditySelected()) {
      return PASSWORD_VALIDITY_OPTIONS[this.validityPeriodIndex]
    }

    let normalizedText = this.customValidityPeriodText.trim()
    if (normalizedText.length === 0 || !/^\d+$/.test(normalizedText)) {
      return null
    }

    return parseInt(normalizedText)
  }

  private buildConfig(): PasswordComplexityConfig | null {
    let validityPeriod = this.resolveValidityPeriod()
    if (validityPeriod === null) {
      this.showResultDialog('failure', IdentityStrings.invalidValidityDays)
      return null
    }

    return {
      minLength: PASSWORD_LENGTH_OPTIONS[this.minLengthIndex],
      requireUppercase: this.requireUppercase,
      requireLowercase: this.requireLowercase,
      requireDigit: this.requireDigit,
      requireSpecialChar: this.requireSpecialChar,
      validityPeriod: validityPeriod
    }
  }

  private saveConfig(): void {
    if (!this.ensureAdminReady(IdentityStrings.saveAction)) {
      return
    }

    let config = this.buildConfig()
    if (!config) {
      return
    }

    let currentPolicy = IdentityService.getPasswordPolicyWithResult().data
    let currentRegex: string = currentPolicy?.complexityRegex ?? ''
    let nextRegex: string = IdentityService.buildComplexityRegex(config)
    let currentValidity = currentPolicy?.validityPeriod ?? 0
    if (currentRegex === nextRegex && currentValidity === config.validityPeriod) {
      this.showResultDialog('failure', '当前没有需要保存的更改')
      return
    }

    let pwdResult = IdentityService.setPasswordPolicyWithResult(config)
    if (pwdResult.success) {
      this.showResultDialog('success', IdentityStrings.saveSuccess)
      return
    }
    this.showFailureDialog(IdentityStrings.passwordPolicyAction, pwdResult)
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

        this.headerActionButton(
          IdentityStrings.saveButton,
          $r('app.media.save'),
          Color.White,
          AppColors.BRAND_PRIMARY,
          () => {
            this.saveConfig()
          }
        )
      }
      .width('100%')
      .padding({
        left: AppStyles.PADDING_LG,
        right: AppStyles.PADDING_LG,
        top: AppStyles.PADDING_LG
      })

      Scroll() {
        Column({ space: 24 }) {
          this.passwordComplexityBuilder()
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
  headerActionButton(
    label: string,
    icon: Resource,
    textColor: ResourceColor,
    backgroundColor: ResourceColor,
    onTap: () => void
  ) {
    Button() {
      Row({ space: 6 }) {
        Image(icon)
          .width(14)
          .height(14)
          .fillColor(textColor)

        Text(label)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(textColor)
      }
      .alignItems(VerticalAlign.Center)
    }
    .type(ButtonType.Normal)
    .backgroundColor(backgroundColor)
    .borderRadius(AppStyles.RADIUS_SM)
    .height(32)
    .padding({ left: 10, right: 10 })
    .onClick(() => {
      onTap()
    })
  }

  @Builder
  passwordComplexityBuilder() {
    Column({ space: 0 }) {
      Row() {
        Text(IdentityStrings.sectionPasswordComplexity)
          .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        Blank()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      Row() {
        Column({ space: 2 }) {
          Text(IdentityStrings.minPasswordLength)
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          Text(IdentityStrings.minPasswordLengthDesc)
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Select(this.lengthOptions)
          .selected(this.minLengthIndex)
          .value(this.lengthOptions[this.minLengthIndex].value as string)
          .font({ size: AppStyles.FONT_SIZE_BODY })
          .fontColor(FormControlUtils.text(this.currentTheme))
          .textModifier(new TextModifier().fontColor(FormControlUtils.text(this.currentTheme)))
          .arrowModifier(new SymbolGlyphModifier().fontColor([FormControlUtils.selectArrow(this.currentTheme)]))
          .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
          .optionFont({ size: AppStyles.FONT_SIZE_BODY })
          .width(120)
          .height(36)
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_SM)
          .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .onSelect((index: number) => {
            this.minLengthIndex = index
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      this.toggleRowBuilder(
        IdentityStrings.requireUppercase,
        IdentityStrings.requireUppercaseDesc,
        this.requireUppercase,
        (value: boolean) => {
          this.requireUppercase = value
        }
      )

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      this.toggleRowBuilder(
        IdentityStrings.requireLowercase,
        IdentityStrings.requireLowercaseDesc,
        this.requireLowercase,
        (value: boolean) => {
          this.requireLowercase = value
        }
      )

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      this.toggleRowBuilder(
        IdentityStrings.requireDigit,
        IdentityStrings.requireDigitDesc,
        this.requireDigit,
        (value: boolean) => {
          this.requireDigit = value
        }
      )

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      this.toggleRowBuilder(
        IdentityStrings.requireSpecialChar,
        IdentityStrings.requireSpecialCharDesc,
        this.requireSpecialChar,
        (value: boolean) => {
          this.requireSpecialChar = value
        }
      )

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
            .selected(this.validityPeriodIndex)
            .value(this.validityOptions[this.validityPeriodIndex].value as string)
            .font({ size: AppStyles.FONT_SIZE_BODY })
            .fontColor(FormControlUtils.text(this.currentTheme))
            .textModifier(new TextModifier().fontColor(FormControlUtils.text(this.currentTheme)))
            .arrowModifier(new SymbolGlyphModifier().fontColor([FormControlUtils.selectArrow(this.currentTheme)]))
            .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
            .optionFont({ size: AppStyles.FONT_SIZE_BODY })
            .width(120)
            .height(36)
            .backgroundColor(FormControlUtils.background(this.currentTheme))
            .borderRadius(AppStyles.RADIUS_SM)
            .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
            .onSelect((index: number) => {
              this.validityPeriodIndex = index
              if (index !== CUSTOM_VALIDITY_OPTION_INDEX) {
                this.customValidityPeriodText = ''
              }
            })

          if (this.isCustomValiditySelected()) {
            Row({ space: 6 }) {
              TextInput({ placeholder: IdentityStrings.customDaysPlaceholder, text: this.customValidityPeriodText })
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
                  this.customValidityPeriodText = value.replace(/[^0-9]/g, '')
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
    .width('100%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .clip(true)
    .border({
      width: 1,
      color: AppColors.getColors(this.currentTheme).BORDER
    })
    .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredCardIndex === 0, true))
    .translate({ y: HoverUtils.getTranslateY(this.hoveredCardIndex === 0, 4) })
    .onHover((isHover: boolean) => {
      HoverUtils.animate(() => {
        this.hoveredCardIndex = isHover ? 0 : -1
      })
    })
  }

  @Builder
  toggleRowBuilder(label: string, desc: string, isOn: boolean, onChange: (value: boolean) => void) {
    Row() {
      Column({ space: 2 }) {
        Text(label)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        Text(desc)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor(AppColors.BRAND_PRIMARY)
        .onChange((value: boolean) => {
          onChange(value)
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
  }
}
