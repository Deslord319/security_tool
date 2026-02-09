import { AppColors, AppStyles, NavItem, NAV_ITEMS } from '../constants/AppConstants'

@Component
export struct SideBar {
  @Prop selectedId: string = 'dashboard'
  onItemSelect: (id: string) => void = () => {}

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
          .fontColor(AppColors.TEXT_PRIMARY)
          .opacity(AppColors.TEXT_PRIMARY_OPACITY)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)

      Divider()
        .color(AppColors.BORDER)
        .opacity(AppColors.BORDER_OPACITY)

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
                .backgroundColor(this.selectedId === item.id ? 'rgba(255,255,255,0.2)' : 'rgba(10,132,255,0.1)')
              Text(item.label)
                .fontSize(AppStyles.FONT_SIZE_BODY)
                .fontColor(this.selectedId === item.id ? Color.White : AppColors.TEXT_PRIMARY)
                .opacity(this.selectedId === item.id ? 1 : AppColors.TEXT_SECONDARY_OPACITY)
            }
            .width('100%')
            .height(44)
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
    }
    .width(AppStyles.SIDEBAR_WIDTH)
    .height('100%')
    .backgroundColor(AppColors.BG_CARD)
  }
}
