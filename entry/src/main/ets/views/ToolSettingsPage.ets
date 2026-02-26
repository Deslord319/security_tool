import { AppColors, AppStyles } from '../constants/AppConstants'
import { SecureStorageService } from '../services/SecureStorageService'
import { AuthService } from '../services/AuthService'
import { preferences } from '@kit.ArkData'
import {
  AuthMethod,
  AUTH_METHOD_OPTIONS,
  PREF_KEY_STARTUP_AUTH,
  PREF_KEY_AUTH_METHOD,
  DEFAULT_TOOL_SETTINGS,
  PREF_STORE_NAME_TOOL
} from '../models/DataModels'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { promptAction } from '@kit.ArkUI'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'

const TAG = 'ToolSettingsPage'

@Component
export struct ToolSettingsPage {
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  // ========== 启动校验状态 ==========
  @State startupAuthEnabled: boolean = DEFAULT_TOOL_SETTINGS.startupAuthEnabled
  @State authMethodIndex: number = 0  // 默认 PIN 码

  // ========== 初始值（用于判断是否有变更）==========
  private initialStartupAuthEnabled: boolean = DEFAULT_TOOL_SETTINGS.startupAuthEnabled
  private initialAuthMethodIndex: number = 0

  // ========== 密码管理状态 ==========
  @State currentPassword: string = ''
  @State newPassword: string = ''
  @State confirmPassword: string = ''
  @State hasExistingPassword: boolean = false

  // ========== 密码可见性状态 ==========
  @State showCurrentPwd: boolean = false
  @State showNewPwd: boolean = false
  @State showConfirmPwd: boolean = false

  // ========== 可用认证方式 ==========
  @State availableAuthMethods: AuthMethod[] = []

  // Select 选项
  private authMethodOptions: SelectOption[] =
    AUTH_METHOD_OPTIONS.map((opt): SelectOption => ({ value: opt.label }))

  aboutToAppear() {
    this.loadSettings()
    this.checkAvailableAuthMethods()
  }

  // 加载设置
  async loadSettings() {
    try {
      let prefs = await preferences.getPreferences(getContext(this), PREF_STORE_NAME_TOOL)

      // 加载启动校验开关
      let startupAuth = await prefs.get(PREF_KEY_STARTUP_AUTH, DEFAULT_TOOL_SETTINGS.startupAuthEnabled)
      this.startupAuthEnabled = startupAuth as boolean

      // 加载认证方式
      let authMethod = await prefs.get(PREF_KEY_AUTH_METHOD, DEFAULT_TOOL_SETTINGS.authMethod)
      let methodValue = authMethod as number
      let idx = AUTH_METHOD_OPTIONS.findIndex((opt) => opt.value === methodValue)
      if (idx >= 0) {
        this.authMethodIndex = idx
      }

      // 保存初始值（用于判断是否有变更）
      this.initialStartupAuthEnabled = this.startupAuthEnabled
      this.initialAuthMethodIndex = this.authMethodIndex

      hilog.info(0x0004, TAG, `Settings loaded: startupAuth=${this.startupAuthEnabled}, authMethod=${methodValue}`)
    } catch (err) {
      hilog.error(0x0004, TAG, `loadSettings failed: ${JSON.stringify(err)}`)
    }

    // 检查是否已有密码
    try {
      this.hasExistingPassword = await SecureStorageService.hasPassword()
      hilog.info(0x0004, TAG, `Has existing password: ${this.hasExistingPassword}`)
    } catch (err) {
      hilog.error(0x0004, TAG, `checkPassword failed: ${JSON.stringify(err)}`)
    }
  }

  // 检查可用认证方式
  checkAvailableAuthMethods() {
    this.availableAuthMethods = AuthService.getAvailableAuthMethods()
    hilog.info(0x0004, TAG, `Available auth methods: ${JSON.stringify(this.availableAuthMethods)}`)
  }

  // 保存设置
  async saveSettings() {
    try {
      // 1. 如果启用了启动校验，检查认证方式是否可用
      if (this.startupAuthEnabled) {
        let authMethod = AUTH_METHOD_OPTIONS[this.authMethodIndex].value
        let checkResult = AuthService.checkAuthMethodAvailability(authMethod)
        if (!checkResult.available) {
          AlertDialog.show({
            title: '认证方式不可用',
            message: `${checkResult.message}\n\n保存后下次启动可能无法进入工具，是否继续？`,
            primaryButton: {
              value: '继续保存',
              action: async () => {
                await this.doSaveSettings()
              }
            },
            secondaryButton: {
              value: '取消',
              action: () => {}
            }
          })
          return
        }
      }

      await this.doSaveSettings()
    } catch (err) {
      hilog.error(0x0004, TAG, `saveSettings failed: ${JSON.stringify(err)}`)
      promptAction.showToast({ message: '保存失败' })
    }
  }

