import { ThemeMode, ThemeOption } from '../theme/ThemeColors'
import { ThemeManager, STORAGE_KEY_THEME, STORAGE_KEY_OPTION } from '../theme/ThemeManager'
import { AppColors, AppStyles, AppInfo, InteractiveItemStyles } from '../constants/AppConstants'
import { CommonStrings } from '../constants/CommonStrings'

@Component
export struct InteractiveMenuRow {
  @Prop icon: Resource = $r('app.media.dashboard')
  @Prop label: string = ''
  @Prop itemId: string = ''
  @Prop currentTheme: ThemeMode = ThemeMode.LIGHT
  @Prop showLabel: boolean = true
  @Prop fixedWidth: number = 0
  @Prop itemBackground: ResourceColor = Color.Transparent
  @Prop iconTileBackground: ResourceColor = Color.Transparent
  @Prop iconColor: ResourceColor = Color.Black
  @Prop textColor: ResourceColor = Color.Black
  @Prop textOpacity: number = 1
  @Prop fontWeight: FontWeight = FontWeight.Normal
  onTap: () => void = () => {}
  onHoverChange: (isHover: boolean) => void = () => {}
  onPressedChange: (isPressed: boolean) => void = () => {}

  build() {
    Row({ space: this.showLabel ? 12 : 0 }) {
      Column() {
        Image(this.icon)
          .width(InteractiveItemStyles.ICON_SIZE)
          .height(InteractiveItemStyles.ICON_SIZE)
          .fillColor(this.iconColor)
          .draggable(false)
      }
      .width(InteractiveItemStyles.ICON_TILE_SIZE)
      .height(InteractiveItemStyles.ICON_TILE_SIZE)
      .borderRadius(InteractiveItemStyles.ICON_TILE_RADIUS)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(this.iconTileBackground)

      if (this.showLabel) {
        Text(this.label)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(this.fontWeight)
          .fontColor(this.textColor)
          .opacity(this.textOpacity)
          .layoutWeight(1)
      }
    }
    .id(this.itemId)
    .width(this.fixedWidth > 0 ? this.fixedWidth : '100%')
    .height(InteractiveItemStyles.ITEM_HEIGHT)
    .padding({
      left: this.showLabel ? InteractiveItemStyles.ITEM_HORIZONTAL_PADDING_START : 0,
      right: this.showLabel ? InteractiveItemStyles.ITEM_HORIZONTAL_PADDING_END : 0
    })
    .justifyContent(this.showLabel ? FlexAlign.Start : FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(InteractiveItemStyles.ITEM_RADIUS)
    .backgroundColor(this.itemBackground)
    .onHover((isHover: boolean) => {
      this.onHoverChange(isHover)
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.onPressedChange(true)
        return
      }
      if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.onPressedChange(false)
      }
    })
    .onClick(() => {
      this.onPressedChange(false)
      this.onTap()
    })
  }
}

@CustomDialog
struct AboutDialog {
  controller: CustomDialogController
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  build() {
    Column({ space: 16 }) {
      Image($r('app.media.startIcon_about'))
        .width(80)
        .height(80)
        .draggable(false)

      Text(AppInfo.APP_NAME)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

      Text(`${CommonStrings.versionLabel} ${AppInfo.APP_VERSION}`)
        .fontSize(14)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)

      Text('Copyright 2026')
        .fontSize(12)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)

      Button(CommonStrings.actionConfirm)
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
  @State activeThemeKey: string = ''
  @State activeActionKey: string = ''
  @State aboutPressed: boolean = false
  @State menuHoverArmed: boolean = false

  private aboutDialogController: CustomDialogController = new CustomDialogController({
    builder: AboutDialog(),
    alignment: DialogAlignment.Center,
    autoCancel: false,
    customStyle: true
  })

  aboutToDisappear(): void {
    try {
      this.aboutDialogController.close()
    } catch (_err) {
    }
  }

