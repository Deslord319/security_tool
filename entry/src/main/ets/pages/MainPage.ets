import { LogUtils } from '../utils/LogUtils'
import { SideBar } from '../components/SideBar'
import { AboutDialogContent, ThemeMenuPopup } from '../components/ThemeMenuPopup'
import { DashboardPage } from '../views/dashboard/overview/DashboardPage'
import { FirewallPage } from '../views/firewall/overview/FirewallPage'
import { FirewallRulesPage } from '../views/firewall/rule-management/FirewallRulesPage'
import { PeripheralPage } from '../views/peripheral/overview/PeripheralPage'
import { IdentityPage } from '../views/identity/settings/IdentityPage'
import { ToolSettingsPage } from '../views/tool-settings/system-settings/ToolSettingsPage'
import { HelpFeedbackPage } from '../views/help-feedback/overview/HelpFeedbackPage'
import { LogManagePage } from '../views/log-manage/overview/LogManagePage'
import { AppColors, AppStyles, InteractiveItemStyles } from '../constants/AppConstants'
import { RouteIds } from '../constants/RouteIds'
import { ThemeMode, ThemeOption } from '../theme/ThemeColors'
import { ThemeManager } from '../theme/ThemeManager'

import { common, ConfigurationConstant } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { PeripheralDevicePolicyRepository } from '../services/peripheral/device-policy/PeripheralDevicePolicyRepository'
import { PeripheralTraceRepository } from '../services/peripheral/connection-record/PeripheralTraceRepository'
import { PeripheralConnectionRecordBluetoothAclConsumer } from '../services/peripheral/connection-record/peripheral_connection_record_bluetooth_acl_consumer'
import { PeripheralConnectionRecordPipelineImpl } from '../services/peripheral/connection-record/peripheral_connection_record_pipeline'
import { PeripheralConnectionRecordRuntimeProducerAdapter } from '../services/peripheral/connection-record/peripheral_connection_record_runtime_producer_adapter'
import { PeripheralConnectionRecordUsbConsumer } from '../services/peripheral/connection-record/peripheral_connection_record_usb_consumer'
import { FirewallService } from '../services/firewall/policy/FirewallService'
import { FirewallPresetMode } from '../models/DataModels'
import { FirewallModeService } from '../services/firewall/mode-control/FirewallModeService'
import { LogCollectorService } from '../services/log-manage/collector/LogCollectorService'

const UI_TEST_ROUTE_KEY = 'ui_test_route'
const TAG = 'MainPage'

@Entry
@ComponentV2
struct MainPage {
  @Local currentPage: string = AppStorage.get<string>(UI_TEST_ROUTE_KEY) ?? RouteIds.DASHBOARD
  @Local firewallEnabled: boolean = false
  @Local firewallPresetMode: FirewallPresetMode = 'custom'
  @Local showMenu: boolean = false
  @Local logManageMounted: boolean = true
  @Local pageEnterOpacity: number = 1
  @Local pageEnterOffset: number = 0
  @Local menuTriggerHovered: boolean = false
  @Local currentTheme: ThemeMode = ThemeManager.getInstance().getCurrentTheme()
  @Local currentThemeOption: ThemeOption = ThemeManager.getInstance().getCurrentOption()
  private aboutDialogController?: CustomDialogController
  private runtimeInitialized: boolean = false
  private runtimeInitInProgress: boolean = false
  private readonly themeListener: () => void = () => {
    this.syncThemeState()
    this.syncDecorButtonStyle()
  }
  private readonly connectionRecordProducer: PeripheralConnectionRecordRuntimeProducerAdapter =
    new PeripheralConnectionRecordRuntimeProducerAdapter()
  private readonly connectionRecordPipeline: PeripheralConnectionRecordPipelineImpl =
    new PeripheralConnectionRecordPipelineImpl(this.connectionRecordProducer, [
      new PeripheralConnectionRecordUsbConsumer(),
      new PeripheralConnectionRecordBluetoothAclConsumer()
    ])