  // 实际执行保存
  private async doSaveSettings() {
    try {
      // 检查是否有实际变更
      let hasAuthConfigChanged = this.startupAuthEnabled !== this.initialStartupAuthEnabled ||
        this.authMethodIndex !== this.initialAuthMethodIndex
      let hasPasswordChange = this.newPassword.length > 0

      // ========== 1. 优先验证密码字段（如果用户填写了当前密码）==========
      // 如果已有密码且用户输入了当前密码，无论是否有其他变更，都先验证
      if (this.hasExistingPassword && this.currentPassword.length > 0) {
        let verified = await SecureStorageService.verifyPassword(this.currentPassword)
        if (!verified) {
          promptAction.showToast({ message: '当前密码错误' })
          return
        }
        hilog.info(0x0004, TAG, 'Current password verified')
      }

      // ========== 2. 检查是否有变更 ==========
      if (!hasAuthConfigChanged && !hasPasswordChange) {
        promptAction.showToast({ message: '没有需要保存的更改' })
        return
      }

      // ========== 3. 保存启动校验配置 ==========
      if (hasAuthConfigChanged) {
        let prefs = await preferences.getPreferences(getContext(this), PREF_STORE_NAME_TOOL)
        await prefs.put(PREF_KEY_STARTUP_AUTH, this.startupAuthEnabled)
        await prefs.put(PREF_KEY_AUTH_METHOD, AUTH_METHOD_OPTIONS[this.authMethodIndex].value)
        await prefs.flush()
        hilog.info(0x0004, TAG, 'Startup auth settings saved')

        // 更新初始值
        this.initialStartupAuthEnabled = this.startupAuthEnabled
        this.initialAuthMethodIndex = this.authMethodIndex
      }

      // ========== 4. 保存密码变更 ==========
      if (hasPasswordChange) {
        // 验证新密码和确认密码一致
        if (this.newPassword !== this.confirmPassword) {
          promptAction.showToast({ message: '两次输入的密码不一致' })
          return
        }

        // 密码长度验证
        if (this.newPassword.length < 4) {
          promptAction.showToast({ message: '密码长度至少为 4 位' })
          return
        }

        // 如果已有密码，需要先验证当前密码（若前面未验证）
        if (this.hasExistingPassword && this.currentPassword.length === 0) {
          promptAction.showToast({ message: '请输入当前密码' })
          return
        }

        // 保存新密码
        let saved = await SecureStorageService.savePassword(this.newPassword)
        if (!saved) {
          promptAction.showToast({ message: '密码保存失败' })
          return
        }

        // 更新状态
        this.hasExistingPassword = true
        this.currentPassword = ''
        this.newPassword = ''
        this.confirmPassword = ''
      }

      promptAction.showToast({ message: '设置已保存' })
    } catch (err) {
      hilog.error(0x0004, TAG, `saveSettings failed: ${JSON.stringify(err)}`)
      promptAction.showToast({ message: '保存失败' })
    }
  }

