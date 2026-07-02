import { LogUtils } from '../utils/LogUtils'
import { SideBar } from '../components/SideBar'
import { AboutDialogContent, ThemeMenuPopup } from '../components/ThemeMenuPopup'
import { DashboardPage } from '../views/dashboard/overview/DashboardPage'
import { FirewallPage } from '../views/firewall/overview/FirewallPage'
import { FirewallRulesPage } from '../views/firewall/rules/FirewallRulesPage'
import { PeripheralPage } from '../views/peripheral/overview/PeripheralPage'
import { IdentityPage } from '../views/identity/settings/IdentityPage'
import { ToolSettingsPage } from '../views/tool-settings/system-settings/ToolSettingsPage'
import { HelpFeedbackPage } from '../views/help-feedback/overview/HelpFeedbackPage'
import { LogManagePage } from '../views/log-manage/overview/LogManagePage'
import { PermissionPage } from '../views/permission-manage/overview/PermissionPage'
import { AppColors, AppStyles, InteractiveItemStyles } from '../constants/AppConstants'
import { AppResources } from '../constants/AppResources'
import { RouteIds } from '../constants/RouteIds'
import { ThemeMode, ThemeOption } from '../theme/ThemeColors'
import { ThemeManager } from '../theme/ThemeManager'
import { ApplicationRuntimeManager } from '../runtime/ApplicationRuntimeManager'

import { common, ConfigurationConstant } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { FirewallOverviewViewModel } from '../viewmodels/firewall/overview/FirewallOverviewViewModel'
import { FirewallRulesViewModel } from '../viewmodels/firewall/rules/FirewallRulesViewModel'
import { IdentitySettingsViewModel } from '../viewmodels/identity/settings/IdentitySettingsViewModel'
import { LogManageViewModel } from '../viewmodels/log-manage/overview/LogManageViewModel'
import { PeripheralViewModel } from '../viewmodels/peripheral/overview/PeripheralViewModel'
import { PermissionViewModel } from '../viewmodels/permission-manage/PermissionViewModel'
import { ToolSettingsViewModel } from '../viewmodels/tool-settings/system-settings/ToolSettingsViewModel'
import { ErrorLike } from '../types/LooseValueTypes'
import { AccountChangeEventBus, AccountChangeSubscription } from '../services/account/AccountChangeEventBus'
import { UserFirewallOption } from '../services/firewall/FirewallModels'
import { SystemUserProvider } from '../services/firewall/providers/SystemUserProvider'
import {
  rememberFirewallRoute,
  resolveNavigationRoute,
  resolveSidebarSelectedRoute
} from '../utils/RouteStateUtils'

const TAG = 'MainPage'

@Entry
@ComponentV2
struct MainPage {
  private readonly applicationRuntime: ApplicationRuntimeManager = ApplicationRuntimeManager.getInstance()
  @Local currentPage: string = RouteIds.DASHBOARD
  private lastFirewallRoute: string = RouteIds.FIREWALL
  @Local firewallOverviewViewModel: FirewallOverviewViewModel = new FirewallOverviewViewModel()
  @Local firewallRulesViewModel: FirewallRulesViewModel = new FirewallRulesViewModel()
  @Local identitySettingsViewModel: IdentitySettingsViewModel = this.applicationRuntime.getIdentitySettingsViewModel()
  @Local showMenu: boolean = false
  @Local logManageViewModel: LogManageViewModel = this.applicationRuntime.getLogManageViewModel()
  @Local peripheralViewModel: PeripheralViewModel = this.applicationRuntime.getPeripheralViewModel()
  @Local permissionViewModel: PermissionViewModel = this.applicationRuntime.getPermissionViewModel()
  @Local toolSettingsViewModel: ToolSettingsViewModel = this.applicationRuntime.getToolSettingsViewModel()
  @Local pageEnterOpacity: number = 1
  @Local pageEnterOffset: number = 0
  @Local menuTriggerHovered: boolean = false
  @Local currentTheme: ThemeMode = ThemeManager.getInstance().getCurrentTheme()
  @Local currentThemeOption: ThemeOption = ThemeManager.getInstance().getCurrentOption()
  private aboutDialogController?: CustomDialogController
  private initialRuntimeWarmupStarted: boolean = false
  private accountChangeSubscription: AccountChangeSubscription | null = null
  private readonly themeListener: () => void = () => {
    this.syncThemeState()
    this.syncDecorButtonStyle()
  }

  aboutToAppear(): void {
    this.createAccountChangeSubscriber()
    ThemeManager.getInstance().subscribe(this.themeListener)
    this.syncThemeState()
    this.syncDecorButtonStyle()
  }

  onPageShow(): void {
    this.handlePageActivated('onPageShow')
  }

  private syncThemeState(): void {
    this.currentTheme = ThemeManager.getInstance().getCurrentTheme()
    this.currentThemeOption = ThemeManager.getInstance().getCurrentOption()
  }

  aboutToDisappear(): void {
    AccountChangeEventBus.unsubscribe(this.accountChangeSubscription)
    this.accountChangeSubscription = null
    ThemeManager.getInstance().unsubscribe(this.themeListener)
  }

