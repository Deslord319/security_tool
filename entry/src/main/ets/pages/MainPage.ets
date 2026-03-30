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
import { Routes, AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { common, ConfigurationConstant } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { LogStorageService } from '../services/LogStorageService'
import { LogRuntimeCollectorService } from '../services/LogRuntimeCollectorService'
import { PeripheralTraceRepository } from '../services/PeripheralTraceRepository'
import { PeripheralRuntimeEventService } from '../services/PeripheralRuntimeEventService'
import { FirewallService } from '../services/FirewallService'
import { FirewallPresetMode } from '../models/DataModels'
import { FirewallModeService } from '../services/FirewallModeService'

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
  @StorageLink(STORAGE_KEY_THEME) @Watch('onThemeChange') currentTheme: ThemeMode = ThemeMode.LIGHT
  private runtimeInitialized: boolean = false
  private runtimeInitInProgress: boolean = false

  aboutToAppear(): void {
    this.applyUiTestRouteOverride()
    this.loadFirewallState().catch((err: Object) => {
      hilog.error(0x0000, 'testTag', `loadFirewallState in aboutToAppear failed: ${JSON.stringify(err)}`)
    })
    this.ensureRuntimeServices().catch((err: Object) => {
      hilog.error(0x0000, 'testTag', `ensureRuntimeServices in aboutToAppear failed: ${JSON.stringify(err)}`)
    })
    this.syncDecorButtonStyle()
  }

  private applyUiTestRouteOverride(): void {
    const route = AppStorage.get<string>(UI_TEST_ROUTE_KEY) ?? ''
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
    AppStorage.setOrCreate<string>(UI_TEST_ROUTE_KEY, '')
  }

  onPageShow(): void {
    this.applyUiTestRouteOverride()
    this.loadFirewallState().catch((err: Object) => {
      hilog.error(0x0000, 'testTag', `loadFirewallState in onPageShow failed: ${JSON.stringify(err)}`)
    })
    this.ensureRuntimeServices().catch((err: Object) => {
      hilog.error(0x0000, 'testTag', `ensureRuntimeServices in onPageShow failed: ${JSON.stringify(err)}`)
    })
    this.syncDecorButtonStyle()
  }

  onThemeChange(): void {
    this.syncDecorButtonStyle()
  }

  private syncDecorButtonStyle(): void {
    let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    let decorButtonStyle: window.DecorButtonStyle = {
      colorMode: this.currentTheme === ThemeMode.DARK
        ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
        : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
    }

    window.getLastWindow(context).then((mainWindow: window.Window) => {
      try {
        mainWindow.setDecorButtonStyle(decorButtonStyle)
      } catch (err) {
        hilog.warn(0x0000, 'testTag',
          'setDecorButtonStyle skipped for theme=%{public}s: %{public}s',
          this.currentTheme, JSON.stringify(err))
      }
    }).catch((err: Error) => {
      hilog.warn(0x0000, 'testTag',
        'getLastWindow failed, skip decor button style sync for theme=%{public}s: %{public}s',
        this.currentTheme, JSON.stringify(err))
    })
  }

  private async loadFirewallState(): Promise<void> {
    let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    await FirewallModeService.initialize(context)
    let policy = await FirewallService.getFirewallPolicy()
    if (policy === null) {
      hilog.warn(0x0000, 'testTag', 'skip firewall state sync because getFirewallPolicy returned null')
      return
    }

    this.firewallEnabled = policy.isOpen
    this.firewallPresetMode = await FirewallModeService.getCurrentMode(context)
  }

  private async ensureRuntimeServices(): Promise<void> {
    if (!this.runtimeInitialized) {
      await this.initRuntimeServices()
      if (!this.runtimeInitialized) {
        hilog.warn(0x0000, 'testTag', 'runtime services not initialized, skip start')
        return
      }
    }

    let status = LogRuntimeCollectorService.getStatus()
    if (!status.running) {
      let collectorStarted = await LogRuntimeCollectorService.start()
      if (!collectorStarted) {
        hilog.warn(0x0000, 'testTag', 'LogRuntimeCollectorService restart failed')
      }
    }

    let runtimeStatus = PeripheralRuntimeEventService.getStatus()
    if (!runtimeStatus.running) {
      let runtimeStarted = await PeripheralRuntimeEventService.start()
      if (!runtimeStarted) {
        hilog.warn(0x0000, 'testTag', 'PeripheralRuntimeEventService start failed')
      }
    }
  }

  private async initRuntimeServices(): Promise<void> {
    if (this.runtimeInitialized || this.runtimeInitInProgress) {
      return
    }
    this.runtimeInitInProgress = true

    try {
      let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
      let storageOk = await LogStorageService.init(context)
      if (!storageOk) {
        hilog.error(0x0000, 'testTag', 'LogStorageService init failed')
        return
      }

      let collectorInited = await LogRuntimeCollectorService.init(context)
      if (!collectorInited) {
        hilog.error(0x0000, 'testTag', 'LogRuntimeCollectorService init failed')
        return
      }

      let traceRepoInited = await PeripheralTraceRepository.init(context)
      if (!traceRepoInited) {
        hilog.error(0x0000, 'testTag', 'PeripheralTraceRepository init failed')
        return
      }
      await PeripheralTraceRepository.configure(180, 200000)

      let runtimeCollectorInited = await PeripheralRuntimeEventService.init(context)
      if (!runtimeCollectorInited) {
        hilog.error(0x0000, 'testTag', 'PeripheralRuntimeEventService init failed')
        return
      }

      this.runtimeInitialized = true
    } catch (err) {
      this.runtimeInitialized = false
      hilog.error(0x0000, 'testTag', `initRuntimeServices failed: ${JSON.stringify(err)}`)
    } finally {
      this.runtimeInitInProgress = false
    }
  }

  onFirewallStatusChange() {
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
      Row() {
        SideBar({
          selectedId: this.currentPage,
          onItemSelect: (id: string) => {
            this.currentPage = id
          }
        })

        Divider()
          .vertical(true)
          .color(AppColors.getColors(this.currentTheme).BORDER)
          .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

        Column() {
          Row() {
            Blank()

            Button() {
              Image($r('app.media.menu_vertical_light'))
                .width(18)
                .height(18)
                .fillColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .draggable(false)
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
          .backgroundColor(this.currentTheme === ThemeMode.DARK ? AppColors.getColors(this.currentTheme).BG_COMPONENT : Color.Transparent)

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
                  onModeChange: async (mode: FirewallPresetMode): Promise<boolean> => {
                    let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
                    let result = await FirewallModeService.switchMode(context, mode)
                    if (result.success) {
                      this.firewallPresetMode = mode
                      return true
                    }
                    return false
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
                  currentMode: this.firewallPresetMode,
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

      if (this.showMenu) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.showMenu = false
          })
      }

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
