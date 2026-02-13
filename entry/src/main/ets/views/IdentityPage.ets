import { AppColors, AppStyles } from '../constants/AppConstants'
import { IdentityService } from '../services/IdentityService'
import { accountManager } from '@kit.MDMKit'
import {
  PasswordComplexityConfig,
  PASSWORD_LENGTH_OPTIONS,
  PASSWORD_MAX_AGE_OPTIONS,
  EXPIRY_NOTIFY_OPTIONS,
  AUTH_TOKEN_VALIDITY_OPTIONS
} from '../models/DataModels'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { promptAction } from '@kit.ArkUI'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'

const TAG = 'IdentityPage'

@Component
export struct IdentityPage {
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  // ========== 口令复杂度状态 ==========
  @State minLengthIndex: number = 1        // 默认 8 位 (PASSWORD_LENGTH_OPTIONS[1])
  @State requireUppercase: boolean = true
  @State requireLowercase: boolean = true
  @State requireDigit: boolean = true
  @State requireSpecialChar: boolean = true

  // ========== 口令有效期状态 ==========
  @State maxAgeIndex: number = 2           // 默认 90 天
  @State notifyDaysIndex: number = 1       // 默认 7 天
  @State authValidityIndex: number = 4     // 默认永久 (-1)

  // ========== 预览正则 ==========
  @State previewRegex: string = ''

  // Select 选项
  private lengthOptions: SelectOption[] =
    PASSWORD_LENGTH_OPTIONS.map((v: number): SelectOption => ({ value: `${v} 位` }))
  private maxAgeOptions: SelectOption[] =
    PASSWORD_MAX_AGE_OPTIONS.map((v: number): SelectOption => ({ value: v === -1 ? '不限制' : `${v} 天` }))
  private notifyOptions: SelectOption[] =
    EXPIRY_NOTIFY_OPTIONS.map((v: number): SelectOption => ({ value: `${v} 天` }))
  private authValidityOptions: SelectOption[] =
    AUTH_TOKEN_VALIDITY_OPTIONS.map((v: number): SelectOption => ({
      value: v === -1 ? '永久有效' : (v >= 60 ? `${v / 60} 小时` : `${v} 分钟`)
    }))

  aboutToAppear() {
    this.loadCurrentPolicy()
    this.updatePreviewRegex()
  }

  // 加载当前策略
  loadCurrentPolicy() {
    // 尝试从系统读取口令策略
    let pwdPolicy = IdentityService.getPasswordPolicy()
    if (pwdPolicy !== null && pwdPolicy.complexityRegex) {
      hilog.info(0x0003, TAG, `Loaded password policy: ${pwdPolicy.complexityRegex}`)
      // 从正则反解析配置（best-effort）
      this.parseRegexToConfig(pwdPolicy.complexityRegex)
    }

    // 尝试从系统读取域账号策略
    let domainPolicy = IdentityService.getDomainAccountPolicy()
    if (domainPolicy !== null) {
      hilog.info(0x0003, TAG, `Loaded domain policy: ${JSON.stringify(domainPolicy)}`)
      this.parseDomainPolicy(domainPolicy)
    }
  }

  // 从正则表达式反解析出 UI 配置
  parseRegexToConfig(regex: string) {
    this.requireLowercase = regex.indexOf('(?=.*[a-z])') >= 0
    this.requireUppercase = regex.indexOf('(?=.*[A-Z])') >= 0
    this.requireDigit = regex.indexOf('(?=.*\\d)') >= 0
    this.requireSpecialChar = regex.indexOf('(?=.*[!@#$%^&*])') >= 0

    // 提取最小长度: 匹配 {N,}$
    let lenMatch = regex.match(/\{(\d+),\}\$/)
    if (lenMatch && lenMatch[1]) {
      let len = parseInt(lenMatch[1])
      let idx = PASSWORD_LENGTH_OPTIONS.indexOf(len)
      if (idx >= 0) {
        this.minLengthIndex = idx
      }
    }
  }

  // 解析域账号策略到 UI 状态
  parseDomainPolicy(policy: accountManager.DomainAccountPolicy) {
    // passwordValidityPeriod (秒) -> 天
    if (policy.passwordValidityPeriod !== undefined) {
      let seconds = policy.passwordValidityPeriod
      if (seconds === -1) {
        this.maxAgeIndex = PASSWORD_MAX_AGE_OPTIONS.indexOf(-1)
      } else {
        let days = Math.round(seconds / 86400)
        let idx = PASSWORD_MAX_AGE_OPTIONS.indexOf(days)
        if (idx >= 0) {
          this.maxAgeIndex = idx
        }
      }
    }

    // passwordExpirationNotification (秒) -> 天
    if (policy.passwordExpirationNotification !== undefined) {
      let seconds = policy.passwordExpirationNotification
      let days = Math.round(seconds / 86400)
      let idx = EXPIRY_NOTIFY_OPTIONS.indexOf(days)
      if (idx >= 0) {
        this.notifyDaysIndex = idx
      }
    }

    // authenticationValidityPeriod (秒) -> 分钟
    if (policy.authenticationValidityPeriod !== undefined) {
      let seconds = policy.authenticationValidityPeriod
      if (seconds === -1) {
        this.authValidityIndex = AUTH_TOKEN_VALIDITY_OPTIONS.indexOf(-1)
      } else {
        let minutes = Math.round(seconds / 60)
        let idx = AUTH_TOKEN_VALIDITY_OPTIONS.indexOf(minutes)
        if (idx >= 0) {
          this.authValidityIndex = idx
        }
      }
    }
  }

