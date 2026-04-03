import { LogUtils } from '../utils/LogUtils'
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
import { AppColors, AppStyles, InteractiveItemStyles } from '../constants/AppConstants'
import { RouteIds } from '../constants/RouteIds'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'

import { common, ConfigurationConstant } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { PeripheralDevicePolicyRepository } from '../services/PeripheralDevicePolicyRepository'
import { PeripheralTraceRepository } from '../services/PeripheralTraceRepository'
import { PeripheralConnectionRecordBluetoothAclConsumer } from '../services/peripheral/connection-record/peripheral_connection_record_bluetooth_acl_consumer'
import { PeripheralConnectionRecordPipelineImpl } from '../services/peripheral/connection-record/peripheral_connection_record_pipeline'
import { PeripheralConnectionRecordRuntimeProducerAdapter } from '../services/peripheral/connection-record/peripheral_connection_record_runtime_producer_adapter'
import { PeripheralConnectionRecordUsbConsumer } from '../services/peripheral/connection-record/peripheral_connection_record_usb_consumer'
import { FirewallService } from '../services/FirewallService'
import { FirewallPresetMode } from '../models/DataModels'
import { FirewallModeService } from '../services/FirewallModeService'
import { LogCollectorService } from '../services/log-manage/collector/LogCollectorService'

const UI_TEST_ROUTE_KEY = 'ui_test_route'

@Entry
@Component
struct MainPage {
  @State @Watch('onPageRouteChange') currentPage: string = AppStorage.get<string>(UI_TEST_ROUTE_KEY) ?? RouteIds.DASHBOARD
  @State @Watch('onFirewallStatusChange') firewallEnabled: boolean = false
  @State firewallPresetMode: FirewallPresetMode = 'custom'
  @State showMenu: boolean = false
  @State logManageMounted: boolean = true
  @State pageEnterOpacity: number = 1
  @State pageEnterOffset: number = 0
  @State menuTriggerHovered: boolean = false
  @StorageLink(STORAGE_KEY_THEME) @Watch('onThemeChange') currentTheme: ThemeMode = ThemeMode.LIGHT
  private runtimeInitialized: boolean = false
  private runtimeInitInProgress: boolean = false
  private readonly connectionRecordProducer: PeripheralConnectionRecordRuntimeProducerAdapter =
    new PeripheralConnectionRecordRuntimeProducerAdapter()
  private readonly connectionRecordPipeline: PeripheralConnectionRecordPipelineImpl =
    new PeripheralConnectionRecordPipelineImpl(this.connectionRecordProducer, [
      new PeripheralConnectionRecordUsbConsumer(),
      new PeripheralConnectionRecordBluetoothAclConsumer()
    ])

