import { ThemeMode, ThemeOption } from '../theme/ThemeColors'
import { ThemeManager, STORAGE_KEY_THEME, STORAGE_KEY_OPTION } from '../theme/ThemeManager'
import { AppColors, AppStyles, AppInfo } from '../constants/AppConstants'

@CustomDialog
struct AboutDialog {
  controller: CustomDialogController
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  build() {
    Column({ space: 16 }) {
      Image($r('app.media.startIcon_about'))
        .width(80)
        .height(80)

      Text(AppInfo.APP_NAME)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

      Text(`版本 ${AppInfo.APP_VERSION}`)
        .fontSize(14)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)

      Text('Copyright 2026')
        .fontSize(12)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)

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
  @State hoveredThemeKey: string = ''
  @State hoveredActionKey: string = ''
  @State aboutHovered: boolean = false
  @State menuHoverArmed: boolean = false

  private aboutDialogController: CustomDialogController = new CustomDialogController({
    builder: AboutDialog(),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: true
  })

  build() {
    Column({ space: 6 }) {
      Column({ space: 6 }) {
        Text('显示模式')
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          .width('100%')
          .padding({ left: 8, right: 8, top: 4 })

        this.ThemeButton($r('app.media.dashboard'), '跟随系统', ThemeOption.SYSTEM)
        this.ThemeButton($r('app.media.sun'), '浅色模式', ThemeOption.LIGHT)
        this.ThemeButton($r('app.media.moon'), '深色模式', ThemeOption.DARK)
      }
      .width('100%')

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
        .margin({ left: 8, right: 8, top: 2, bottom: 2 })

      Column({ space: 2 }) {
        this.ActionMenuItem($r('app.media.help_menu'), '帮助与反馈', 'help-feedback')
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
    .onAppear(() => {
      this.hoveredThemeKey = ''
      this.hoveredActionKey = ''
      this.aboutHovered = false
      this.menuHoverArmed = false
    })
    .onHover((isHover: boolean) => {
      if (isHover) {
        this.menuHoverArmed = true
        return
      }
      this.menuHoverArmed = false
      this.hoveredThemeKey = ''
      this.hoveredActionKey = ''
      this.aboutHovered = false
    })
  }

  private resolveMenuHoverBackground(isHovered: boolean): string {
    if (!isHovered) {
      return 'rgba(0,0,0,0)'
    }
    return this.currentTheme === ThemeMode.DARK ? AppColors.MENU_HOVER_DARK : AppColors.MENU_HOVER_LIGHT
  }

  private resolveMenuIconFillColor(): ResourceColor {
    return this.currentTheme === ThemeMode.DARK ? '#A9C7FF' : AppColors.BRAND_PRIMARY
  }

  private resolveMenuIconTileBackground(): string {
    return this.currentTheme === ThemeMode.DARK ? 'rgba(255,255,255,0.08)' : 'rgba(60,60,67,0.06)'
  }

  @Builder
  ThemeButton(icon: Resource, label: string, option: ThemeOption) {
    Row({ space: 12 }) {
      Column() {
        Image(icon)
          .width(18)
          .height(18)
          .fillColor(this.resolveMenuIconFillColor())
      }
      .width(30)
      .height(30)
      .borderRadius(10)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(this.resolveMenuIconTileBackground())

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
        if (!this.menuHoverArmed) {
          return
        }
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
          .fillColor(this.resolveMenuIconFillColor())
      }
      .width(30)
      .height(30)
      .borderRadius(10)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(this.resolveMenuIconTileBackground())

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
      if (!this.menuHoverArmed) {
        return
      }
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
        Image($r('app.media.info_menu'))
          .width(18)
          .height(18)
          .fillColor(this.resolveMenuIconFillColor())
      }
      .width(30)
      .height(30)
      .borderRadius(10)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(this.resolveMenuIconTileBackground())

      Text('关于')
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
      if (!this.menuHoverArmed) {
        return
      }
      this.aboutHovered = isHover
    })
    .onClick(() => {
      this.showMenu = false
      this.aboutDialogController.open()
    })
  }
}
