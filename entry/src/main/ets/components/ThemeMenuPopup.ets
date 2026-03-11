import { ThemeMode, ThemeOption } from '../theme/ThemeColors'
import { ThemeManager, STORAGE_KEY_THEME, STORAGE_KEY_OPTION } from '../theme/ThemeManager'
import { AppColors, AppStyles, AppInfo } from '../constants/AppConstants'

@CustomDialog
struct AboutDialog {
  controller: CustomDialogController
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  build() {
    Column({ space: 16 }) {
      Column() {
        Image($r('app.media.info'))
          .width(24)
          .height(24)
          .fillColor(AppColors.BRAND_PRIMARY)
      }
        .width(56)
        .height(56)
        .borderRadius(14)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(this.currentTheme === ThemeMode.DARK ? 'rgba(10,132,255,0.18)' : 'rgba(10,132,255,0.12)')

      Text(AppInfo.APP_NAME)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

      Text(`\u7248\u672c ${AppInfo.APP_VERSION}`)
        .fontSize(14)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)

      Text(AppInfo.BUNDLE_NAME)
        .fontSize(12)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)

      Text('Copyright 2025')
        .fontSize(12)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)

      Button('\u786e\u5b9a')
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
  @State hoveredThemeKey: string = ''
  @State hoveredActionKey: string = ''
  @State aboutHovered: boolean = false

  private aboutDialogController: CustomDialogController = new CustomDialogController({
    builder: AboutDialog(),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: true
  })

  build() {
    Column({ space: 6 }) {
      Column({ space: 6 }) {
        Text('\u663e\u793a\u6a21\u5f0f\uff1a')
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          .width('100%')
          .padding({ left: 8, right: 8, top: 4 })

        this.ThemeButton($r('app.media.dashboard'), '\u8ddf\u968f\u7cfb\u7edf', ThemeOption.SYSTEM)
        this.ThemeButton($r('app.media.sun'), '\u6d45\u8272\u6a21\u5f0f', ThemeOption.LIGHT)
        this.ThemeButton($r('app.media.moon'), '\u6df1\u8272\u6a21\u5f0f', ThemeOption.DARK)
      }
      .width('100%')

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
        .margin({ left: 8, right: 8, top: 2, bottom: 2 })

      Column({ space: 2 }) {
        this.ActionMenuItem($r('app.media.settings'), '\u5de5\u5177\u8bbe\u7f6e', 'tool-settings')
        this.ActionMenuItem($r('app.media.help'), '\u5e2e\u52a9\u4e0e\u53cd\u9988', 'help-feedback')
        this.AboutMenuItem()
      }
      .width('100%')
    }
    .width(236)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .shadow({
      radius: 16,
      color: this.currentTheme === ThemeMode.DARK ? 'rgba(0,0,0,0.4)' : 'rgba(0,0,0,0.15)',
      offsetX: 0,
      offsetY: 4
    })
    .padding(8)
  }

  private resolveMenuHoverBackground(isHovered: boolean): string {
    if (!isHovered) {
      return 'rgba(0,0,0,0)'
    }
    return this.currentTheme === ThemeMode.DARK ? AppColors.MENU_HOVER_DARK : AppColors.MENU_HOVER_LIGHT
  }

  private resolveThemeButtonBackground(option: ThemeOption): string {
    let isSelected = this.currentOption === option
    if (isSelected) {
      return this.currentTheme === ThemeMode.DARK ? 'rgba(125, 161, 255, 0.18)' : 'rgba(10, 132, 255, 0.12)'
    }
    return this.currentTheme === ThemeMode.DARK ? 'rgba(255,255,255,0.08)' : 'rgba(60,60,67,0.06)'
  }

  private resolveActionIconTileBackground(): string {
    return this.currentTheme === ThemeMode.DARK ? 'rgba(255,255,255,0.08)' : 'rgba(60,60,67,0.06)'
  }

  private resolveThemeIconColor(option: ThemeOption): ResourceColor {
    if (this.currentOption === option) {
      return this.currentTheme === ThemeMode.DARK ? '#A9C7FF' : AppColors.BRAND_PRIMARY
    }
    switch (option) {
      case ThemeOption.SYSTEM:
        return AppColors.BRAND_PRIMARY
      case ThemeOption.LIGHT:
        return '#FFD60A'
      case ThemeOption.DARK:
        return '#8E8E93'
      default:
        return AppColors.getColors(this.currentTheme).TEXT_PRIMARY
    }
  }

  private resolveActionIconColor(): ResourceColor {
    return this.currentTheme === ThemeMode.DARK ? '#A9C7FF' : '#2F6FE4'
  }

  @Builder
  ThemeButton(icon: Resource, label: string, option: ThemeOption) {
    Row({ space: 12 }) {
      Column() {
        Image(icon)
          .width(18)
          .height(18)
          .fillColor(this.resolveThemeIconColor(option))
      }
      .width(30)
      .height(30)
      .borderRadius(10)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(this.resolveThemeButtonBackground(option))

      Text(label)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(this.currentOption === option ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(this.currentOption === option ? AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY : AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .layoutWeight(1)
    }
      .id(`theme-option-${option}`)
      .width('100%')
      .height(44)
      .padding({ left: 8, right: 10 })
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)
      .borderRadius(12)
      .backgroundColor(this.resolveMenuHoverBackground(this.hoveredThemeKey === option))
      .onHover((hover: boolean) => {
        this.hoveredThemeKey = hover ? option : ''
      })
      .onClick(() => {
        ThemeManager.getInstance().setOption(option)
        this.showMenu = false
      })
  }

  @Builder
  ActionMenuItem(icon: Resource, label: string, route: string) {
    Row({ space: 12 }) {
      Column() {
        Image(icon)
          .width(18)
          .height(18)
          .fillColor(this.resolveActionIconColor())
      }
      .width(30)
      .height(30)
      .borderRadius(10)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(this.resolveActionIconTileBackground())

      Text(label)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        .layoutWeight(1)
    }
    .id(`menu-action-${route}`)
    .width('100%')
    .height(44)
    .padding({ left: 8, right: 10 })
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.resolveMenuHoverBackground(this.hoveredActionKey === route))
    .borderRadius(12)
    .onHover((hover: boolean) => {
      this.hoveredActionKey = hover ? route : ''
    })
    .onClick(() => {
      this.showMenu = false
      if (route && this.onNavigate) {
        this.onNavigate(route)
      }
    })
  }

  @Builder
  AboutMenuItem() {
    Row({ space: 12 }) {
      Column() {
        Image($r('app.media.info'))
          .width(18)
          .height(18)
          .fillColor(this.resolveActionIconColor())
      }
      .width(30)
      .height(30)
      .borderRadius(10)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(this.resolveActionIconTileBackground())

      Text('\u5173\u4e8e')
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        .layoutWeight(1)
    }
    .id('menu-action-about')
    .width('100%')
    .height(44)
    .padding({ left: 8, right: 10 })
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.resolveMenuHoverBackground(this.aboutHovered))
    .borderRadius(12)
    .onHover((isHover: boolean) => {
      this.aboutHovered = isHover
    })
    .onClick(() => {
      this.showMenu = false
      this.aboutDialogController.open()
    })
  }
}