  private createAccountChangeSubscriber(): void {
    if (this.accountChangeSubscription) {
      return
    }
    AccountChangeEventBus.subscribe(async (): Promise<void> => {
      await this.handleAccountChangeEvent()
    }).then((subscription: AccountChangeSubscription | null) => {
      this.accountChangeSubscription = subscription
    }).catch((err: Error) => {
      LogUtils.warn(TAG, 'create account change subscriber failed: %{public}s', JSON.stringify(err))
    })
  }

  private async handleAccountChangeEvent(): Promise<void> {
    if (this.currentPage !== RouteIds.FIREWALL && this.currentPage !== RouteIds.FIREWALL_RULES) {
      return
    }
    let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    let users: UserFirewallOption[] = (await SystemUserProvider.loadAvailableUserIds()).users
    await this.loadFirewallState()
    if (this.currentPage === RouteIds.FIREWALL_RULES) {
      await this.firewallRulesViewModel.refreshForAccountChange(context, users)
    }
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
    if (!this.firewallOverviewViewModel.state.initialized) {
      await this.firewallOverviewViewModel.initialize(context)
      return
    }
    await this.firewallOverviewViewModel.refresh(context)
  }

  private handlePageActivated(source: 'onPageShow'): void {
    this.syncThemeState()
    this.requestFirewallStateIfNeeded(source)
    this.ensureRuntimeServicesForActiveRoute(source)
    this.syncDecorButtonStyle()
  }

  private setCurrentPage(page: string): void {
    this.lastFirewallRoute = rememberFirewallRoute(this.lastFirewallRoute, page)
    this.currentPage = page
    this.handlePageRouteChange()
  }

  private navigateToRoute(route: string): void {
    this.setCurrentPage(resolveNavigationRoute(route, this.lastFirewallRoute))
  }

  private handlePageRouteChange(): void {
    // Request an explicit refresh when navigating to the log manager page instead of forcing a remount.
    if (this.currentPage === RouteIds.LOG_MANAGE) {
      this.requestLogManageRefresh().catch((err: Error) => {
        LogUtils.warn(TAG, `requestLogManageRefresh failed: ${JSON.stringify(err)}`)
      })
    }
    this.requestFirewallStateIfNeeded('onPageShow')
    this.ensureRuntimeServicesForActiveRoute('onPageShow')
    this.pageEnterOpacity = 0.76
    this.pageEnterOffset = this.currentPage === RouteIds.DASHBOARD ? 18 : 10
    this.getUIContext().animateTo({
      duration: 320,
      curve: Curve.Friction
    }, () => {
      this.pageEnterOpacity = 1
      this.pageEnterOffset = 0
    })
  }

  private handleInitialDashboardAnimationComplete(): void {
    if (this.initialRuntimeWarmupStarted || this.currentPage !== RouteIds.DASHBOARD) {
      return
    }
    this.initialRuntimeWarmupStarted = true
    this.applicationRuntime.ensureRuntimeServices().catch((err: ErrorLike) => {
      LogUtils.error(TAG, `initial runtime warmup after dashboard animation failed: ${JSON.stringify(err)}`)
    })
  }

  // Ensure the shared LogManageViewModel is initialized/activated and refreshed when the user
  // navigates to the log page. This avoids relying on UI remounting behavior.
  private async requestLogManageRefresh(): Promise<void> {
    try {
      await this.applicationRuntime.refreshLogManageData()
    } catch (err) {
      LogUtils.warn(TAG, `requestLogManageRefresh failed: ${JSON.stringify(err)}`)
    }
  }

  private async handleThemeToggle(): Promise<void> {
    await ThemeManager.getInstance().toggleTheme()
  }

