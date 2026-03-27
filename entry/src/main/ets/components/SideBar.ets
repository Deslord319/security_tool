import { AppColors, AppStyles, NavItem, NAV_ITEMS, AppInfo } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { ThemeManager, STORAGE_KEY_THEME } from '../theme/ThemeManager'

@Component
export struct SideBar {
  @Prop selectedId: string = 'dashboard'
  onItemSelect: (id: string) => void = () => {}
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  @State hoveredNavId: string = ''
  @State themeToggleHovered: boolean = false

  private getNavIconBackground(itemId: string): string {
    if (this.selectedId === itemId) {
      return AppColors.SIDEBAR_SELECTED_TILE
    }
    return this.currentTheme === ThemeMode.DARK ? 'rgba(10,132,255,0.14)' : 'rgba(10,132,255,0.08)'
  }

  private getNavItemBackground(itemId: string): string {
    if (this.selectedId === itemId) {
      return AppColors.BRAND_PRIMARY
    }
    return this.hoveredNavId === itemId ? (this.currentTheme === ThemeMode.DARK ? AppColors.MENU_HOVER_DARK : AppColors.MENU_HOVER_LIGHT) : 'rgba(0,0,0,0)'
  }

  private getThemeModeIcon(): Resource {
    return this.currentTheme === ThemeMode.DARK ? $r('app.media.moon') : $r('app.media.sun')
  }

  private getThemeModeLabel(): string {
    return this.currentTheme === ThemeMode.DARK ? '深色模式' : '浅色模式'
  }

  private getThemeModeIconColor(): string {
    return this.currentTheme === ThemeMode.DARK ? '#8E8E93' : '#FFD60A'
  }

  private getThemeModeIconBackground(): string {
    return this.currentTheme === ThemeMode.DARK ? 'rgba(142,142,147,0.18)' : 'rgba(255,214,10,0.14)'
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        Image($r('app.media.startIcon_about'))
          .width(20)
          .height(20)
          .fillColor(AppColors.BRAND_PRIMARY)

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
            Row({ space: 12 }) {
              Column() {
                Image(item.icon)
                  .width(16)
                  .height(16)
                  .fillColor(this.selectedId === item.id ? AppColors.SIDEBAR_SELECTED_ICON : AppColors.BRAND_PRIMARY)
              }
              .width(28)
              .height(28)
              .borderRadius(6)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .backgroundColor(this.getNavIconBackground(item.id))

              Text(item.label)
                .fontSize(AppStyles.FONT_SIZE_BODY)
                .fontWeight(this.selectedId === item.id ? FontWeight.Medium : (this.hoveredNavId === item.id ? FontWeight.Bold : FontWeight.Normal))
                .fontColor(this.selectedId === item.id ? Color.White : AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(this.selectedId === item.id ? 1 : AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
            }
            .width('100%')
            .height(44)
            .id(`sidebar-nav-${item.id}`)
            .padding({ left: 12, right: 12 })
            .borderRadius(AppStyles.RADIUS_MD)
            .backgroundColor(this.getNavItemBackground(item.id))
            .onHover((isHover: boolean) => {
              this.hoveredNavId = isHover ? item.id : ''
            })
            .onClick(() => {
              this.onItemSelect(item.id)
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

      Row({ space: 12 }) {
        Column() {
          Image(this.getThemeModeIcon())
            .width(16)
            .height(16)
            .fillColor(this.getThemeModeIconColor())
        }
        .width(28)
        .height(28)
        .borderRadius(6)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(this.getThemeModeIconBackground())

        Text(this.getThemeModeLabel())
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .id(this.currentTheme === ThemeMode.DARK ? 'theme-mode-dark' : 'theme-mode-light')
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
      }
      .width('100%')
      .height(48)
      .id('sidebar-theme-toggle')
      .padding({ left: 20, right: 20 })
      .borderRadius(AppStyles.RADIUS_MD)
      .backgroundColor(this.themeToggleHovered ? (this.currentTheme === ThemeMode.DARK ? AppColors.MENU_HOVER_DARK : AppColors.MENU_HOVER_LIGHT) : Color.Transparent)
      .onHover((isHover: boolean) => {
        this.themeToggleHovered = isHover
      })
      .onClick(() => {
        ThemeManager.getInstance().toggleTheme()
      })
    }
    .width(AppStyles.SIDEBAR_WIDTH)
    .height('100%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
  }
}
