import { SideBar } from '../components/SideBar'
import { ThemeMenuPopup } from '../components/ThemeMenuPopup'
import { DashboardPage } from '../views/DashboardPage'
import { FirewallPage } from '../views/FirewallPage'
import { FirewallRulesPage } from '../views/FirewallRulesPage'
import { PeripheralPage } from '../views/PeripheralPage'
import { IdentityPage } from '../views/IdentityPage'
import { ToolSettingsPage } from '../views/ToolSettingsPage'
import { PlaceholderPage } from '../views/PlaceholderPage'
import { Routes, AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { hilog } from '@kit.PerformanceAnalysisKit'

@Entry
@Component
struct MainPage {
  @State currentPage: string = Routes.DASHBOARD
  @State @Watch('onFirewallStatusChange') firewallEnabled: boolean = false
  @State showMenu: boolean = false
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  aboutToAppear(): void {
    hilog.info(0x0000, 'testTag', '[DIAG] MainPage aboutToAppear, currentTheme=%{public}s, AppStorage=%{public}s',
      this.currentTheme, AppStorage.get<string>(STORAGE_KEY_THEME) ?? 'undefined')
  }

  onFirewallStatusChange() {
    // 防火墙状态变更时可在此处理
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      // 主内容
      Row() {
        // 左侧导航栏
        SideBar({
          selectedId: this.currentPage,
          onItemSelect: (id: string) => {
            this.currentPage = id
          }
        })

        // 分割线
        Divider()
          .vertical(true)
          .color(AppColors.getColors(this.currentTheme).BORDER)
          .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

        // 右侧内容区
        Column() {
          // 顶部标题栏
          Row() {
            Text(this.getPageTitle())
              .fontSize(AppStyles.FONT_SIZE_TITLE)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

            Blank()

            // 三点菜单按钮
            Button() {
              Text('⋮')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
            }
            .type(ButtonType.Normal)
            .width(36)
            .height(36)
            .borderRadius(AppStyles.RADIUS_MD)
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.showMenu = !this.showMenu
            })
          }
          .width('100%')
          .height(56)
          .padding({ left: AppStyles.PADDING_LG, right: 140 })
          .alignItems(VerticalAlign.Center)

          // 页面内容
          Column() {
            if (this.currentPage === Routes.DASHBOARD) {
              DashboardPage({
                firewallEnabled: this.firewallEnabled,
                onNavigate: (route: string) => {
                  this.currentPage = route
                }
              })
            } else if (this.currentPage === Routes.FIREWALL) {
              FirewallPage({
                firewallEnabled: this.firewallEnabled,
                onFirewallToggle: (enabled: boolean) => {
                  this.firewallEnabled = enabled
                },
                onNavigateToRules: (filterType?: number) => {
                  this.currentPage = Routes.FIREWALL_RULES
                }
              })
            } else if (this.currentPage === Routes.FIREWALL_RULES) {
              FirewallRulesPage({
                onBack: () => {
                  this.currentPage = Routes.FIREWALL
                }
              })
            } else if (this.currentPage === Routes.LOG_MANAGE) {
              PlaceholderPage({ title: '日志管理' })
            } else if (this.currentPage === Routes.PERIPHERAL_MANAGE) {
              PeripheralPage()
            } else if (this.currentPage === Routes.IDENTITY) {
              IdentityPage()
            } else if (this.currentPage === Routes.TOOL_SETTINGS) {
              ToolSettingsPage()
            }
          }
          .layoutWeight(1)
        }
        .layoutWeight(1)
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)

      // 菜单遮罩层
      if (this.showMenu) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.showMenu = false
          })
      }

      // 下拉菜单
      if (this.showMenu) {
        Column() {
          ThemeMenuPopup({
            showMenu: $showMenu,
            onNavigate: (route: string) => {
              this.currentPage = route
            }
          })
        }
        .margin({ top: 56, right: 140 })
      }
    }
    .width('100%')
    .height('100%')
  }

  getPageTitle(): string {
    switch (this.currentPage) {
      case Routes.DASHBOARD:
        return '安全总览'
      case Routes.FIREWALL:
        return '防火墙'
      case Routes.FIREWALL_RULES:
        return '防火墙规则'
      case Routes.LOG_MANAGE:
        return '日志管理'
      case Routes.PERIPHERAL_MANAGE:
        return '外设管理'
      case Routes.IDENTITY:
        return '身份鉴别'
      case Routes.TOOL_SETTINGS:
        return '工具设置'
      default:
        return '安全管理中心'
    }
  }
}