  aboutToAppear(): void {
    ThemeManager.getInstance().subscribe(this.themeListener)
    this.syncThemeState()
    this.applyUiTestRouteOverride()
    this.loadFirewallState().catch((err: Object) => {
      LogUtils.error(TAG, `loadFirewallState in aboutToAppear failed: ${JSON.stringify(err)}`)
    })
    this.ensureRuntimeServices().catch((err: Object) => {
      LogUtils.error(TAG, `ensureRuntimeServices in aboutToAppear failed: ${JSON.stringify(err)}`)
    })
    this.syncDecorButtonStyle()
  }

  onPageShow(): void {
    this.syncThemeState()
    this.applyUiTestRouteOverride()
    this.loadFirewallState().catch((err: Object) => {
      LogUtils.error(TAG, `loadFirewallState in onPageShow failed: ${JSON.stringify(err)}`)
    })
    this.ensureRuntimeServices().catch((err: Object) => {
      LogUtils.error(TAG, `ensureRuntimeServices in onPageShow failed: ${JSON.stringify(err)}`)
    })
    this.syncDecorButtonStyle()
  }

  private syncThemeState(): void {
    this.currentTheme = ThemeManager.getInstance().getCurrentTheme()
    this.currentThemeOption = ThemeManager.getInstance().getCurrentOption()
  }

  aboutToDisappear(): void {
    ThemeManager.getInstance().unsubscribe(this.themeListener)
  }

