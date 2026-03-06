import { AppColors, AppStyles, NavItem, NAV_ITEMS } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { ThemeManager, STORAGE_KEY_THEME } from '../theme/ThemeManager'

@Component
export struct SideBar {
  @Prop selectedId: string = 'dashboard'
  onItemSelect: (id: string) => void = () => {}
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  build() {
    Column() {
      // Logo 区域
      Row({ space: 8 }) {
        Text('S')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .width(28)
          .height(28)
          .borderRadius(8)
          .backgroundColor(AppColors.BRAND_PRIMARY)
        Text('安全管理中心')
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

      // 导航列表
      List({ space: 4 }) {
        ForEach(NAV_ITEMS, (item: NavItem) => {
          ListItem() {
            Row({ space: 12 }) {
              // 使用文字图标
              Text(item.iconText)
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.selectedId === item.id ? Color.White : AppColors.BRAND_PRIMARY)
                .textAlign(TextAlign.Center)
                .width(28)
                .height(28)
                .borderRadius(6)
                .backgroundColor(this.selectedId === item.id ? 'rgba(255,255,255,0.2)' :
                  (this.currentTheme === ThemeMode.DARK ? 'rgba(10,132,255,0.2)' : 'rgba(10,132,255,0.1)'))
              Text(item.label)
                .fontSize(AppStyles.FONT_SIZE_BODY)
                .fontColor(this.selectedId === item.id ? Color.White : AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(this.selectedId === item.id ? 1 : AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
            }
            .width('100%')
            .height(44)
            .id(`sidebar-nav-${item.id}`)
            .padding({ left: 12, right: 12 })
            .borderRadius(AppStyles.RADIUS_MD)
            .backgroundColor(this.selectedId === item.id ? AppColors.BRAND_PRIMARY : Color.Transparent)
            .onClick(() => {
              this.onItemSelect(item.id)
            })
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 8, right: 8, top: 8 })

      // 底部主题切换按钮
      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      Row({ space: 12 }) {
        Text(this.currentTheme === ThemeMode.DARK ? '浅' : '深')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.currentTheme === ThemeMode.DARK ? '#FFD60A' : '#5856D6')
          .textAlign(TextAlign.Center)
          .width(28)
          .height(28)
          .borderRadius(6)
          .backgroundColor(this.currentTheme === ThemeMode.DARK ? 'rgba(255,214,10,0.15)' : 'rgba(88,86,214,0.1)')
        Text(this.currentTheme === ThemeMode.DARK ? '浅色模式' : '深色模式')
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .id(this.currentTheme === ThemeMode.DARK ? 'theme-mode-dark' : 'theme-mode-light')
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
      }
      .width('100%')
      .height(48)
      .id('sidebar-theme-toggle')
      .padding({ left: 20, right: 20 })
      .onClick(() => {
        ThemeManager.getInstance().toggleTheme()
      })
    }
    .width(AppStyles.SIDEBAR_WIDTH)
    .height('100%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
  }
}
