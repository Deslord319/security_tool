import { AppColors, AppStyles, InteractiveItemStyles, NavItem, NAV_ITEMS } from '../constants/AppConstants'
import { AppResources } from '../constants/AppResources'
import { AppText, ThemeText } from '../constants/StringCatalog'
import { RouteIds } from '../constants/RouteIds'
import { ThemeMode } from '../theme/ThemeColors'
import { InteractiveMenuRow } from './ThemeMenuPopup'

@ComponentV2
export struct SideBar {
  @Param selectedId: string = RouteIds.DASHBOARD
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Event onItemSelect: (id: string) => void = () => {}
  @Event onToggleTheme: () => void = () => {}
  @Local hoveredNavId: string = ''
  @Local themeToggleHovered: boolean = false
  @Local activeNavId: string = ''
  @Local themeTogglePressed: boolean = false

  private getNavIconBackground(itemId: string): string {
    return InteractiveItemStyles.getSidebarIconTileBackground(this.currentTheme, this.selectedId === itemId)
  }

  private getNavItemBackground(itemId: string): string {
    return InteractiveItemStyles.getSidebarItemBackground(
      this.currentTheme,
      this.selectedId === itemId,
      this.hoveredNavId === itemId,
      this.activeNavId === itemId
    )
  }

  private getThemeModeIcon(): Resource {
    return this.currentTheme === ThemeMode.DARK ? AppResources.MOON_ICON : AppResources.SUN_ICON
  }

  private getThemeModeLabel(): string {
    return this.currentTheme === ThemeMode.DARK ? ThemeText.DARK_MODE : ThemeText.LIGHT_MODE
  }

  private getThemeModeIconColor(): string {
    return InteractiveItemStyles.getThemeModeIconColor(this.currentTheme)
  }

  private getThemeModeIconBackground(): string {
    return InteractiveItemStyles.getThemeModeIconTileBackground(this.currentTheme)
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        Image(AppResources.START_ICON_ABOUT)
          .width(20)
          .height(20)
          .draggable(false)

        Text(AppText.NAME)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      List({ space: 4 }) {
        ForEach(NAV_ITEMS, (item: NavItem) => {
          ListItem() {
            InteractiveMenuRow({
              icon: item.icon,
              label: item.label,
              itemId: `sidebar-nav-${item.id}`,
              currentTheme: this.currentTheme,
              itemBackground: this.getNavItemBackground(item.id),
              iconTileBackground: this.getNavIconBackground(item.id),
              iconColor: InteractiveItemStyles.getSidebarIconColor(this.currentTheme, this.selectedId === item.id),
              textColor: InteractiveItemStyles.getSidebarTextColor(this.currentTheme, this.selectedId === item.id),
              textOpacity: this.selectedId === item.id ? 1 : AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY,
              fontWeight: this.selectedId === item.id ? FontWeight.Medium : (this.hoveredNavId === item.id ? FontWeight.Bold : FontWeight.Normal),
              onHoverChange: (isHover: boolean) => {
                this.hoveredNavId = isHover ? item.id : ''
              },
              onPressedChange: (isPressed: boolean) => {
                this.activeNavId = isPressed ? item.id : ''
              },
              onTap: () => {
                this.activeNavId = ''
                this.onItemSelect(item.id)
              }
            })
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 8, right: 8, top: 8 })

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      InteractiveMenuRow({
        icon: this.getThemeModeIcon(),
        label: this.getThemeModeLabel(),
        itemId: this.currentTheme === ThemeMode.DARK ? 'theme-mode-dark' : 'theme-mode-light',
        currentTheme: this.currentTheme,
        itemBackground: InteractiveItemStyles.getMenuItemBackground(this.currentTheme, this.themeToggleHovered, this.themeTogglePressed),
        iconTileBackground: this.getThemeModeIconBackground(),
        iconColor: this.getThemeModeIconColor(),
        textColor: AppColors.getColors(this.currentTheme).TEXT_PRIMARY,
        textOpacity: AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY,
        onHoverChange: (isHover: boolean) => {
          this.themeToggleHovered = isHover
        },
        onPressedChange: (isPressed: boolean) => {
          this.themeTogglePressed = isPressed
        },
        onTap: () => {
          this.themeTogglePressed = false
          this.onToggleTheme()
        }
      })
    }
    .width(AppStyles.SIDEBAR_WIDTH)
    .height('100%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
  }
}
