import { AppColors, AppStyles, Routes } from '../constants/AppConstants'
import { StatCard } from '../components/StatCard'
import { ToolCard } from '../components/ToolCard'

@Component
export struct DashboardPage {
  @Prop firewallEnabled: boolean = false
  onNavigate: (route: string) => void = () => {}

  build() {
    Scroll() {
      Column({ space: 24 }) {
        // 页面标题
        Column({ space: 4 }) {
          Text('安全总览')
            .fontSize(AppStyles.FONT_SIZE_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TEXT_PRIMARY)
            .opacity(AppColors.TEXT_PRIMARY_OPACITY)
          Text('HarmonyOS 安全管理中心 — 企业级设备安全管控平台')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.TEXT_PRIMARY)
            .opacity(AppColors.TEXT_TERTIARY_OPACITY)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        // 统计卡片区域 - 4列网格
        GridRow({ columns: 4, gutter: 16 }) {
          GridCol() {
            StatCard({
              label: '防火墙状态',
              value: this.firewallEnabled ? '已开启' : '已关闭',
              gradientStart: '#0A84FF',
              gradientEnd: '#00C6FF',
              iconText: '防'
            })
          }

          GridCol() {
            StatCard({
              label: '今日审计事件',
              value: '—',
              gradientStart: '#34C759',
              gradientEnd: '#30D158',
              iconText: '日'
            })
          }

          GridCol() {
            StatCard({
              label: '已连接外设',
              value: '—',
              gradientStart: '#5856D6',
              gradientEnd: '#AF52DE',
              iconText: '外'
            })
          }

          GridCol() {
            StatCard({
              label: '身份策略状态',
              value: '—',
              gradientStart: '#FF9500',
              gradientEnd: '#FFCC00',
              iconText: '身'
            })
          }
        }
        .width('100%')

        // 快捷功能区标题
        Text('快捷功能')
          .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .opacity(AppColors.TEXT_PRIMARY_OPACITY)

        // 快捷功能卡片 - 6个，3列2行
        GridRow({ columns: 3, gutter: 16 }) {
          GridCol() {
            ToolCard({
              label: '防火墙管理',
              iconText: '防',
              gradientStart: '#0A84FF',
              gradientEnd: '#00C6FF',
              onPress: () => { this.onNavigate(Routes.FIREWALL) }
            })
          }

          GridCol() {
            ToolCard({
              label: '日志管理',
              iconText: '日',
              gradientStart: '#34C759',
              gradientEnd: '#30D158',
              onPress: () => { this.onNavigate(Routes.LOG_MANAGE) }
            })
          }

          GridCol() {
            ToolCard({
              label: '外设管理',
              iconText: '外',
              gradientStart: '#5856D6',
              gradientEnd: '#AF52DE',
              onPress: () => { this.onNavigate(Routes.PERIPHERAL_MANAGE) }
            })
          }

          GridCol() {
            ToolCard({
              label: '身份鉴别',
              iconText: '身',
              gradientStart: '#FF9500',
              gradientEnd: '#FFCC00',
              onPress: () => { this.onNavigate(Routes.IDENTITY) }
            })
          }

          GridCol() {
            ToolCard({
              label: '防火墙规则',
              iconText: '规',
              gradientStart: '#FF3B30',
              gradientEnd: '#FF6B6B',
              onPress: () => { this.onNavigate(Routes.FIREWALL_RULES) }
            })
          }

          GridCol() {
            ToolCard({
              label: '工具设置',
              iconText: '设',
              gradientStart: '#8E8E93',
              gradientEnd: '#AEAEB2',
              onPress: () => { this.onNavigate(Routes.TOOL_SETTINGS) }
            })
          }
        }
        .width('100%')
      }
      .padding(AppStyles.PADDING_LG)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .backgroundColor(AppColors.BG_PAGE)
  }
}
