import { AppColors, AppStyles, Routes } from '../constants/AppConstants'
import { StatCard } from '../components/StatCard'
import { ToolCard } from '../components/ToolCard'
import { LogStorageService } from '../services/LogStorageService'
import { LogRuntimeCollectorService } from '../services/LogRuntimeCollectorService'
import { LogAuditService } from '../services/LogAuditService'
import { EnterpriseAdminService } from '../services/EnterpriseAdminService'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'

const TAG = 'DashboardPage'

@Component
export struct DashboardPage {
  @Prop firewallEnabled: boolean = false
  onNavigate: (route: string) => void = () => {}
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  @State todayAuditCount: number = 0
  @State blockedAuditCount: number = 0
  @State totalLogCount: number = 0
  @State adminActivated: boolean = false
  @State collectorRunning: boolean = false
  @State logSubscribed: boolean = false
  @State subscribeModeLabel: string = 'None'
  private refreshTimerId: number = -1
  private readonly REFRESH_INTERVAL_MS: number = 3000

  aboutToAppear(): void {
    this.refreshLogStats()
    this.refreshHealthStatus()
    this.startRefreshTimer()
  }

  onPageShow(): void {
    this.refreshLogStats()
    this.refreshHealthStatus()
  }

  aboutToDisappear(): void {
    if (this.refreshTimerId >= 0) {
      clearInterval(this.refreshTimerId)
      this.refreshTimerId = -1
    }
  }

  startRefreshTimer(): void {
    if (this.refreshTimerId >= 0) {
      return
    }
    this.refreshTimerId = setInterval(() => {
      this.refreshLogStats()
      this.refreshHealthStatus()
    }, this.REFRESH_INTERVAL_MS)
  }

  async refreshLogStats(): Promise<void> {
    try {
      let stats = LogStorageService.getStatistics()
      this.todayAuditCount = stats.todayCount
      this.blockedAuditCount = stats.blockedCount
      this.totalLogCount = stats.totalCount
    } catch (err) {
      hilog.error(0x0000, TAG, `refreshLogStats failed: ${JSON.stringify(err)}`)
    }
  }

  refreshHealthStatus(): void {
    let adminState = EnterpriseAdminService.probeActivation()
    this.adminActivated = adminState.activated
    let runtimeStatus = LogRuntimeCollectorService.getStatus()
    this.collectorRunning = runtimeStatus.running
    this.logSubscribed = runtimeStatus.subscribed
    let mode = LogAuditService.getSubscribeMode()
    if (mode === 'client') {
      this.subscribeModeLabel = 'Client'
    } else if (mode === 'legacy') {
      this.subscribeModeLabel = 'Legacy'
    } else {
      this.subscribeModeLabel = 'None'
    }
  }

  build() {
    Scroll() {
      Column({ space: 20 }) {
        Column({ space: 4 }) {
          Text('安全总览')
            .fontSize(AppStyles.FONT_SIZE_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

          Text('HarmonyOS 安全管理中心，提供企业级设备安全管控能力。')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Row({ space: 10 }) {
          this.healthTag('管理员', this.adminActivated ? '已激活' : '未激活', this.adminActivated)
          this.healthTag('采集器', this.collectorRunning ? '运行中' : '未运行', this.collectorRunning)
          this.healthTag('日志订阅', this.logSubscribed ? '正常' : '异常', this.logSubscribed)
          this.healthTag('订阅模式', this.subscribeModeLabel, this.subscribeModeLabel !== 'None')
        }
        .width('100%')

        GridRow({ columns: 4, gutter: 16 }) {
          GridCol() {
            StatCard({
              label: '防火墙状态',
              value: this.firewallEnabled ? '已开启' : '已关闭',
              gradientStart: '#0A84FF',
              gradientEnd: '#00C6FF',
              icon: $r('app.media.firewall')
            })
          }

          GridCol() {
            StatCard({
              label: '今日审计事件',
              value: this.todayAuditCount.toString(),
              gradientStart: '#34C759',
              gradientEnd: '#30D158',
              icon: $r('app.media.log')
            })
          }

          GridCol() {
            StatCard({
              label: '已阻止事件',
              value: this.blockedAuditCount.toString(),
              gradientStart: '#5856D6',
              gradientEnd: '#AF52DE',
              icon: $r('app.media.alert')
            })
          }

          GridCol() {
            StatCard({
              label: '日志总量',
              value: this.totalLogCount.toString(),
              gradientStart: '#FF9500',
              gradientEnd: '#FFCC00',
              icon: $r('app.media.folder')
            })
          }
        }
        .width('100%')

        Text('快捷功能')
          .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

        GridRow({ columns: 3, gutter: 16 }) {
          GridCol() {
            ToolCard({
              label: '防火墙管理',
              icon: $r('app.media.firewall'),
              gradientStart: '#0A84FF',
              gradientEnd: '#00C6FF',
              onPress: () => { this.onNavigate(Routes.FIREWALL) }
            })
          }

          GridCol() {
            ToolCard({
              label: '日志管理',
              icon: $r('app.media.log'),
              gradientStart: '#34C759',
              gradientEnd: '#30D158',
              onPress: () => { this.onNavigate(Routes.LOG_MANAGE) }
            })
          }

          GridCol() {
            ToolCard({
              label: '外设管理',
              icon: $r('app.media.peripheral'),
              gradientStart: '#5856D6',
              gradientEnd: '#AF52DE',
              onPress: () => { this.onNavigate(Routes.PERIPHERAL_MANAGE) }
            })
          }

          GridCol() {
            ToolCard({
              label: '身份鉴别',
              icon: $r('app.media.identity'),
              gradientStart: '#FF9500',
              gradientEnd: '#FFCC00',
              onPress: () => { this.onNavigate(Routes.IDENTITY) }
            })
          }

          GridCol() {
            ToolCard({
              label: '防火墙规则',
              icon: $r('app.media.rules'),
              gradientStart: '#FF3B30',
              gradientEnd: '#FF6B6B',
              onPress: () => { this.onNavigate(Routes.FIREWALL_RULES) }
            })
          }

          GridCol() {
            ToolCard({
              label: '工具设置',
              icon: $r('app.media.settings'),
              gradientStart: '#8E8E93',
              gradientEnd: '#AEAEB2',
              onPress: () => { this.onNavigate(Routes.TOOL_SETTINGS) }
            })
          }
        }
        .width('100%')
      }
      .padding({ left: 32, right: 32, top: 16, bottom: 24 })
      .width('100%')
    }
    .align(Alignment.Top)
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }

  @Builder
  healthTag(label: string, value: string, ok: boolean) {
    Row({ space: 6 }) {
      Circle({ width: 6, height: 6 }).fill(ok ? AppColors.SUCCESS : AppColors.WARNING)
      Text(`${label} ${value}`)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(ok ? AppColors.getColors(this.currentTheme).TAG_GREEN_TEXT : AppColors.getColors(this.currentTheme).TAG_ORANGE_TEXT)
    }
    .padding({ left: 8, right: 8, top: 6, bottom: 6 })
    .backgroundColor(ok ? AppColors.getColors(this.currentTheme).TAG_GREEN_BG : AppColors.getColors(this.currentTheme).TAG_ORANGE_BG)
    .borderRadius(AppStyles.RADIUS_SM)
  }
}