  private applyUiTestRouteOverride(): void {
    const route = AppStorage.get<string>(UI_TEST_ROUTE_KEY) ?? ''
    if (route.length === 0) {
      return
    }
    switch (route) {
      case RouteIds.DASHBOARD:
      case RouteIds.FIREWALL:
      case RouteIds.FIREWALL_RULES:
      case RouteIds.LOG_MANAGE:
      case RouteIds.PERIPHERAL_MANAGE:
      case RouteIds.IDENTITY:
      case RouteIds.TOOL_SETTINGS:
      case RouteIds.HELP_FEEDBACK:
        this.setCurrentPage(route)
        break
      default:
        break
    }
    AppStorage.setOrCreate<string>(UI_TEST_ROUTE_KEY, '')
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
        LogUtils.warn(TAG,
          'setDecorButtonStyle skipped for theme=%{public}s: %{public}s',
          this.currentTheme, JSON.stringify(err))
      }
    }).catch((err: Error) => {
      LogUtils.warn(TAG,
        'getLastWindow failed, skip decor button style sync for theme=%{public}s: %{public}s',
        this.currentTheme, JSON.stringify(err))
    })
  }

  private async loadFirewallState(): Promise<void> {
    let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    await FirewallModeService.initialize(context)
    let policy = await FirewallService.getFirewallPolicy()
    if (policy === null) {
      LogUtils.warn(TAG, 'skip firewall state sync because getFirewallPolicy returned null')
      return
    }

    this.firewallEnabled = policy.isOpen
    this.firewallPresetMode = await FirewallModeService.getCurrentMode(context)
  }

  private async ensureRuntimeServices(): Promise<void> {
    if (!this.runtimeInitialized) {
      await this.initRuntimeServices()
      if (!this.runtimeInitialized) {
        LogUtils.warn(TAG, 'runtime services not initialized, skip start')
        return
      }
    }

    let status = LogCollectorService.getStatus()
    if (!status.running) {
      let collectorStarted = await LogCollectorService.start()
      LogUtils.info(TAG, `ensureRuntimeServices collector start result: started=${collectorStarted.success}, code=${collectorStarted.code}`)
      if (!collectorStarted.success) {
        LogUtils.warn(TAG, `LogCollectorService restart failed: ${collectorStarted.code}`)
      }
    }

    let runtimeStatus = this.connectionRecordProducer.getStatus()
    if (!runtimeStatus.running) {
      let runtimeStarted = await this.connectionRecordPipeline.start()
      let latestStatus = this.connectionRecordProducer.getStatus()
      LogUtils.info(TAG,
        `ensureRuntimeServices peripheral runtime start result: started=${runtimeStarted}, usb=${latestStatus.capabilities.usbRuntimeEvents}, bluetooth=${latestStatus.capabilities.bluetoothRuntimeEvents}, reason=${latestStatus.capabilities.degradedReason ?? 'none'}`
      )
      if (!runtimeStarted) {
        LogUtils.warn(TAG, 'connection record runtime start failed')
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
      let collectorInited = await LogCollectorService.init(context)
      if (!collectorInited.success) {
        LogUtils.error(TAG, `LogCollectorService init failed: ${collectorInited.code}`)
        return
      }

      let traceRepoInited = await this.connectionRecordPipeline.bindContext(context)
      if (!traceRepoInited) {
        LogUtils.error(TAG, 'connection record pipeline bindContext failed')
        return
      }
      await PeripheralTraceRepository.configure(180, 200000)

      let devicePolicyInited = await PeripheralDevicePolicyRepository.init(context)
      if (!devicePolicyInited) {
        LogUtils.error(TAG, 'PeripheralDevicePolicyRepository init failed')
        return
      }

      let producerAttached = await this.connectionRecordPipeline.attachProducer(this.connectionRecordProducer)
      if (!producerAttached) {
        LogUtils.error(TAG, 'connection record pipeline attachProducer failed')
        return
      }
      LogUtils.info(TAG, 'initRuntimeServices success')

      this.runtimeInitialized = true
    } catch (err) {
      this.runtimeInitialized = false
      LogUtils.error(TAG, `initRuntimeServices failed: ${JSON.stringify(err)}`)
    } finally {
      this.runtimeInitInProgress = false
    }
  }

  private setCurrentPage(page: string): void {
    this.currentPage = page
    this.handlePageRouteChange()
  }

  private handlePageRouteChange(): void {
    if (this.currentPage === RouteIds.LOG_MANAGE) {
      this.logManageMounted = false
      setTimeout(() => {
        if (this.currentPage === RouteIds.LOG_MANAGE) {
          this.logManageMounted = true
        }
      }, 0)
    } else {
      this.logManageMounted = true
    }
    this.pageEnterOpacity = 0.76
    this.pageEnterOffset = this.currentPage === RouteIds.DASHBOARD ? 18 : 10
    animateTo({
      duration: 320,
      curve: Curve.Friction
    }, () => {
      this.pageEnterOpacity = 1
      this.pageEnterOffset = 0
    })
  }

  private async handleThemeToggle(): Promise<void> {
    await ThemeManager.getInstance().toggleTheme()
    this.syncThemeState()
    this.syncDecorButtonStyle()
  }

  private async handleThemeOptionSelect(option: ThemeOption): Promise<void> {
    await ThemeManager.getInstance().setOption(option)
    this.syncThemeState()
    this.syncDecorButtonStyle()
  }

  private async switchFirewallMode(mode: FirewallPresetMode): Promise<boolean> {
    let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    let result = await FirewallModeService.switchMode(context, mode)
    if (result.success) {
      this.firewallPresetMode = mode
      return true
    }
    return false
  }

  private openAboutDialog(): void {
    this.closeAboutDialog()
    try {
      this.aboutDialogController = new CustomDialogController({
        builder: AboutDialogContent({
          controller: this.aboutDialogController,
          currentTheme: this.currentTheme,
          onConfirm: () => {
            this.closeAboutDialog()
          }
        }),
        alignment: DialogAlignment.Center,
        autoCancel: false,
        customStyle: true,
        isModal: true,
        maskColor: AppColors.OVERLAY_BACKGROUND,
        cancel: () => {
          this.aboutDialogController = undefined
        }
      })
      this.aboutDialogController.open()
    } catch (err) {
      LogUtils.warn(TAG, `openAboutDialog failed: ${JSON.stringify(err)}`)
      this.aboutDialogController = undefined
    }
  }

  private closeAboutDialog(): void {
    try {
      this.aboutDialogController?.close()
    } catch (err) {
      LogUtils.warn(TAG, `closeAboutDialog failed: ${JSON.stringify(err)}`)
    } finally {
      this.aboutDialogController = undefined
    }
  }

  @Builder
  private buildDashboardRoute() {
    Column() {
      DashboardPage({
        currentTheme: this.currentTheme,
        onNavigate: (route: string) => {
          this.setCurrentPage(route)
        }
      })
    }
    .id('route-page-dashboard')
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildFirewallRoute() {
    Column() {
      FirewallPage({
        firewallEnabled: this.firewallEnabled,
        currentMode: this.firewallPresetMode,
        currentTheme: this.currentTheme,
        onFirewallToggle: (enabled: boolean) => {
          this.firewallEnabled = enabled
        },
        onModeChange: async (mode: FirewallPresetMode): Promise<boolean> => this.switchFirewallMode(mode),
        onBack: () => {
          this.setCurrentPage(RouteIds.DASHBOARD)
        },
        onNavigateToRules: () => {
          this.setCurrentPage(RouteIds.FIREWALL_RULES)
        }
      })
    }
    .id('route-page-firewall')
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildFirewallRulesRoute() {
    Column() {
      FirewallRulesPage({
        currentMode: this.firewallPresetMode,
        currentTheme: this.currentTheme,
        onBack: () => {
          this.setCurrentPage(RouteIds.FIREWALL)
        }
      })
    }
    .id('route-page-firewall-rules')
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildLogManageRoute() {
    Column() {
      if (this.logManageMounted) {
        LogManagePage({
          currentTheme: this.currentTheme,
          onBack: () => {
            this.setCurrentPage(RouteIds.DASHBOARD)
          }
        })
      } else {
        Column()
          .width('100%')
          .height('100%')
      }
    }
    .id('route-page-log-manage')
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildPeripheralRoute() {
    Column() {
      PeripheralPage({
        currentTheme: this.currentTheme,
        onBack: () => {
          this.setCurrentPage(RouteIds.DASHBOARD)
        }
      })
    }
    .id('route-page-peripheral-manage')
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildIdentityRoute() {
    Column() {
      IdentityPage({
        currentTheme: this.currentTheme,
        onBack: () => {
          this.setCurrentPage(RouteIds.DASHBOARD)
        }
      })
    }
    .id('route-page-identity')
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildToolSettingsRoute() {
    Column() {
      ToolSettingsPage({
        currentTheme: this.currentTheme,
        onBack: () => {
          this.setCurrentPage(RouteIds.DASHBOARD)
        }
      })
    }
    .id('route-page-tool-settings')
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildHelpFeedbackRoute() {
    Column() {
      HelpFeedbackPage({
        currentTheme: this.currentTheme,
        onBack: () => {
          this.setCurrentPage(RouteIds.DASHBOARD)
        }
      })
    }
    .id('route-page-help-feedback')
    .width('100%')
    .height('100%')
  }

  @Builder
  private currentRoutePage() {
    if (this.currentPage === RouteIds.DASHBOARD) {
      this.buildDashboardRoute()
    } else if (this.currentPage === RouteIds.FIREWALL) {
      this.buildFirewallRoute()
    } else if (this.currentPage === RouteIds.FIREWALL_RULES) {
      this.buildFirewallRulesRoute()
    } else if (this.currentPage === RouteIds.LOG_MANAGE) {
      this.buildLogManageRoute()
    } else if (this.currentPage === RouteIds.PERIPHERAL_MANAGE) {
      this.buildPeripheralRoute()
    } else if (this.currentPage === RouteIds.IDENTITY) {
      this.buildIdentityRoute()
    } else if (this.currentPage === RouteIds.TOOL_SETTINGS) {
      this.buildToolSettingsRoute()
    } else if (this.currentPage === RouteIds.HELP_FEEDBACK) {
      this.buildHelpFeedbackRoute()
    } else {
      this.buildDashboardRoute()
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Row() {
        SideBar({
          selectedId: this.currentPage,
          currentTheme: this.currentTheme,
          onItemSelect: (id: string) => {
            this.setCurrentPage(id)
          },
          onToggleTheme: () => {
            void this.handleThemeToggle()
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
            .backgroundColor(InteractiveItemStyles.getMenuItemBackground(this.currentTheme, this.menuTriggerHovered))
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
            this.currentRoutePage()
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
            currentTheme: this.currentTheme,
            currentOption: this.currentThemeOption,
            onDismiss: () => {
              this.showMenu = false
            },
            onNavigate: (route: string) => {
              this.setCurrentPage(route)
            },
            onSelectOption: (option: ThemeOption) => {
              void this.handleThemeOptionSelect(option)
            },
            onOpenAbout: () => {
              this.openAboutDialog()
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
