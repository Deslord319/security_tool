import { AppColors, AppStyles, InteractiveItemStyles, NavItem, NAV_ITEMS, AppInfo } from '../constants/AppConstants'
import { CommonStrings } from '../constants/CommonStrings'
import { ThemeMode } from '../theme/ThemeColors'
import { ThemeManager, STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { InteractiveMenuRow } from './ThemeMenuPopup'

@Component
export struct SideBar {
  @Prop selectedId: string = 'dashboard'
  onItemSelect: (id: string) => void = () => {}
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  @State hoveredNavId: string = ''
  @State themeToggleHovered: boolean = false
  @State activeNavId: string = ''
  @State themeTogglePressed: boolean = false

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
    return this.currentTheme === ThemeMode.DARK ? $r('app.media.moon') : $r('app.media.sun')
  }

  private getThemeModeLabel(): string {
    return this.currentTheme === ThemeMode.DARK ? CommonStrings.themeDarkMode : CommonStrings.themeLightMode
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
        Image($r('app.media.startIcon_about'))
          .width(20)
          .height(20)
          .draggable(false)

        Text(AppInfo.APP_NAME)
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
          ThemeManager.getInstance().toggleTheme()
        }
      })
    }
    .width(AppStyles.SIDEBAR_WIDTH)
    .height('100%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
  }
}
