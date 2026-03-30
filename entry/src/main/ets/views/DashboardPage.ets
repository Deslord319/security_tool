import { common } from '@kit.AbilityKit'
import { AppColors, AppStyles } from '../constants/AppConstants'
import { DashboardStrings } from '../constants/modules/DashboardStrings'
import { MetricSummaryCard } from '../components/MetricSummaryCard'
import { ToolCard } from '../components/ToolCard'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { DashboardModuleCardState, DashboardQuickEntryState } from '../models/DashboardModels'
import { DashboardViewModel } from '../viewmodels/DashboardViewModel'

@Component
export struct DashboardPage {
  onNavigate: (route: string) => void = () => {}
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  @State viewModel: DashboardViewModel = new DashboardViewModel()
  @State titleEnterOpacity: number = 0
  @State titleEnterOffset: number = 20
  @State moduleEnterOpacity: number[] = [0, 0, 0, 0]
  @State moduleEnterOffset: number[] = [18, 18, 18, 18]
  @State moduleEnterScale: number[] = [0.97, 0.97, 0.97, 0.97]
  @State sectionTitleEnterOpacity: number = 0
  @State sectionTitleEnterOffset: number = 16
  @State quickEnterOpacity: number[] = [0, 0, 0]
  @State quickEnterOffset: number[] = [18, 18, 18]
  @State quickEnterScale: number[] = [0.97, 0.97, 0.97]
  private enterTimerIds: number[] = []
  private initialized: boolean = false

  aboutToAppear(): void {
    void this.initializePage()
  }

  onPageShow(): void {
    void this.viewModel.refreshStaticStatuses()
  }

  aboutToDisappear(): void {
    this.viewModel.destroy()
    this.initialized = false
    this.clearEnterTimers()
  }

  private async initializePage(): Promise<void> {
    if (!this.initialized) {
      let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
      await this.viewModel.initialize(context)
      this.initialized = true
    } else {
      await this.viewModel.refreshAll()
    }
    this.playEnterAnimation()
  }

  private resetEnterState(): void {
    this.titleEnterOpacity = 0
    this.titleEnterOffset = 20
    this.moduleEnterOpacity = [0, 0, 0, 0]
    this.moduleEnterOffset = [18, 18, 18, 18]
    this.moduleEnterScale = [0.97, 0.97, 0.97, 0.97]
    this.sectionTitleEnterOpacity = 0
    this.sectionTitleEnterOffset = 16
    this.quickEnterOpacity = [0, 0, 0]
    this.quickEnterOffset = [18, 18, 18]
    this.quickEnterScale = [0.97, 0.97, 0.97]
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

    for (let index = 0; index < 4; index++) {
      this.scheduleEnter(140 + index * 70, () => {
        let nextOpacity = [...this.moduleEnterOpacity]
        let nextOffset = [...this.moduleEnterOffset]
        let nextScale = [...this.moduleEnterScale]
        nextOpacity[index] = 1
        nextOffset[index] = 0
        nextScale[index] = 1
        this.moduleEnterOpacity = nextOpacity
        this.moduleEnterOffset = nextOffset
        this.moduleEnterScale = nextScale
      })
    }

    this.scheduleEnter(450, () => {
      this.sectionTitleEnterOpacity = 1
      this.sectionTitleEnterOffset = 0
    })

    for (let index = 0; index < 3; index++) {
      this.scheduleEnter(520 + index * 70, () => {
        let nextOpacity = [...this.quickEnterOpacity]
        let nextOffset = [...this.quickEnterOffset]
        let nextScale = [...this.quickEnterScale]
        nextOpacity[index] = 1
        nextOffset[index] = 0
        nextScale[index] = 1
        this.quickEnterOpacity = nextOpacity
        this.quickEnterOffset = nextOffset
        this.quickEnterScale = nextScale
      })
    }
  }

  build() {
    Scroll() {
      Column({ space: 22 }) {
        Column({ space: 4 }) {
          Text(DashboardStrings.pageTitle)
            .fontSize(AppStyles.FONT_SIZE_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

          Text(DashboardStrings.pageSubtitle)
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .opacity(this.titleEnterOpacity)
        .translate({ y: this.titleEnterOffset })

        GridRow({ columns: 4, gutter: 16 }) {
          ForEach(this.viewModel.moduleCards, (card: DashboardModuleCardState, index: number) => {
            GridCol() {
              MetricSummaryCard({
                title: card.title,
                primaryText: card.primaryText,
                secondaryText: card.secondaryText,
                statusText: card.statusText,
                statusKind: card.statusKind,
                icon: card.icon,
                accentStart: card.accentStart,
                accentEnd: card.accentEnd,
                clickable: card.clickable,
                onPress: () => {
                  if (card.route) {
                    this.onNavigate(card.route)
                  }
                }
              })
            }
            .opacity(this.moduleEnterOpacity[index] ?? 1)
            .translate({ y: this.moduleEnterOffset[index] ?? 0 })
            .scale({ x: this.moduleEnterScale[index] ?? 1, y: this.moduleEnterScale[index] ?? 1 })
          })
        }
        .width('100%')

        Text('更多功能')
          .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(this.sectionTitleEnterOpacity * AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          .translate({ y: this.sectionTitleEnterOffset })
          .width('100%')

        GridRow({ columns: 3, gutter: 16 }) {
          ForEach(this.viewModel.quickEntries, (entry: DashboardQuickEntryState, index: number) => {
            GridCol() {
              ToolCard({
                label: entry.title,
                icon: entry.icon,
                gradientStart: entry.accentStart,
                gradientEnd: entry.accentEnd,
                onPress: () => { this.onNavigate(entry.route) }
              })
            }
            .opacity(this.quickEnterOpacity[index] ?? 1)
            .translate({ y: this.quickEnterOffset[index] ?? 0 })
            .scale({ x: this.quickEnterScale[index] ?? 1, y: this.quickEnterScale[index] ?? 1 })
          })
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
}
