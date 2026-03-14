import { AppColors, AppStyles } from '../constants/AppConstants'
import { IdentityService } from '../services/IdentityService'
import {
  AdminActivationState,
  OperationResult,
  PasswordComplexityConfig,
  PASSWORD_LENGTH_OPTIONS,
  PASSWORD_VALIDITY_OPTIONS
} from '../models/DataModels'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { promptAction } from '@kit.ArkUI'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { EnterpriseAdminService } from '../services/EnterpriseAdminService'
import { BackNavButton } from '../components/BackNavButton'
import { HoverUtils } from '../utils/HoverUtils'
import { FormControlUtils } from '../utils/FormControlUtils'

const TAG = 'IdentityPage'
const DOMAIN = 0x0003
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

  private lengthOptions: SelectOption[] = PASSWORD_LENGTH_OPTIONS.map((value: number): SelectOption => ({
    value: `${value} 位`
  } as SelectOption))

  private validityOptions: SelectOption[] = [
    ...PASSWORD_VALIDITY_OPTIONS.map((value: number): SelectOption => ({
      value: value === 0 ? '永久' : `${value} 天`
    } as SelectOption)),
    { value: '自定义' } as SelectOption
  ]

  aboutToAppear() {
    this.refreshAdminActivationState()
    this.loadCurrentPolicy()
  }

  private refreshAdminActivationState(): void {
    this.adminState = EnterpriseAdminService.probeActivation()
  }

  private ensureAdminReady(action: string): boolean {
    this.refreshAdminActivationState()
    if (this.adminState.activated) {
      return true
    }
    let reasonText = this.adminState.errorMessage || '企业管理员未激活'
    let codeText = this.adminState.errorCode !== undefined ? ` (${this.adminState.errorCode})` : ''
    promptAction.showToast({ message: `${action}失败：${reasonText}${codeText}` })
    return false
  }

  private showFailureDialog<T>(action: string, result: OperationResult<T>): void {
    if (result.isAdminMissing) {
      let reasonText = result.errorMessage || '企业管理员未激活'
      let codeText = result.errorCode !== undefined ? ` (${result.errorCode})` : ''
      promptAction.showToast({ message: `${action}失败：${reasonText}${codeText}` })
      return
    }

    let codeText = result.errorCode !== undefined ? `错误码: ${result.errorCode}\n` : ''
    let reasonText = result.errorMessage || `${action}失败`
    let suggestionText = result.suggestion || '请检查企业管理员状态和系统权限后重试。'
    AlertDialog.show({
      title: `${action}失败`,
      message: `${codeText}原因: ${reasonText}\n建议: ${suggestionText}`,
      primaryButton: { value: '知道了', action: () => {} }
    })
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
      promptAction.showToast({ message: '请输入非负整数天数，0 表示永久有效' })
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
    if (!this.ensureAdminReady('保存身份鉴别配置')) {
      return
    }

    let config = this.buildConfig()
    if (!config) {
      return
    }

    let pwdResult = IdentityService.setPasswordPolicyWithResult(config)
    if (pwdResult.success) {
      promptAction.showToast({ message: '身份鉴别配置已保存。' })
      return
    }
    this.showFailureDialog('设置口令策略', pwdResult)
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
            Text('身份鉴别')
              .fontSize(AppStyles.FONT_SIZE_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
            Text('配置账户口令复杂度和密码有效期，保障系统访问安全。')
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
          '保存配置',
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
        Text('口令复杂度策略')
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
          Text('最小密码长度')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          Text('设置用户密码的最少字符数要求。')
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
        '要求包含大写字母',
        '密码中必须包含至少一个大写英文字母 (A-Z)。',
        this.requireUppercase,
        (value: boolean) => {
          this.requireUppercase = value
        }
      )

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      this.toggleRowBuilder(
        '要求包含小写字母',
        '密码中必须包含至少一个小写英文字母 (a-z)。',
        this.requireLowercase,
        (value: boolean) => {
          this.requireLowercase = value
        }
      )

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      this.toggleRowBuilder(
        '要求包含数字',
        '密码中必须包含至少一个数字 (0-9)。',
        this.requireDigit,
        (value: boolean) => {
          this.requireDigit = value
        }
      )

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      this.toggleRowBuilder(
        '要求包含特殊字符',
        '密码中必须包含至少一个特殊字符 (!@#$%^&*)。',
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
          Text('密码有效期')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          Text('设置密码需要变更的周期。固定选项保持不变，也支持自定义输入，0 表示永久有效。')
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
              TextInput({ placeholder: '输入天数', text: this.customValidityPeriodText })
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
              Text('天')
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
      color: this.hoveredCardIndex === 0 ? AppColors.BRAND_PRIMARY : AppColors.getColors(this.currentTheme).BORDER
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