  build() {
    Column({ space: 6 }) {
      Column({ space: 6 }) {
        Text(CommonStrings.themeSectionTitle)
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          .width('100%')
          .padding({ left: 8, right: 8, top: 4 })

        this.themeButton($r('app.media.dashboard'), CommonStrings.themeFollowSystem, ThemeOption.SYSTEM)
        this.themeButton($r('app.media.sun'), CommonStrings.themeLightMode, ThemeOption.LIGHT)
        this.themeButton($r('app.media.moon'), CommonStrings.themeDarkMode, ThemeOption.DARK)
      }
      .width('100%')

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
        .margin({ left: 8, right: 8, top: 2, bottom: 2 })

      Column({ space: 2 }) {
        this.actionMenuItem($r('app.media.help_menu'), CommonStrings.moduleHelpFeedback, 'help-feedback')
        this.aboutMenuItem()
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

  private resolveMenuBackground(isHovered: boolean, isPressed: boolean): string {
    return InteractiveItemStyles.getMenuItemBackground(this.currentTheme, isHovered, isPressed)
  }

  private resolveMenuIconFillColor(): ResourceColor {
    return InteractiveItemStyles.getMenuIconColor(this.currentTheme)
  }

  private resolveMenuIconTileBackground(): string {
    return InteractiveItemStyles.getMenuIconTileBackground(this.currentTheme)
  }

  @Builder
  private themeButton(icon: Resource, label: string, option: ThemeOption) {
    InteractiveMenuRow({
      icon: icon,
      label: label,
      itemId: `theme-option-${option}`,
      currentTheme: this.currentTheme,
      itemBackground: this.resolveMenuBackground(this.hoveredThemeKey === option, this.activeThemeKey === option),
      iconTileBackground: this.resolveMenuIconTileBackground(),
      iconColor: this.resolveMenuIconFillColor(),
      textColor: AppColors.getColors(this.currentTheme).TEXT_PRIMARY,
      textOpacity: this.currentOption === option
        ? AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY
        : AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY,
      fontWeight: this.currentOption === option ? FontWeight.Bold : FontWeight.Normal,
      onHoverChange: (hover: boolean) => {
        if (!this.menuHoverArmed) {
          return
        }
        this.hoveredThemeKey = hover ? option : ''
      },
      onPressedChange: (isPressed: boolean) => {
        this.activeThemeKey = isPressed ? option : ''
      },
      onTap: () => {
        this.activeThemeKey = ''
        ThemeManager.getInstance().setOption(option)
        this.showMenu = false
      }
    })
  }

  @Builder
  private actionMenuItem(icon: Resource, label: string, route: string) {
    InteractiveMenuRow({
      icon: icon,
      label: label,
      itemId: `menu-action-${route}`,
      currentTheme: this.currentTheme,
      itemBackground: this.resolveMenuBackground(this.hoveredActionKey === route, this.activeActionKey === route),
      iconTileBackground: this.resolveMenuIconTileBackground(),
      iconColor: this.resolveMenuIconFillColor(),
      textColor: AppColors.getColors(this.currentTheme).TEXT_PRIMARY,
      textOpacity: AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY,
      onHoverChange: (hover: boolean) => {
        if (!this.menuHoverArmed) {
          return
        }
        this.hoveredActionKey = hover ? route : ''
      },
      onPressedChange: (isPressed: boolean) => {
        this.activeActionKey = isPressed ? route : ''
      },
      onTap: () => {
        this.activeActionKey = ''
        this.showMenu = false
        if (route && this.onNavigate) {
          this.onNavigate(route)
        }
      }
    })
  }

  @Builder
  private aboutMenuItem() {
    InteractiveMenuRow({
      icon: $r('app.media.info_menu'),
      label: CommonStrings.aboutLabel,
      itemId: 'menu-action-about',
      currentTheme: this.currentTheme,
      itemBackground: this.resolveMenuBackground(this.aboutHovered, this.aboutPressed),
      iconTileBackground: this.resolveMenuIconTileBackground(),
      iconColor: this.resolveMenuIconFillColor(),
      textColor: AppColors.getColors(this.currentTheme).TEXT_PRIMARY,
      textOpacity: AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY,
      onHoverChange: (isHover: boolean) => {
        if (!this.menuHoverArmed) {
          return
        }
        this.aboutHovered = isHover
      },
      onPressedChange: (isPressed: boolean) => {
        this.aboutPressed = isPressed
      },
      onTap: () => {
        this.aboutPressed = false
        this.showMenu = false
        this.aboutDialogController.open()
      }
    })
  }
}
