import { ThemeMode, ThemeOption } from '../theme/ThemeColors'
import { ThemeManager, STORAGE_KEY_THEME, STORAGE_KEY_OPTION } from '../theme/ThemeManager'
import { AppColors, AppStyles, AppInfo } from '../constants/AppConstants'

@CustomDialog
struct AboutDialog {
  controller: CustomDialogController
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  build() {
    Column({ space: 16 }) {
      // 应用图标
      Text('S')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .textAlign(TextAlign.Center)
        .width(56)
        .height(56)
        .borderRadius(14)
        .backgroundColor(AppColors.BRAND_PRIMARY)

      // 应用名称
      Text(AppInfo.APP_NAME)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

      // 版本号
      Text('版本 ' + AppInfo.APP_VERSION)
        .fontSize(14)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)

      // 包名
      Text(AppInfo.BUNDLE_NAME)
        .fontSize(12)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)

      // 版权
      Text('Copyright \u00A9 2025')
        .fontSize(12)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)

      // 确定按钮
      Button('确定')
        .width('100%')
        .height(40)
        .fontSize(16)
        .fontColor(Color.White)
        .backgroundColor(AppColors.BRAND_PRIMARY)
        .borderRadius(AppStyles.RADIUS_MD)
        .onClick(() => {
          this.controller.close()
        })
    }
    .width(360)
    .padding(24)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
  }
}

@Component
export struct ThemeMenuPopup {
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  @StorageLink(STORAGE_KEY_OPTION) currentOption: ThemeOption = ThemeOption.SYSTEM
  @Link showMenu: boolean
  onNavigate?: (route: string) => void

  private aboutDialogController: CustomDialogController = new CustomDialogController({
    builder: AboutDialog(),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: true
  })

  build() {
    Column() {
      // 主题选择区域（单行紧凑布局）
      Row() {
        Text('显示模式')
          .fontSize(12)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          .fontWeight(FontWeight.Medium)

        Blank()

        Row({ space: 4 }) {
          this.ThemeButton('\uD83D\uDDA5', ThemeOption.SYSTEM)
          this.ThemeButton('\u2600', ThemeOption.LIGHT)
          this.ThemeButton('\uD83C\uDF19', ThemeOption.DARK)
        }
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 12 })
      .alignItems(VerticalAlign.Center)

      // 分隔线
      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
        .margin({ left: 16, right: 16 })

      // 设置
      this.ActionMenuItem('设置', '\u2699', 'tool-settings')

      // 帮助和反馈
      this.ActionMenuItem('帮助和反馈', '?', 'help-feedback')

      // 关于
      Row() {
        Text('\u24D8')
          .fontSize(16)
          .width(24)
          .textAlign(TextAlign.Center)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)

        Text('关于')
          .fontSize(14)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          .layoutWeight(1)
          .margin({ left: 8 })
      }
      .width('100%')
      .height(44)
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        this.showMenu = false
        this.aboutDialogController.open()
      })
    }
    .width(220)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .shadow({
      radius: 16,
      color: this.currentTheme === ThemeMode.DARK ? 'rgba(0,0,0,0.4)' : 'rgba(0,0,0,0.15)',
      offsetX: 0,
      offsetY: 4
    })
    .padding({ top: 4, bottom: 8 })
  }

  @Builder
  ThemeButton(icon: string, option: ThemeOption) {
    Text(icon)
      .fontSize(16)
      .id(`theme-option-${option}`)
      .fontColor(this.currentOption === option ? Color.White :
        AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
      .opacity(this.currentOption === option ? 1 :
        AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
      .width(32)
      .height(32)
      .textAlign(TextAlign.Center)
      .borderRadius(AppStyles.RADIUS_MD)
      .backgroundColor(this.currentOption === option ? AppColors.BRAND_PRIMARY :
        (this.currentTheme === ThemeMode.DARK ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.05)'))
      .onClick(() => {
        ThemeManager.getInstance().setOption(option)
        this.showMenu = false
      })
  }

  @Builder
  ActionMenuItem(label: string, icon: string, route: string) {
    Row() {
      Text(icon)
        .fontSize(16)
        .width(24)
        .textAlign(TextAlign.Center)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)

      Text(label)
        .fontSize(14)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        .layoutWeight(1)
        .margin({ left: 8 })
    }
    .width('100%')
    .height(44)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      this.showMenu = false
      if (route && this.onNavigate) {
        this.onNavigate(route)
      }
    })
  }
}