  // 重置默认
  resetToDefault() {
    AlertDialog.show({
      title: '确认重置',
      message: '将恢复为默认配置：\n\n- 启用启动校验\n- 使用 PIN 码认证\n\n重置后需点击"保存设置"才会持久化。',
      primaryButton: {
        value: '确认',
        action: () => {
          this.startupAuthEnabled = DEFAULT_TOOL_SETTINGS.startupAuthEnabled
          this.authMethodIndex = AUTH_METHOD_OPTIONS.findIndex((opt) => opt.value === DEFAULT_TOOL_SETTINGS.authMethod)
          if (this.authMethodIndex < 0) {
            this.authMethodIndex = 0
          }
          this.currentPassword = ''
          this.newPassword = ''
          this.confirmPassword = ''
          promptAction.showToast({ message: '已重置，请点击"保存设置"以生效' })
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {}
      }
    })
  }

  // 测试认证
  async testAuth() {
    let authMethod = AUTH_METHOD_OPTIONS[this.authMethodIndex].value

    // 先检查可用性
    let checkResult = AuthService.checkAuthMethodAvailability(authMethod)
    if (!checkResult.available) {
      AlertDialog.show({
        title: '认证方式不可用',
        message: checkResult.message,
        confirm: {
          value: '知道了',
          action: () => {}
        }
      })
      return
    }

    // 执行认证
    let success = await AuthService.authenticate(authMethod)
    if (success) {
      promptAction.showToast({ message: '认证成功' })
    } else {
      promptAction.showToast({ message: '认证已取消' })
    }
  }

  build() {
    Column() {
      // 页面头部
      Row() {
        Column({ space: 4 }) {
          Text('工具设置')
            .fontSize(AppStyles.FONT_SIZE_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          Text('配置安全管理工具的启动校验和密码管理')
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
          // 功能区 1: 启动校验
          this.startupAuthBuilder()

          // 功能区 2: 工具密码管理
          this.passwordManageBuilder()
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

        Button('保存设置')
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(Color.White)
          .backgroundColor(AppColors.BRAND_PRIMARY)
          .borderRadius(AppStyles.RADIUS_MD)
          .height(36)
          .layoutWeight(1)
          .onClick(() => {
            this.saveSettings()
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

  // ==================== 功能区 1: 启动校验 ====================
  @Builder
  startupAuthBuilder() {
    Column({ space: 0 }) {
      // 区块标题
      Row() {
        Text('启动校验配置')
          .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        Blank()
        Text('userAuth')
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_TEXT)
          .backgroundColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_BG)
          .borderRadius(4)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      // 启动时密码校验开关
      Row() {
        Column({ space: 2 }) {
          Text('启动时身份校验')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          Text('开启后每次启动工具时需要进行身份认证')
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Toggle({ type: ToggleType.Switch, isOn: this.startupAuthEnabled })
          .selectedColor(AppColors.BRAND_PRIMARY)
          .onChange((value: boolean) => {
            this.startupAuthEnabled = value
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      // 认证方式选择
      Row() {
        Column({ space: 2 }) {
          Text('认证方式')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          Text('选择启动校验时使用的身份认证方式')
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Select(this.authMethodOptions)
          .selected(this.authMethodIndex)
          .value(this.authMethodOptions[this.authMethodIndex].value as string)
          .font({ size: AppStyles.FONT_SIZE_BODY })
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
          .optionFont({ size: AppStyles.FONT_SIZE_BODY })
          .width(140)
          .onSelect((index: number) => {
            this.authMethodIndex = index
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      // 测试认证按钮
      Row() {
        Blank()
        Button('测试认证')
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT)
          .backgroundColor(AppColors.getColors(this.currentTheme).TAG_BLUE_BG)
          .borderRadius(AppStyles.RADIUS_SM)
          .height(32)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            this.testAuth()
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    }
    .width('100%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .clip(true)
  }

  // ==================== 功能区 2: 工具密码管理 ====================
  @Builder
  passwordManageBuilder() {
    Column({ space: 0 }) {
      // 区块标题
      Row() {
        Text('工具密码管理')
          .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        Blank()
        Text('AssetStore')
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TAG_TEAL_TEXT)
          .backgroundColor(AppColors.getColors(this.currentTheme).TAG_TEAL_BG)
          .borderRadius(4)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      // 当前密码（仅在已有密码时显示）
      if (this.hasExistingPassword) {
        this.passwordInputRow('当前密码', '请输入当前密码', this.currentPassword, this.showCurrentPwd,
          (val: string) => {
            this.currentPassword = val
          },
          (show: boolean) => {
            this.showCurrentPwd = show
          })

        Divider()
          .color(AppColors.getColors(this.currentTheme).BORDER)
          .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
      }

      // 新密码
      this.passwordInputRow(this.hasExistingPassword ? '新密码' : '设置密码',
        this.hasExistingPassword ? '请输入新密码' : '请设置工具访问密码',
        this.newPassword, this.showNewPwd,
        (val: string) => {
          this.newPassword = val
        },
        (show: boolean) => {
          this.showNewPwd = show
        })

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      // 确认密码
      this.passwordInputRow('确认密码', '请再次输入密码', this.confirmPassword, this.showConfirmPwd,
        (val: string) => {
          this.confirmPassword = val
        },
        (show: boolean) => {
          this.showConfirmPwd = show
        })

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      // 提示信息
      Row() {
        Text(this.hasExistingPassword
          ? '提示：修改密码需要先验证当前密码。密码存储在设备安全区域内。'
          : '提示：首次设置密码后，再次修改需要验证当前密码。')
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(AppColors.getColors(this.currentTheme).TAG_BLUE_BG)
    }
    .width('100%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .clip(true)
  }

  // ==================== 密码输入行 Builder ====================
  @Builder
  passwordInputRow(label: string, placeholder: string, value: string, showPassword: boolean,
    onValueChange: (val: string) => void, onShowChange: (show: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        .width(100)

      TextInput({ placeholder: placeholder, text: value })
        .type(showPassword ? InputType.Normal : InputType.Password)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_COMPONENT)
        .borderRadius(AppStyles.RADIUS_SM)
        .height(36)
        .layoutWeight(1)
        .onChange((newValue: string) => {
          onValueChange(newValue)
        })

      Button() {
        Text(showPassword ? '隐藏' : '显示')
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
      }
      .type(ButtonType.Normal)
      .backgroundColor(Color.Transparent)
      .width(48)
      .height(36)
      .onClick(() => {
        onShowChange(!showPassword)
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
  }
}