  // 更新预览正则
  updatePreviewRegex() {
    let config: PasswordComplexityConfig = {
      minLength: PASSWORD_LENGTH_OPTIONS[this.minLengthIndex],
      requireUppercase: this.requireUppercase,
      requireLowercase: this.requireLowercase,
      requireDigit: this.requireDigit,
      requireSpecialChar: this.requireSpecialChar
    }
    this.previewRegex = IdentityService.buildComplexityRegex(config)
  }

  // 保存配置
  saveConfig() {
    // 1. 保存口令复杂度策略
    let complexityConfig: PasswordComplexityConfig = {
      minLength: PASSWORD_LENGTH_OPTIONS[this.minLengthIndex],
      requireUppercase: this.requireUppercase,
      requireLowercase: this.requireLowercase,
      requireDigit: this.requireDigit,
      requireSpecialChar: this.requireSpecialChar
    }
    let pwdSuccess = IdentityService.setPasswordPolicy(complexityConfig)

    // 2. 保存域账号策略
    let domainSuccess = IdentityService.setDomainAccountPolicy(
      PASSWORD_MAX_AGE_OPTIONS[this.maxAgeIndex],
      EXPIRY_NOTIFY_OPTIONS[this.notifyDaysIndex],
      AUTH_TOKEN_VALIDITY_OPTIONS[this.authValidityIndex]
    )

    // 3. Toast 反馈
    try {
      if (pwdSuccess && domainSuccess) {
        promptAction.showToast({ message: '身份鉴别配置已保存' })
      } else if (pwdSuccess) {
        promptAction.showToast({ message: '口令策略已保存，域账号策略保存失败' })
      } else if (domainSuccess) {
        promptAction.showToast({ message: '域账号策略已保存，口令策略保存失败' })
      } else {
        promptAction.showToast({ message: '保存失败，请检查权限和设备管理员状态' })
      }
    } catch (e) {
      hilog.error(0x0003, TAG, `showToast failed: ${JSON.stringify(e)}`)
    }
  }

  // 重置默认
  resetToDefault() {
    this.minLengthIndex = 1       // 8 位
    this.requireUppercase = true
    this.requireLowercase = true
    this.requireDigit = true
    this.requireSpecialChar = true
    this.maxAgeIndex = 2          // 90 天
    this.notifyDaysIndex = 1      // 7 天
    this.authValidityIndex = 4    // 永久
    this.updatePreviewRegex()
    try {
      promptAction.showToast({ message: '已重置为默认配置' })
    } catch (e) {
      hilog.error(0x0003, TAG, `showToast failed: ${JSON.stringify(e)}`)
    }
  }

