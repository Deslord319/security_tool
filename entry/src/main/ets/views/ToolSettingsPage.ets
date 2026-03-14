import { AppColors, AppStyles } from '../constants/AppConstants'
import { AuthService } from '../services/AuthService'
import { SystemSettingsService } from '../services/SystemSettingsService'
import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import {
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
import { BackNavButton } from '../components/BackNavButton'
import { HoverUtils } from '../utils/HoverUtils'
import { FormControlUtils } from '../utils/FormControlUtils'

const TAG = 'ToolSettingsPage'

@Component
export struct ToolSettingsPage {
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  onBack: () => void = () => {}
  @State hoveredCardIndex: number = -1
  @State startupAuthEnabled: boolean = DEFAULT_TOOL_SETTINGS.startupAuthEnabled
  @State authMethodIndex: number = 0

  private initialStartupAuthEnabled: boolean = DEFAULT_TOOL_SETTINGS.startupAuthEnabled
  private initialAuthMethodIndex: number = 0
  private authMethodOptions: SelectOption[] =
    AUTH_METHOD_OPTIONS.map((opt): SelectOption => ({ value: opt.label }))

  aboutToAppear() {
    this.loadSettings()
  }

  async loadSettings() {
    try {
      let prefs = await preferences.getPreferences(getContext(this), PREF_STORE_NAME_TOOL)
      let startupAuth = await prefs.get(PREF_KEY_STARTUP_AUTH, DEFAULT_TOOL_SETTINGS.startupAuthEnabled)
      this.startupAuthEnabled = startupAuth as boolean

      let authMethod = await prefs.get(PREF_KEY_AUTH_METHOD, DEFAULT_TOOL_SETTINGS.authMethod)
      let methodValue = authMethod as number
      let idx = AUTH_METHOD_OPTIONS.findIndex((opt) => opt.value === methodValue)
      if (idx >= 0) {
        this.authMethodIndex = idx
      }

      this.initialStartupAuthEnabled = this.startupAuthEnabled
      this.initialAuthMethodIndex = this.authMethodIndex
      hilog.info(0x0004, TAG, `Settings loaded: startupAuth=${this.startupAuthEnabled}, authMethod=${methodValue}`)
    } catch (err) {
      hilog.error(0x0004, TAG, `loadSettings failed: ${JSON.stringify(err)}`)
    }
  }

  async saveSettings() {
    try {
      if (this.startupAuthEnabled) {
        let authMethod = AUTH_METHOD_OPTIONS[this.authMethodIndex].value
        let checkResult = AuthService.checkAuthMethodAvailability(authMethod)
        if (!checkResult.available) {
          AlertDialog.show({
            title: '认证方式不可用',
            message: `${checkResult.message}\n\n继续保存后，启动时身份校验可能无法正常工作，请确认是否仍要保存设置。`,
            primaryButton: {
              value: '仍然保存',
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
      promptAction.showToast({ message: '保存设置失败' })
    }
  }

  private async doSaveSettings() {
    try {
      let hasAuthConfigChanged = this.startupAuthEnabled !== this.initialStartupAuthEnabled ||
        this.authMethodIndex !== this.initialAuthMethodIndex

      if (!hasAuthConfigChanged) {
        promptAction.showToast({ message: '当前没有需要保存的更改' })
        return
      }

      let prefs = await preferences.getPreferences(getContext(this), PREF_STORE_NAME_TOOL)
      await prefs.put(PREF_KEY_STARTUP_AUTH, this.startupAuthEnabled)
      await prefs.put(PREF_KEY_AUTH_METHOD, AUTH_METHOD_OPTIONS[this.authMethodIndex].value)
      await prefs.flush()

      this.initialStartupAuthEnabled = this.startupAuthEnabled
      this.initialAuthMethodIndex = this.authMethodIndex
      hilog.info(0x0004, TAG, 'Startup auth settings saved')
      promptAction.showToast({ message: '工具设置保存成功' })
    } catch (err) {
      hilog.error(0x0004, TAG, `saveSettings failed: ${JSON.stringify(err)}`)
      promptAction.showToast({ message: '保存设置失败' })
    }
  }

  private async openPasswordSettings() {
    try {
      const context = getContext(this) as common.UIAbilityContext
      const opened = await SystemSettingsService.openPasswordSettings(context)
      if (!opened) {
        promptAction.showToast({ message: '无法打开系统密码设置，请手动前往系统设置修改' })
      }
    } catch (err) {
      hilog.error(0x0004, TAG, `openPasswordSettings failed: ${JSON.stringify(err)}`)
      promptAction.showToast({ message: '无法打开系统密码设置，请手动前往系统设置修改' })
    }
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
            Text('工具设置')
              .fontSize(AppStyles.FONT_SIZE_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
            Text('配置启动认证与系统密码修改入口等工具级安全能力')
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
          '保存设置',
          $r('app.media.save'),
          Color.White,
          AppColors.BRAND_PRIMARY,
          () => {
            this.saveSettings()
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
          this.startupAuthBuilder()
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
  startupAuthBuilder() {
    Column({ space: 0 }) {
      Row() {
        Text('启动认证设置')
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
          Text('启动时身份校验')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          Text('开启后，进入工具前需要先完成系统认证')
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

      Row() {
        Column({ space: 2 }) {
          Text('认证方式')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          Text('选择启动时身份校验使用的系统认证方式')
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
          .fontColor(FormControlUtils.text(this.currentTheme))
          .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
          .optionFont({ size: AppStyles.FONT_SIZE_BODY })
          .width(140)
          .height(36)
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_SM)
          .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .onSelect((index: number) => {
            this.authMethodIndex = index
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      Row() {
        Column({ space: 2 }) {
          Text('修改密码')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          Text('打开系统设置中的“生物识别和密码”，修改系统 PIN/密码')
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button('修改密码')
          .type(ButtonType.Normal)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(Color.White)
          .backgroundColor(AppColors.BRAND_PRIMARY)
          .borderRadius(AppStyles.RADIUS_SM)
          .height(36)
          .padding({ left: 14, right: 14 })
          .onClick(() => {
            void this.openPasswordSettings()
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
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
}
