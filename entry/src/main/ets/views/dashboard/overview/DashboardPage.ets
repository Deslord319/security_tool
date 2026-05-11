import { common } from '@kit.AbilityKit'
import { AppColors, AppStyles } from '../../../constants/AppConstants'
import { ModuleText } from '../../../constants/StringCatalog'
import { DashboardPageStrings } from '../../../constants/modules/DashboardStrings'
import { MetricSummaryCard } from '../../../components/MetricSummaryCard'
import { ToolCard } from '../../../components/ToolCard'
import { ThemeMode } from '../../../theme/ThemeColors'
import { DashboardModuleCardState, DashboardQuickEntryState } from '../../../models/DashboardModels'
import { DashboardViewModel } from '../../../viewmodels/dashboard/overview/DashboardViewModel'

@ComponentV2
export struct DashboardPage {
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Event onNavigate: (route: string) => void = () => {}
  @Local viewModel: DashboardViewModel = new DashboardViewModel()
  @Local titleEnterOpacity: number = 0
  @Local titleEnterOffset: number = 20
  @Local moduleEnterOpacity: number[] = []
  @Local moduleEnterOffset: number[] = []
  @Local sectionTitleEnterOpacity: number = 0
  @Local sectionTitleEnterOffset: number = 16
  @Local quickEnterOpacity: number[] = []
  @Local quickEnterOffset: number[] = []
  private enterTimerIds: number[] = []
  private initialized: boolean = false

  aboutToAppear(): void {
    this.initializePage()
  }

  onPageShow(): void {
    this.viewModel.refreshStaticStatuses()
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
    this.moduleEnterOpacity = this.buildAnimationValues(this.viewModel.moduleCards.length, 0)
    this.moduleEnterOffset = this.buildAnimationValues(this.viewModel.moduleCards.length, 18)
    this.sectionTitleEnterOpacity = 0
    this.sectionTitleEnterOffset = 16
    this.quickEnterOpacity = this.buildAnimationValues(this.viewModel.quickEntries.length, 0)
    this.quickEnterOffset = this.buildAnimationValues(this.viewModel.quickEntries.length, 18)
  }

  private buildAnimationValues(count: number, value: number): number[] {
    let values: number[] = []
    for (let index = 0; index < count; index++) {
      values.push(value)
    }
    return values
  }

  private clearEnterTimers(): void {
    this.enterTimerIds.forEach((timerId: number) => clearTimeout(timerId))
    this.enterTimerIds = []
  }

  private scheduleEnter(delayMs: number, update: () => void): void {
    let timerId = setTimeout(() => {
      this.getUIContext().animateTo({
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

    for (let index = 0; index < this.viewModel.moduleCards.length; index++) {
      this.scheduleEnter(140 + index * 70, () => {
        let nextOpacity = [...this.moduleEnterOpacity]
        let nextOffset = [...this.moduleEnterOffset]
        nextOpacity[index] = 1
        nextOffset[index] = 0
        this.moduleEnterOpacity = nextOpacity
        this.moduleEnterOffset = nextOffset
      })
    }

    this.scheduleEnter(450, () => {
      this.sectionTitleEnterOpacity = 1
      this.sectionTitleEnterOffset = 0
    })

    for (let index = 0; index < this.viewModel.quickEntries.length; index++) {
      this.scheduleEnter(520 + index * 55, () => {
        let nextOpacity = [...this.quickEnterOpacity]
        let nextOffset = [...this.quickEnterOffset]
        nextOpacity[index] = 1
        nextOffset[index] = 0
        this.quickEnterOpacity = nextOpacity
        this.quickEnterOffset = nextOffset
      })
    }
  }

  build() {
    Scroll() {
      Column({ space: 22 }) {
        Column({ space: 4 }) {
          Text(ModuleText.DASHBOARD)
            .fontSize(AppStyles.FONT_SIZE_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

          Text(DashboardPageStrings.SUBTITLE)
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .opacity(this.titleEnterOpacity)
        .translate({ y: this.titleEnterOffset })

        GridRow({ columns: 4, gutter: 22 }) {
          ForEach(this.viewModel.moduleCards, (card: DashboardModuleCardState, index: number) => {
            GridCol() {
              MetricSummaryCard({
                title: card.title,
                primaryText: card.primaryText,
                secondaryText: card.secondaryText,
                icon: card.icon,
                accentStart: card.accentStart,
                accentEnd: card.accentEnd,
                cardHeight: 108,
                iconTileSize: 58,
                iconTileRadius: 18,
                iconSize: 34,
                primaryFontSize: 24,
                secondaryMaxLines: 3,
                clickable: false,
                hoverable: true,
                currentTheme: this.currentTheme
              })
            }
            .opacity(this.moduleEnterOpacity[index] ?? 1)
            .translate({ y: this.moduleEnterOffset[index] ?? 0 })
          })
        }
        .width('100%')

        Text(DashboardPageStrings.QUICK_ACTIONS_TITLE)
          .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(this.sectionTitleEnterOpacity * AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          .translate({ y: this.sectionTitleEnterOffset })
          .width('100%')
          .textAlign(TextAlign.Center)

        Column() {
          GridRow({ columns: 3, gutter: 22 }) {
            ForEach(this.viewModel.quickEntries, (entry: DashboardQuickEntryState, index: number) => {
              GridCol() {
                ToolCard({
                  label: entry.title,
                  icon: entry.icon,
                  gradientStart: entry.accentStart,
                  gradientEnd: entry.accentEnd,
                  currentTheme: this.currentTheme,
                  onPress: () => { this.onNavigate(entry.route) }
                })
              }
              .opacity(this.quickEnterOpacity[index] ?? 1)
              .translate({ y: this.quickEnterOffset[index] ?? 0 })
            })
          }
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .padding({ left: 48, right: 48, top: 16, bottom: 24 })
      .width('100%')
    }
    .align(Alignment.Top)
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }
}
