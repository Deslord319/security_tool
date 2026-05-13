import { ThemeMode, ThemeOption } from '../theme/ThemeColors'
import { bundleManager } from '@kit.AbilityKit'
import { AppColors, AppStyles, InteractiveItemStyles } from '../constants/AppConstants'
import { AppResources } from '../constants/AppResources'
import { ActionText, AppText, ModuleText, ThemeText } from '../constants/StringCatalog'
import { RouteIds } from '../constants/RouteIds'
import { DetailDialogShell } from './DetailDialogShell'

@ComponentV2
export struct InteractiveMenuRow {
  @Param icon: Resource = AppResources.DASHBOARD_ICON
  @Param label: string = ''
  @Param itemId: string = ''
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Param showLabel: boolean = true
  @Param fixedWidth: number = 0
  @Param itemBackground: ResourceColor = Color.Transparent
  @Param iconTileBackground: ResourceColor = Color.Transparent
  @Param iconColor: ResourceColor = Color.Black
  @Param textColor: ResourceColor = Color.Black
  @Param textOpacity: number = 1
  @Param fontWeight: FontWeight = FontWeight.Normal
  @Event onTap: () => void = () => {}
  @Event onHoverChange: (isHover: boolean) => void = () => {}
  @Event onPressedChange: (isPressed: boolean) => void = () => {}

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
export struct AboutDialogContent {
  controller: CustomDialogController
  currentTheme: ThemeMode = ThemeMode.LIGHT
  onConfirm: () => void = () => {}

  @Builder
  private aboutContent() {
    Column({ space: 14 }) {
      Image(AppResources.START_ICON_ABOUT)
        .width(80)
        .height(80)
        .margin({ top: 18 })
        .draggable(false)

      Text(AppText.NAME)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

      Text(`${AppText.VERSION} ${this.resolveAppVersion()}`)
        .fontSize(14)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)

      Text(AppText.COPYRIGHT)
        .fontSize(12)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)

      Button(ActionText.CONFIRM)
        .width(180)
        .height(AppStyles.BUTTON_HEIGHT)
        .fontSize(16)
        .fontColor(Color.White)
        .backgroundColor(AppColors.BRAND_PRIMARY)
        .borderRadius(AppStyles.RADIUS_MD)
        .onClick(() => {
          this.onConfirm()
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    DetailDialogShell({
      title: AppText.ABOUT,
      dialogWidth: 360,
      maxBodyHeight: 290,
      currentTheme: this.currentTheme,
      showHeader: false,
      showCloseAction: false,
      bodyRightPaddingExtra: 0,
      onClose: this.onConfirm,
      content: () => {
        this.aboutContent()
      }
    })
  }

  private resolveAppVersion(): string {
    try {
      const bundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      )
      return bundleInfo.versionName
    } catch (_) {
      return ''
    }
  }
}

@ComponentV2
export struct ThemeMenuPopup {
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Param currentOption: ThemeOption = ThemeOption.SYSTEM
  @Event onDismiss: () => void = () => {}
  @Event onNavigate: (route: string) => void = () => {}
  @Event onSelectOption: (option: ThemeOption) => void = () => {}
  @Event onOpenAbout: () => void = () => {}
  @Local hoveredThemeKey: string = ''
  @Local hoveredActionKey: string = ''
  @Local aboutHovered: boolean = false
  @Local activeThemeKey: string = ''
  @Local activeActionKey: string = ''
  @Local aboutPressed: boolean = false
  @Local menuHoverArmed: boolean = false

  build() {
    Column({ space: 6 }) {
      Column({ space: 6 }) {
        Text(ThemeText.SECTION_TITLE)
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          .width('100%')
          .padding({ left: 8, right: 8, top: 4 })

        this.themeButton(AppResources.DASHBOARD_ICON, ThemeText.FOLLOW_SYSTEM, ThemeOption.SYSTEM)
        this.themeButton(AppResources.SUN_ICON, ThemeText.LIGHT_MODE, ThemeOption.LIGHT)
        this.themeButton(AppResources.MOON_ICON, ThemeText.DARK_MODE, ThemeOption.DARK)
      }
      .width('100%')

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
        .margin({ left: 8, right: 8, top: 2, bottom: 2 })

      Column({ space: 2 }) {
        this.actionMenuItem(AppResources.HELP_MENU_ICON, ModuleText.HELP_FEEDBACK, RouteIds.HELP_FEEDBACK)
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
        this.onSelectOption(option)
        this.onDismiss()
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
        this.onDismiss()
        this.onNavigate(route)
      }
    })
  }

  @Builder
  private aboutMenuItem() {
    InteractiveMenuRow({
      icon: AppResources.INFO_MENU_ICON,
      label: AppText.ABOUT,
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
        this.onDismiss()
        this.onOpenAbout()
      }
    })
  }
}