  aboutToAppear(): void {
    this.applyUiTestRouteOverride()
    this.loadFirewallState().catch((err: Object) => {
      LogUtils.error('testTag', `loadFirewallState in aboutToAppear failed: ${JSON.stringify(err)}`)
    })
    this.ensureRuntimeServices().catch((err: Object) => {
      LogUtils.error('testTag', `ensureRuntimeServices in aboutToAppear failed: ${JSON.stringify(err)}`)
    })
    this.syncDecorButtonStyle()
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
      LogUtils.error('testTag', `loadFirewallState in onPageShow failed: ${JSON.stringify(err)}`)
    })
    this.ensureRuntimeServices().catch((err: Object) => {
      LogUtils.error('testTag', `ensureRuntimeServices in onPageShow failed: ${JSON.stringify(err)}`)
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
        LogUtils.warn('testTag', 
          'setDecorButtonStyle skipped for theme=%{public}s: %{public}s',
          this.currentTheme, JSON.stringify(err))
      }
    }).catch((err: Error) => {
      LogUtils.warn('testTag', 
        'getLastWindow failed, skip decor button style sync for theme=%{public}s: %{public}s',
        this.currentTheme, JSON.stringify(err))
    })
  }

  private async loadFirewallState(): Promise<void> {
    let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    await FirewallModeService.initialize(context)
    let policy = await FirewallService.getFirewallPolicy()
    if (policy === null) {
      LogUtils.warn('testTag', 'skip firewall state sync because getFirewallPolicy returned null')
      return
    }

    this.firewallEnabled = policy.isOpen
    this.firewallPresetMode = await FirewallModeService.getCurrentMode(context)
  }

  private async ensureRuntimeServices(): Promise<void> {
    if (!this.runtimeInitialized) {
      await this.initRuntimeServices()
      if (!this.runtimeInitialized) {
        LogUtils.warn('testTag', 'runtime services not initialized, skip start')
        return
      }
    }

    let status = LogCollectorService.getStatus()
    if (!status.running) {
      let collectorStarted = await LogCollectorService.start()
      LogUtils.info('testTag', `ensureRuntimeServices collector start result: started=${collectorStarted.success}, code=${collectorStarted.code}`)
      if (!collectorStarted.success) {
        LogUtils.warn('testTag', `LogCollectorService restart failed: ${collectorStarted.code}`)
      }
    }

    let runtimeStatus = this.connectionRecordProducer.getStatus()
    if (!runtimeStatus.running) {
      let runtimeStarted = await this.connectionRecordPipeline.start()
      let latestStatus = this.connectionRecordProducer.getStatus()
      LogUtils.info('testTag',
        `ensureRuntimeServices peripheral runtime start result: started=${runtimeStarted}, usb=${latestStatus.capabilities.usbRuntimeEvents}, bluetooth=${latestStatus.capabilities.bluetoothRuntimeEvents}, reason=${latestStatus.capabilities.degradedReason ?? 'none'}`
      )
      if (!runtimeStarted) {
        LogUtils.warn('testTag', 'connection record runtime start failed')
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
        LogUtils.error('testTag', `LogCollectorService init failed: ${collectorInited.code}`)
        return
      }

      let traceRepoInited = await this.connectionRecordPipeline.bindContext(context)
      if (!traceRepoInited) {
        LogUtils.error('testTag', 'connection record pipeline bindContext failed')
        return
      }
      await PeripheralTraceRepository.configure(180, 200000)

      let devicePolicyInited = await PeripheralDevicePolicyRepository.init(context)
      if (!devicePolicyInited) {
        LogUtils.error('testTag', 'PeripheralDevicePolicyRepository init failed')
        return
      }

      let producerAttached = await this.connectionRecordPipeline.attachProducer(this.connectionRecordProducer)
      if (!producerAttached) {
        LogUtils.error('testTag', 'connection record pipeline attachProducer failed')
        return
      }
      LogUtils.info('testTag', 'initRuntimeServices success')

      this.runtimeInitialized = true
    } catch (err) {
      this.runtimeInitialized = false
      LogUtils.error('testTag', `initRuntimeServices failed: ${JSON.stringify(err)}`)
    } finally {
      this.runtimeInitInProgress = false
    }
  }

  onFirewallStatusChange() {
  }

  onPageRouteChange(): void {
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
            if (this.currentPage === RouteIds.DASHBOARD) {
              Column() {
                DashboardPage({
                  onNavigate: (route: string) => {
                    this.currentPage = route
                  }
                })
              }
              .id('route-page-dashboard')
              .width('100%')
              .height('100%')
            } else if (this.currentPage === RouteIds.FIREWALL) {
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
                    this.currentPage = RouteIds.DASHBOARD
                  },
                  onNavigateToRules: () => {
                    this.currentPage = RouteIds.FIREWALL_RULES
                  }
                })
              }
              .id('route-page-firewall')
              .width('100%')
              .height('100%')
            } else if (this.currentPage === RouteIds.FIREWALL_RULES) {
              Column() {
                FirewallRulesPage({
                  currentMode: this.firewallPresetMode,
                  onBack: () => {
                    this.currentPage = RouteIds.FIREWALL
                  }
                })
              }
              .id('route-page-firewall-rules')
              .width('100%')
              .height('100%')
            } else if (this.currentPage === RouteIds.LOG_MANAGE) {
              Column() {
                if (this.logManageMounted) {
                  LogManagePage({
                    currentTheme: this.currentTheme,
                    onBack: () => {
                      this.currentPage = RouteIds.DASHBOARD
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
            } else if (this.currentPage === RouteIds.PERIPHERAL_MANAGE) {
              Column() {
                PeripheralPage({
                  onBack: () => {
                    this.currentPage = RouteIds.DASHBOARD
                  }
                })
              }
              .id('route-page-peripheral-manage')
              .width('100%')
              .height('100%')
            } else if (this.currentPage === RouteIds.IDENTITY) {
              Column() {
                IdentityPage({
                  onBack: () => {
                    this.currentPage = RouteIds.DASHBOARD
                  }
                })
              }
              .id('route-page-identity')
              .width('100%')
              .height('100%')
            } else if (this.currentPage === RouteIds.TOOL_SETTINGS) {
              Column() {
                ToolSettingsPage({
                  onBack: () => {
                    this.currentPage = RouteIds.DASHBOARD
                  }
                })
              }
              .id('route-page-tool-settings')
              .width('100%')
              .height('100%')
            } else if (this.currentPage === RouteIds.HELP_FEEDBACK) {
              Column() {
                HelpFeedbackPage({
                  onBack: () => {
                    this.currentPage = RouteIds.DASHBOARD
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