  build() {
    Column() {
      // 页面头部
      Row() {
        Column({ space: 4 }) {
          Text('身份鉴别')
            .fontSize(AppStyles.FONT_SIZE_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          Text('配置账户口令策略和认证方式，保障系统访问安全')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({
        left: AppStyles.PADDING_LG,
        right: AppStyles.PADDING_LG,
        top: AppStyles.PADDING_LG
      })

      // 主内容区
      Scroll() {
        Column({ space: 24 }) {
          // 功能区 1: 口令复杂度策略
          this.passwordComplexityBuilder()

          // 功能区 2: 口令有效期配置
          this.passwordValidityBuilder()
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

      // 底部按钮栏
      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      Row({ space: 12 }) {
        Button('重置默认')
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_COMPONENT)
          .borderRadius(AppStyles.RADIUS_MD)
          .height(36)
          .layoutWeight(1)
          .onClick(() => {
            this.resetToDefault()
          })

        Button('保存配置')
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(Color.White)
          .backgroundColor(AppColors.BRAND_PRIMARY)
          .borderRadius(AppStyles.RADIUS_MD)
          .height(36)
          .layoutWeight(1)
          .onClick(() => {
            this.saveConfig()
          })
      }
      .width('100%')
      .padding({
        left: AppStyles.PADDING_LG,
        right: AppStyles.PADDING_LG,
        top: AppStyles.PADDING_MD,
        bottom: AppStyles.PADDING_MD
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }

  // ==================== 功能区 1: 口令复杂度策略 ====================
  @Builder
  passwordComplexityBuilder() {
    Column({ space: 0 }) {
      // 区块标题
      Row() {
        Text('口令复杂度策略')
          .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        Blank()
        Text('securityManager')
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TAG_ORANGE_TEXT)
          .backgroundColor(AppColors.getColors(this.currentTheme).TAG_ORANGE_BG)
          .borderRadius(4)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      // 最小密码长度
      Row() {
        Column({ space: 2 }) {
          Text('最小密码长度')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          Text('设置用户密码的最少字符数要求')
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
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
          .optionFont({ size: AppStyles.FONT_SIZE_BODY })
          .width(120)
          .onSelect((index: number) => {
            this.minLengthIndex = index
            this.updatePreviewRegex()
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      // 要求包含大写字母
      this.toggleRowBuilder('要求包含大写字母', '密码中必须包含至少一个大写英文字母 (A-Z)',
        this.requireUppercase, (val: boolean) => {
          this.requireUppercase = val
          this.updatePreviewRegex()
        })

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      // 要求包含小写字母
      this.toggleRowBuilder('要求包含小写字母', '密码中必须包含至少一个小写英文字母 (a-z)',
        this.requireLowercase, (val: boolean) => {
          this.requireLowercase = val
          this.updatePreviewRegex()
        })

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      // 要求包含数字
      this.toggleRowBuilder('要求包含数字', '密码中必须包含至少一个数字 (0-9)',
        this.requireDigit, (val: boolean) => {
          this.requireDigit = val
          this.updatePreviewRegex()
        })

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      // 要求包含特殊字符
      this.toggleRowBuilder('要求包含特殊字符', '密码中必须包含至少一个特殊字符 (!@#$%^&*)',
        this.requireSpecialChar, (val: boolean) => {
          this.requireSpecialChar = val
          this.updatePreviewRegex()
        })

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      // 正则预览
      Row() {
        Text('生成的正则表达式：')
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        Text(this.previewRegex)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
    }
    .width('100%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .clip(true)
  }

  // ==================== 功能区 2: 口令有效期配置 ====================
  @Builder
  passwordValidityBuilder() {
    Column({ space: 0 }) {
      // 区块标题
      Row() {
        Text('口令有效期配置')
          .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        Blank()
        Text('accountManager')
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT)
          .backgroundColor(AppColors.getColors(this.currentTheme).TAG_BLUE_BG)
          .borderRadius(4)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      // 密码最长使用天数
      Row() {
        Column({ space: 2 }) {
          Text('密码最长使用天数')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          Text('超过此期限后用户须修改密码')
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Select(this.maxAgeOptions)
          .selected(this.maxAgeIndex)
          .value(this.maxAgeOptions[this.maxAgeIndex].value as string)
          .font({ size: AppStyles.FONT_SIZE_BODY })
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
          .optionFont({ size: AppStyles.FONT_SIZE_BODY })
          .width(120)
          .onSelect((index: number) => {
            this.maxAgeIndex = index
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      // 密码过期前提醒天数
      Row() {
        Column({ space: 2 }) {
          Text('密码过期前提醒天数')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          Text('在密码到期前指定天数发送提醒通知')
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Select(this.notifyOptions)
          .selected(this.notifyDaysIndex)
          .value(this.notifyOptions[this.notifyDaysIndex].value as string)
          .font({ size: AppStyles.FONT_SIZE_BODY })
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
          .optionFont({ size: AppStyles.FONT_SIZE_BODY })
          .width(120)
          .onSelect((index: number) => {
            this.notifyDaysIndex = index
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      // 认证Token有效期
      Row() {
        Column({ space: 2 }) {
          Text('认证Token有效期')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          Text('Token 过期后进入系统须重新认证域账号')
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Select(this.authValidityOptions)
          .selected(this.authValidityIndex)
          .value(this.authValidityOptions[this.authValidityIndex].value as string)
          .font({ size: AppStyles.FONT_SIZE_BODY })
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
          .optionFont({ size: AppStyles.FONT_SIZE_BODY })
          .width(120)
          .onSelect((index: number) => {
            this.authValidityIndex = index
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      // 提示信息
      Row() {
        Text('注意：设置域账号策略后须在设备侧修改域账号密码，否则有效期配置不生效。')
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TAG_ORANGE_TEXT)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(AppColors.getColors(this.currentTheme).TAG_ORANGE_BG)
    }
    .width('100%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .clip(true)
  }

  // ==================== 通用 Toggle 行 Builder ====================
  @Builder
  toggleRowBuilder(label: string, desc: string, isOn: boolean, onChange: (val: boolean) => void) {
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
