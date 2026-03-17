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
  @State subscribeModeLabel: string = '未订阅'
  @State titleEnterOpacity: number = 0
  @State titleEnterOffset: number = 20
  @State healthEnterOpacity: number = 0
  @State healthEnterOffset: number = 18
  @State sectionTitleEnterOpacity: number = 0
  @State sectionTitleEnterOffset: number = 16
  @State statEnterOpacity: number[] = [0, 0, 0, 0]
  @State statEnterOffset: number[] = [22, 22, 22, 22]
  @State statEnterScale: number[] = [0.96, 0.96, 0.96, 0.96]
  @State toolEnterOpacity: number[] = [0, 0, 0, 0, 0, 0]
  @State toolEnterOffset: number[] = [22, 22, 22, 22, 22, 22]
  @State toolEnterScale: number[] = [0.96, 0.96, 0.96, 0.96, 0.96, 0.96]
  private refreshTimerId: number = -1
  private enterTimerIds: number[] = []
  private readonly REFRESH_INTERVAL_MS: number = 3000

  aboutToAppear(): void {
    this.refreshLogStats()
    this.refreshHealthStatus()
    this.startRefreshTimer()
    this.playEnterAnimation()
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
    this.clearEnterTimers()
  }

  private resetEnterState(): void {
    this.titleEnterOpacity = 0
    this.titleEnterOffset = 20
    this.healthEnterOpacity = 0
    this.healthEnterOffset = 18
    this.sectionTitleEnterOpacity = 0
    this.sectionTitleEnterOffset = 16
    this.statEnterOpacity = [0, 0, 0, 0]
    this.statEnterOffset = [22, 22, 22, 22]
    this.statEnterScale = [0.96, 0.96, 0.96, 0.96]
    this.toolEnterOpacity = [0, 0, 0, 0, 0, 0]
    this.toolEnterOffset = [22, 22, 22, 22, 22, 22]
    this.toolEnterScale = [0.96, 0.96, 0.96, 0.96, 0.96, 0.96]
  }

  private clearEnterTimers(): void {
    this.enterTimerIds.forEach((timerId: number) => clearTimeout(timerId))
    this.enterTimerIds = []
  }

  private scheduleEnter(delayMs: number, update: () => void): void {
    let timerId = setTimeout(() => {
      animateTo({
        duration: 300,
        curve: Curve.Friction
      }, update)
    }, delayMs)
    this.enterTimerIds = [...this.enterTimerIds, timerId]
  }

  private playEnterAnimation(): void {
    this.clearEnterTimers()
    this.resetEnterState()

    this.scheduleEnter(40, () => {
      this.titleEnterOpacity = 1
      this.titleEnterOffset = 0
    })

    this.scheduleEnter(120, () => {
      this.healthEnterOpacity = 1
      this.healthEnterOffset = 0
    })

    for (let index = 0; index < 4; index++) {
      this.scheduleEnter(180 + index * 70, () => {
        let nextOpacity = [...this.statEnterOpacity]
        let nextOffset = [...this.statEnterOffset]
        let nextScale = [...this.statEnterScale]
        nextOpacity[index] = 1
        nextOffset[index] = 0
        nextScale[index] = 1
        this.statEnterOpacity = nextOpacity
        this.statEnterOffset = nextOffset
        this.statEnterScale = nextScale
      })
    }

    this.scheduleEnter(470, () => {
      this.sectionTitleEnterOpacity = 1
      this.sectionTitleEnterOffset = 0
    })

    for (let index = 0; index < 6; index++) {
      this.scheduleEnter(540 + index * 70, () => {
        let nextOpacity = [...this.toolEnterOpacity]
        let nextOffset = [...this.toolEnterOffset]
        let nextScale = [...this.toolEnterScale]
        nextOpacity[index] = 1
        nextOffset[index] = 0
        nextScale[index] = 1
        this.toolEnterOpacity = nextOpacity
        this.toolEnterOffset = nextOffset
        this.toolEnterScale = nextScale
      })
    }
  }

  private startRefreshTimer(): void {
    if (this.refreshTimerId >= 0) {
      return
    }
    this.refreshTimerId = setInterval(() => {
      this.refreshLogStats()
      this.refreshHealthStatus()
    }, this.REFRESH_INTERVAL_MS)
  }

  private async refreshLogStats(): Promise<void> {
    try {
      let stats = LogStorageService.getStatistics()
      this.todayAuditCount = stats.todayCount
      this.blockedAuditCount = stats.blockedCount
      this.totalLogCount = stats.totalCount
    } catch (err) {
      hilog.error(0x0000, TAG, `refreshLogStats failed: ${JSON.stringify(err)}`)
    }
  }

  private refreshHealthStatus(): void {
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
      this.subscribeModeLabel = '未订阅'
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
        .opacity(this.titleEnterOpacity)
        .translate({ y: this.titleEnterOffset })

        Row({ space: 10 }) {
          this.healthTag('管理员', this.adminActivated ? '已激活' : '未激活', this.adminActivated)
          this.healthTag('采集器', this.collectorRunning ? '运行中' : '未运行', this.collectorRunning)
          this.healthTag('订阅', this.logSubscribed ? '正常' : '异常', this.logSubscribed)
        }
        .width('100%')
        .opacity(this.healthEnterOpacity)
        .translate({ y: this.healthEnterOffset })

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
          .opacity(this.statEnterOpacity[0])
          .translate({ y: this.statEnterOffset[0] })
          .scale({ x: this.statEnterScale[0], y: this.statEnterScale[0] })

          GridCol() {
            StatCard({
              label: '今日审计事件',
              value: this.todayAuditCount.toString(),
              gradientStart: '#34C759',
              gradientEnd: '#30D158',
              icon: $r('app.media.log')
            })
          }
          .opacity(this.statEnterOpacity[1])
          .translate({ y: this.statEnterOffset[1] })
          .scale({ x: this.statEnterScale[1], y: this.statEnterScale[1] })

          GridCol() {
            StatCard({
              label: '已阻止事件',
              value: this.blockedAuditCount.toString(),
              gradientStart: '#5856D6',
              gradientEnd: '#AF52DE',
              icon: $r('app.media.alert')
            })
          }
          .opacity(this.statEnterOpacity[2])
          .translate({ y: this.statEnterOffset[2] })
          .scale({ x: this.statEnterScale[2], y: this.statEnterScale[2] })

          GridCol() {
            StatCard({
              label: '日志总量',
              value: this.totalLogCount.toString(),
              gradientStart: '#FF9500',
              gradientEnd: '#FFCC00',
              icon: $r('app.media.folder')
            })
          }
          .opacity(this.statEnterOpacity[3])
          .translate({ y: this.statEnterOffset[3] })
          .scale({ x: this.statEnterScale[3], y: this.statEnterScale[3] })
        }
        .width('100%')

        Text('快捷功能')
          .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(this.sectionTitleEnterOpacity * AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          .translate({ y: this.sectionTitleEnterOffset })

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
          .opacity(this.toolEnterOpacity[0])
          .translate({ y: this.toolEnterOffset[0] })
          .scale({ x: this.toolEnterScale[0], y: this.toolEnterScale[0] })

          GridCol() {
            ToolCard({
              label: '日志管理',
              icon: $r('app.media.log'),
              gradientStart: '#34C759',
              gradientEnd: '#30D158',
              onPress: () => { this.onNavigate(Routes.LOG_MANAGE) }
            })
          }
          .opacity(this.toolEnterOpacity[1])
          .translate({ y: this.toolEnterOffset[1] })
          .scale({ x: this.toolEnterScale[1], y: this.toolEnterScale[1] })

          GridCol() {
            ToolCard({
              label: '外设管理',
              icon: $r('app.media.peripheral'),
              gradientStart: '#5856D6',
              gradientEnd: '#AF52DE',
              onPress: () => { this.onNavigate(Routes.PERIPHERAL_MANAGE) }
            })
          }
          .opacity(this.toolEnterOpacity[2])
          .translate({ y: this.toolEnterOffset[2] })
          .scale({ x: this.toolEnterScale[2], y: this.toolEnterScale[2] })

          GridCol() {
            ToolCard({
              label: '身份鉴别',
              icon: $r('app.media.identity'),
              gradientStart: '#FF9500',
              gradientEnd: '#FFCC00',
              onPress: () => { this.onNavigate(Routes.IDENTITY) }
            })
          }
          .opacity(this.toolEnterOpacity[3])
          .translate({ y: this.toolEnterOffset[3] })
          .scale({ x: this.toolEnterScale[3], y: this.toolEnterScale[3] })

          GridCol() {
            ToolCard({
              label: '工具设置',
              icon: $r('app.media.settings'),
              gradientStart: '#0F766E',
              gradientEnd: '#14B8A6',
              onPress: () => { this.onNavigate(Routes.TOOL_SETTINGS) }
            })
          }
          .opacity(this.toolEnterOpacity[4])
          .translate({ y: this.toolEnterOffset[4] })
          .scale({ x: this.toolEnterScale[4], y: this.toolEnterScale[4] })

          GridCol() {
            ToolCard({
              label: '帮助与反馈',
              icon: $r('app.media.help'),
              gradientStart: '#FF3B30',
              gradientEnd: '#FF6B6B',
              onPress: () => { this.onNavigate(Routes.HELP_FEEDBACK) }
            })
          }
          .opacity(this.toolEnterOpacity[5])
          .translate({ y: this.toolEnterOffset[5] })
          .scale({ x: this.toolEnterScale[5], y: this.toolEnterScale[5] })
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
