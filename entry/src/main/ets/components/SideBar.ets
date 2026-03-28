import { AppColors, AppStyles, InteractiveItemStyles, NavItem, NAV_ITEMS, AppInfo } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { ThemeManager, STORAGE_KEY_THEME } from '../theme/ThemeManager'

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
    return this.currentTheme === ThemeMode.DARK ? '深色模式' : '浅色模式'
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
            Row({ space: 12 }) {
              Column() {
                Image(item.icon)
                  .width(InteractiveItemStyles.ICON_SIZE)
                  .height(InteractiveItemStyles.ICON_SIZE)
                  .fillColor(InteractiveItemStyles.getSidebarIconColor(this.currentTheme, this.selectedId === item.id))
                  .draggable(false)
              }
              .width(InteractiveItemStyles.ICON_TILE_SIZE)
              .height(InteractiveItemStyles.ICON_TILE_SIZE)
              .borderRadius(InteractiveItemStyles.ICON_TILE_RADIUS)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .backgroundColor(this.getNavIconBackground(item.id))

              Text(item.label)
                .fontSize(AppStyles.FONT_SIZE_BODY)
                .fontWeight(this.selectedId === item.id ? FontWeight.Medium : (this.hoveredNavId === item.id ? FontWeight.Bold : FontWeight.Normal))
                .fontColor(InteractiveItemStyles.getSidebarTextColor(this.currentTheme, this.selectedId === item.id))
                .opacity(this.selectedId === item.id ? 1 : AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
            }
            .width('100%')
            .height(InteractiveItemStyles.ITEM_HEIGHT)
            .id(`sidebar-nav-${item.id}`)
            .padding({
              left: InteractiveItemStyles.ITEM_HORIZONTAL_PADDING_START,
              right: InteractiveItemStyles.ITEM_HORIZONTAL_PADDING_END
            })
            .borderRadius(InteractiveItemStyles.ITEM_RADIUS)
            .backgroundColor(this.getNavItemBackground(item.id))
            .onHover((isHover: boolean) => {
              this.hoveredNavId = isHover ? item.id : ''
            })
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.activeNavId = item.id
                return
              }
              if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.activeNavId = ''
              }
            })
            .onClick(() => {
              this.activeNavId = ''
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
            .width(InteractiveItemStyles.ICON_SIZE)
            .height(InteractiveItemStyles.ICON_SIZE)
            .fillColor(this.getThemeModeIconColor())
            .draggable(false)
        }
        .width(InteractiveItemStyles.ICON_TILE_SIZE)
        .height(InteractiveItemStyles.ICON_TILE_SIZE)
        .borderRadius(InteractiveItemStyles.ICON_TILE_RADIUS)
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
      .height(InteractiveItemStyles.ITEM_HEIGHT)
      .id('sidebar-theme-toggle')
      .padding({
        left: InteractiveItemStyles.ITEM_HORIZONTAL_PADDING_START,
        right: InteractiveItemStyles.ITEM_HORIZONTAL_PADDING_END
      })
      .borderRadius(InteractiveItemStyles.ITEM_RADIUS)
      .backgroundColor(InteractiveItemStyles.getMenuItemBackground(this.currentTheme, this.themeToggleHovered, this.themeTogglePressed))
      .onHover((isHover: boolean) => {
        this.themeToggleHovered = isHover
      })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.themeTogglePressed = true
          return
        }
        if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.themeTogglePressed = false
        }
      })
      .onClick(() => {
        this.themeTogglePressed = false
        ThemeManager.getInstance().toggleTheme()
      })
    }
    .width(AppStyles.SIDEBAR_WIDTH)
    .height('100%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
  }
}
