import { SideBar } from '../components/SideBar'
import { ThemeMenuPopup } from '../components/ThemeMenuPopup'
import { DashboardPage } from '../views/DashboardPage'
import { FirewallPage } from '../views/FirewallPage'
import { FirewallRulesPage } from '../views/FirewallRulesPage'
import { PeripheralPage } from '../views/PeripheralPage'
import { IdentityPage } from '../views/IdentityPage'
import { ToolSettingsPage } from '../views/ToolSettingsPage'
import { HelpFeedbackPage } from '../views/HelpFeedbackPage'
import { LogManagePage } from '../views/LogManagePage'
import { PlaceholderPage } from '../views/PlaceholderPage'
import { Routes, AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { common } from '@kit.AbilityKit'
import { LogStorageService } from '../services/LogStorageService'
import { LogRuntimeCollectorService } from '../services/LogRuntimeCollectorService'
import { PeripheralTraceRepository } from '../services/PeripheralTraceRepository'
import { PeripheralRuntimeEventService } from '../services/PeripheralRuntimeEventService'
import { FirewallPresetMode } from '../models/DataModels'

const UI_TEST_ROUTE_KEY = 'ui_test_route'

@Entry
@Component
struct MainPage {
  @State @Watch('onPageRouteChange') currentPage: string = AppStorage.get<string>(UI_TEST_ROUTE_KEY) ?? Routes.DASHBOARD
  @State @Watch('onFirewallStatusChange') firewallEnabled: boolean = false
  @State firewallPresetMode: FirewallPresetMode = 'custom'
  @State showMenu: boolean = false
  @State pageEnterOpacity: number = 1
  @State pageEnterOffset: number = 0
  @State menuTriggerHovered: boolean = false
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  private runtimeInitialized: boolean = false
  private runtimeInitInProgress: boolean = false

  aboutToAppear(): void {
    this.applyUiTestRouteOverride()
    hilog.info(0x0000, 'testTag', '[DIAG] MainPage aboutToAppear, currentTheme=%{public}s, AppStorage=%{public}s',
      this.currentTheme, AppStorage.get<string>(STORAGE_KEY_THEME) ?? 'undefined')
    this.ensureRuntimeServices().catch((err: Object) => {
      hilog.error(0x0000, 'testTag', `[DIAG] ensureRuntimeServices in aboutToAppear failed: ${JSON.stringify(err)}`)
    })
  }

  private applyUiTestRouteOverride(): void {
    const route = AppStorage.get<string>(UI_TEST_ROUTE_KEY) ?? ''
    hilog.info(0x0000, 'testTag', '[DIAG] applyUiTestRouteOverride route=%{public}s', route)
    if (route.length === 0) {
      return
    }
    switch (route) {
      case Routes.DASHBOARD:
      case Routes.FIREWALL:
      case Routes.FIREWALL_RULES:
      case Routes.LOG_MANAGE:
      case Routes.PERIPHERAL_MANAGE:
      case Routes.IDENTITY:
      case Routes.TOOL_SETTINGS:
      case Routes.HELP_FEEDBACK:
        this.currentPage = route
        break
      default:
        break
    }
    // Consume one-shot route override to avoid affecting manual navigation.
    AppStorage.setOrCreate<string>(UI_TEST_ROUTE_KEY, '')
  }

  onPageShow(): void {
    this.applyUiTestRouteOverride()
    this.ensureRuntimeServices().catch((err: Object) => {
      hilog.error(0x0000, 'testTag', `[DIAG] ensureRuntimeServices in onPageShow failed: ${JSON.stringify(err)}`)
    })
  }

  private async ensureRuntimeServices(): Promise<void> {
    if (!this.runtimeInitialized) {
      await this.initRuntimeServices()
      if (!this.runtimeInitialized) {
        hilog.warn(0x0000, 'testTag', '[DIAG] runtime services not initialized, skip start')
        return
      }
    }

    let status = LogRuntimeCollectorService.getStatus()
    if (!status.running) {
      let collectorStarted = await LogRuntimeCollectorService.start()
      if (!collectorStarted) {
        hilog.warn(0x0000, 'testTag', '[DIAG] LogRuntimeCollectorService restart failed')
      }
    }

    let runtimeStatus = PeripheralRuntimeEventService.getStatus()
    if (!runtimeStatus.running) {
      let runtimeStarted = await PeripheralRuntimeEventService.start()
      if (!runtimeStarted) {
        hilog.warn(0x0000, 'testTag', '[DIAG] PeripheralRuntimeEventService start failed')
      }
    }
  }

  private async initRuntimeServices(): Promise<void> {
    if (this.runtimeInitialized || this.runtimeInitInProgress) {
      return
    }
    this.runtimeInitInProgress = true

    try {
      let context = getContext(this) as common.UIAbilityContext
      let storageOk = await LogStorageService.init(context)
      if (!storageOk) {
        hilog.error(0x0000, 'testTag', '[DIAG] LogStorageService init failed')
        return
      }

      let collectorInited = await LogRuntimeCollectorService.init(context)
      if (!collectorInited) {
        hilog.error(0x0000, 'testTag', '[DIAG] LogRuntimeCollectorService init failed')
        return
      }

      let traceRepoInited = await PeripheralTraceRepository.init(context)
      if (!traceRepoInited) {
        hilog.error(0x0000, 'testTag', '[DIAG] PeripheralTraceRepository init failed')
        return
      }
      await PeripheralTraceRepository.configure(180, 200000)

      let runtimeCollectorInited = await PeripheralRuntimeEventService.init(context)
      if (!runtimeCollectorInited) {
        hilog.error(0x0000, 'testTag', '[DIAG] PeripheralRuntimeEventService init failed')
        return
      }

      this.runtimeInitialized = true
    } catch (err) {
      this.runtimeInitialized = false
      hilog.error(0x0000, 'testTag', `[DIAG] initRuntimeServices failed: ${JSON.stringify(err)}`)
    } finally {
      this.runtimeInitInProgress = false
    }
  }

  onFirewallStatusChange() {
    // 防火墙状态变更时可在此处理
  }

  onPageRouteChange(): void {
    this.pageEnterOpacity = 0.76
    this.pageEnterOffset = this.currentPage === Routes.DASHBOARD ? 18 : 10
    animateTo({
      duration: 320,
      curve: Curve.Friction
    }, () => {
      this.pageEnterOpacity = 1
      this.pageEnterOffset = 0
    })
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
            Blank()

            // 三点菜单按钮
            Button() {
              Image(this.currentTheme === ThemeMode.DARK
                ? $r('app.media.menu_vertical_dark')
                : $r('app.media.menu_vertical_light'))
                .width(18)
                .height(18)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
            }
            .type(ButtonType.Normal)
            .id('top-menu-trigger')
            .width(32)
            .height(32)
            .borderRadius(AppStyles.RADIUS_MD)
            .backgroundColor(this.menuTriggerHovered ?
              (this.currentTheme === ThemeMode.DARK ? AppColors.MENU_HOVER_DARK : AppColors.MENU_HOVER_LIGHT) :
              Color.Transparent)
            .onHover((isHover: boolean) => {
              this.menuTriggerHovered = isHover
            })
            .onClick(() => {
              this.showMenu = !this.showMenu
            })
          }
          .width('100%')
          .height(56)
          .padding({ left: AppStyles.PADDING_LG, right: 140 })
          .alignItems(VerticalAlign.Center)
          .backgroundColor(this.currentTheme === ThemeMode.DARK ? '#2C2C2E' : Color.Transparent)

          // 页面内容
          Column() {
            if (this.currentPage === Routes.DASHBOARD) {
              Column() {
                DashboardPage({
                  firewallEnabled: this.firewallEnabled,
                  onNavigate: (route: string) => {
                    this.currentPage = route
                  }
                })
              }
              .id('route-page-dashboard')
              .width('100%')
              .height('100%')
            } else if (this.currentPage === Routes.FIREWALL) {
              Column() {
                FirewallPage({
                  firewallEnabled: this.firewallEnabled,
                  currentMode: this.firewallPresetMode,
                  onFirewallToggle: (enabled: boolean) => {
                    this.firewallEnabled = enabled
                  },
                  onModeChange: (mode: FirewallPresetMode) => {
                    this.firewallPresetMode = mode
                  },
                  onBack: () => {
                    this.currentPage = Routes.DASHBOARD
                  },
                  onNavigateToRules: () => {
                    this.currentPage = Routes.FIREWALL_RULES
                  }
                })
              }
              .id('route-page-firewall')
              .width('100%')
              .height('100%')
            } else if (this.currentPage === Routes.FIREWALL_RULES) {
              Column() {
                FirewallRulesPage({
                  onBack: () => {
                    this.currentPage = Routes.FIREWALL
                  }
                })
              }
              .id('route-page-firewall-rules')
              .width('100%')
              .height('100%')
            } else if (this.currentPage === Routes.LOG_MANAGE) {
              Column() {
                LogManagePage({
                  onBack: () => {
                    this.currentPage = Routes.DASHBOARD
                  }
                })
              }
              .id('route-page-log-manage')
              .width('100%')
              .height('100%')
            } else if (this.currentPage === Routes.PERIPHERAL_MANAGE) {
              Column() {
                PeripheralPage({
                  onBack: () => {
                    this.currentPage = Routes.DASHBOARD
                  }
                })
              }
              .id('route-page-peripheral-manage')
              .width('100%')
              .height('100%')
            } else if (this.currentPage === Routes.IDENTITY) {
              Column() {
                IdentityPage({
                  onBack: () => {
                    this.currentPage = Routes.DASHBOARD
                  }
                })
              }
              .id('route-page-identity')
              .width('100%')
              .height('100%')
            } else if (this.currentPage === Routes.TOOL_SETTINGS) {
              Column() {
                ToolSettingsPage({
                  onBack: () => {
                    this.currentPage = Routes.DASHBOARD
                  }
                })
              }
              .id('route-page-tool-settings')
              .width('100%')
              .height('100%')
            } else if (this.currentPage === Routes.HELP_FEEDBACK) {
              Column() {
                HelpFeedbackPage({
                  onBack: () => {
                    this.currentPage = Routes.DASHBOARD
                  }
                })
              }
              .id('route-page-help-feedback')
              .width('100%')
              .height('100%')
            }
          }
          .layoutWeight(1)
          .opacity(this.pageEnterOpacity)
          .translate({ y: this.pageEnterOffset })
        }
        .layoutWeight(1)
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)

      if (this.currentTheme === ThemeMode.DARK) {
        Column()
          .id('theme-marker-dark')
          .width(1)
          .height(1)
          .opacity(0)
      } else {
        Column()
          .id('theme-marker-light')
          .width(1)
          .height(1)
          .opacity(0)
      }

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
}
