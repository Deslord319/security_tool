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
      this.subscribeModeLabel = 'None'
    }
  }

  build() {
    Scroll() {
      Column({ space: 20 }) {
        Column({ space: 4 }) {
          Text('\u5b89\u5168\u603b\u89c8')
            .fontSize(AppStyles.FONT_SIZE_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

          Text('HarmonyOS \u5b89\u5168\u7ba1\u7406\u4e2d\u5fc3\uff0c\u63d0\u4f9b\u4f01\u4e1a\u7ea7\u8bbe\u5907\u5b89\u5168\u7ba1\u63a7\u80fd\u529b\u3002')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .opacity(this.titleEnterOpacity)
        .translate({ y: this.titleEnterOffset })

        Row({ space: 10 }) {
          this.healthTag('\u7ba1\u7406\u5458', this.adminActivated ? '\u5df2\u6fc0\u6d3b' : '\u672a\u6fc0\u6d3b', this.adminActivated)
          this.healthTag('\u91c7\u96c6\u5668', this.collectorRunning ? '\u8fd0\u884c\u4e2d' : '\u672a\u8fd0\u884c', this.collectorRunning)
          this.healthTag('\u65e5\u5fd7\u8ba2\u9605', this.logSubscribed ? '\u6b63\u5e38' : '\u5f02\u5e38', this.logSubscribed)
          this.healthTag('\u8ba2\u9605\u6a21\u5f0f', this.subscribeModeLabel, this.subscribeModeLabel !== 'None')
        }
        .width('100%')
        .opacity(this.healthEnterOpacity)
        .translate({ y: this.healthEnterOffset })

        GridRow({ columns: 4, gutter: 16 }) {
          GridCol() {
            StatCard({
              label: '\u9632\u706b\u5899\u72b6\u6001',
              value: this.firewallEnabled ? '\u5df2\u5f00\u542f' : '\u5df2\u5173\u95ed',
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
              label: '\u4eca\u65e5\u5ba1\u8ba1\u4e8b\u4ef6',
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
              label: '\u5df2\u963b\u6b62\u4e8b\u4ef6',
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
              label: '\u65e5\u5fd7\u603b\u91cf',
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

        Text('\u5feb\u6377\u529f\u80fd')
          .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(this.sectionTitleEnterOpacity * AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          .translate({ y: this.sectionTitleEnterOffset })

        GridRow({ columns: 3, gutter: 16 }) {
          GridCol() {
            ToolCard({
              label: '\u9632\u706b\u5899\u7ba1\u7406',
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
              label: '\u65e5\u5fd7\u7ba1\u7406',
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
              label: '\u5916\u8bbe\u7ba1\u7406',
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
              label: '\u8eab\u4efd\u9274\u522b',
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
              label: '\u9632\u706b\u5899\u89c4\u5219',
              icon: $r('app.media.rules'),
              gradientStart: '#FF3B30',
              gradientEnd: '#FF6B6B',
              onPress: () => { this.onNavigate(Routes.FIREWALL_RULES) }
            })
          }
          .opacity(this.toolEnterOpacity[4])
          .translate({ y: this.toolEnterOffset[4] })
          .scale({ x: this.toolEnterScale[4], y: this.toolEnterScale[4] })

          GridCol() {
            ToolCard({
              label: '\u5de5\u5177\u8bbe\u7f6e',
              icon: $r('app.media.settings'),
              gradientStart: '#8E8E93',
              gradientEnd: '#AEAEB2',
              onPress: () => { this.onNavigate(Routes.TOOL_SETTINGS) }
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