  private async handleThemeOptionSelect(option: ThemeOption): Promise<void> {
    await ThemeManager.getInstance().setOption(option)
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
          this.navigateToRoute(route)
        },
        onInitialEnterAnimationComplete: () => {
          this.handleInitialDashboardAnimationComplete()
        }
      })
    }
    .id('route-page-dashboard')
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildLogManageRoute() {
    Column() {
      LogManagePage({
        currentTheme: this.currentTheme,
        onBack: () => {
          this.setCurrentPage(RouteIds.DASHBOARD)
        },
        viewModel: this.logManageViewModel
      })
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
        viewModel: this.peripheralViewModel,
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
        viewModel: this.identitySettingsViewModel,
        onBack: () => {
          this.setCurrentPage(RouteIds.DASHBOARD)
        }
      })
    }
    .id('route-page-identity')
    .width('100%')
    .height('100%')
  }

  private requestFirewallStateIfNeeded(source: 'onPageShow'): void {
    if (this.currentPage !== RouteIds.FIREWALL && this.currentPage !== RouteIds.FIREWALL_RULES) {
      return
    }
    this.loadFirewallState().catch((err: ErrorLike) => {
      LogUtils.error(TAG, `loadFirewallState in ${source} failed: ${JSON.stringify(err)}`)
    })
  }

  private ensureRuntimeServicesForActiveRoute(source: 'onPageShow'): void {
    if (this.currentPage === RouteIds.LOG_MANAGE) {
      this.applicationRuntime.ensureLogRuntimeServices().catch((err: ErrorLike) => {
        LogUtils.error(TAG, `ensureLogRuntimeServices in ${source} failed: ${JSON.stringify(err)}`)
      })
      return
    }
    if (this.currentPage === RouteIds.PERIPHERAL_MANAGE) {
      this.applicationRuntime.ensurePeripheralRuntimeServices().catch((err: ErrorLike) => {
        LogUtils.error(TAG, `ensurePeripheralRuntimeServices in ${source} failed: ${JSON.stringify(err)}`)
      })
      return
    }
    if (this.currentPage === RouteIds.PERMISSION_MANAGE) {
      this.applicationRuntime.ensurePermissionRuntimeServices().catch((err: ErrorLike) => {
        LogUtils.error(TAG, `ensurePermissionRuntimeServices in ${source} failed: ${JSON.stringify(err)}`)
      })
      return
    }
    if (this.currentPage === RouteIds.IDENTITY) {
      this.applicationRuntime.ensureIdentityRuntimeServices().catch((err: ErrorLike) => {
        LogUtils.error(TAG, `ensureIdentityRuntimeServices in ${source} failed: ${JSON.stringify(err)}`)
      })
    }
  }

  @Builder
  private buildPermissionManageRoute() {
    Column() {
      PermissionPage({
        currentTheme: this.currentTheme,
        viewModel: this.permissionViewModel,
        onBack: () => {
          this.setCurrentPage(RouteIds.DASHBOARD)
        }
      })
    }
    .id('route-page-permission-manage')
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildToolSettingsRoute() {
    Column() {
      ToolSettingsPage({
        currentTheme: this.currentTheme,
        viewModel: this.toolSettingsViewModel,
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
      Column() {
        FirewallPage({
          overviewViewModel: this.firewallOverviewViewModel,
          currentTheme: this.currentTheme,
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
    } else if (this.currentPage === RouteIds.FIREWALL_RULES) {
      Column() {
        FirewallRulesPage({
          currentMode: this.firewallOverviewViewModel.state.currentMode,
          currentTheme: this.currentTheme,
          rulesViewModel: this.firewallRulesViewModel,
          onBack: () => {
            this.setCurrentPage(RouteIds.FIREWALL)
          }
        })
      }
      .id('route-page-firewall-rules')
      .width('100%')
      .height('100%')
    } else if (this.currentPage === RouteIds.LOG_MANAGE) {
      this.buildLogManageRoute()
    } else if (this.currentPage === RouteIds.PERIPHERAL_MANAGE) {
      this.buildPeripheralRoute()
    } else if (this.currentPage === RouteIds.PERMISSION_MANAGE) {
      this.buildPermissionManageRoute()
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
          selectedId: resolveSidebarSelectedRoute(this.currentPage),
          currentTheme: this.currentTheme,
          onItemSelect: (id: string) => {
            this.navigateToRoute(id)
          },
          onToggleTheme: () => {
            this.handleThemeToggle()
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
              Image(AppResources.MENU_VERTICAL_LIGHT_ICON)
                .width(18)
                .height(18)
                .fillColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .draggable(false)
            }
            .type(ButtonType.Normal)
            .id('top-menu-trigger')
            .width(AppStyles.TITLE_BAR_CONTROL_BACKGROUND_SIZE)
            .height(AppStyles.TITLE_BAR_CONTROL_BACKGROUND_SIZE)
            .translate({ y: AppStyles.TITLE_BAR_CONTROL_VERTICAL_OFFSET })
            .borderRadius(AppStyles.TITLE_BAR_CONTROL_BACKGROUND_RADIUS)
            .backgroundColor(InteractiveItemStyles.getMenuItemBackground(this.currentTheme, this.menuTriggerHovered))
            .onHover((isHover: boolean) => {
              this.menuTriggerHovered = isHover
            })
            .onClick(() => {
              this.showMenu = !this.showMenu
            })
          }
          .width('100%')
          .height(AppStyles.TOP_BAR_HEIGHT)
          .padding({ left: AppStyles.PADDING_LG, right: AppStyles.WINDOW_CONTROL_RESERVED_WIDTH })
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
        // Hidden marker used by E2E checks to verify the active theme without parsing colors.
        Column()
          .id('theme-marker-dark')
          .width(1)
          .height(1)
          .opacity(0)
      } else {
        // Hidden marker used by E2E checks to verify the active theme without parsing colors.
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
              this.navigateToRoute(route)
            },
            onSelectOption: (option: ThemeOption) => {
              this.handleThemeOptionSelect(option).catch((err: ErrorLike) => {
                LogUtils.warn(TAG, `handleThemeOptionSelect failed: ${JSON.stringify(err)}`)
              })
            },
            onOpenAbout: () => {
              this.openAboutDialog()
            }
          })
        }
        .margin({ top: AppStyles.TOP_BAR_HEIGHT, right: AppStyles.WINDOW_CONTROL_RESERVED_WIDTH })
      }
    }
    .width('100%')
    .height('100%')
  }
}
