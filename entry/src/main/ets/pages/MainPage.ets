import { SideBar } from '../components/SideBar'
import { DashboardPage } from '../views/DashboardPage'
import { FirewallPage } from '../views/FirewallPage'
import { FirewallRulesPage } from '../views/FirewallRulesPage'
import { PlaceholderPage } from '../views/PlaceholderPage'
import { Routes } from '../constants/AppConstants'
import { AppColors } from '../constants/AppConstants'

@Entry
@Component
struct MainPage {
  @State currentPage: string = Routes.DASHBOARD
  @State @Watch('onFirewallStatusChange') firewallEnabled: boolean = false

  onFirewallStatusChange() {
    // 防火墙状态变更时可在此处理
  }

  build() {
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
        .color(AppColors.BORDER)
        .opacity(AppColors.BORDER_OPACITY)

      // 右侧内容区
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
          PlaceholderPage({ title: '外设管理' })
        } else if (this.currentPage === Routes.IDENTITY) {
          PlaceholderPage({ title: '身份鉴别' })
        } else if (this.currentPage === Routes.TOOL_SETTINGS) {
          PlaceholderPage({ title: '工具设置' })
        }
      }
      .layoutWeight(1)
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PAGE)
  }
}
