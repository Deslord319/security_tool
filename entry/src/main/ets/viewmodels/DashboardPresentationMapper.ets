import { AppColors, Routes } from '../constants/AppConstants'
import { DashboardStrings } from '../constants/modules/DashboardStrings'
import {
  DashboardAdminSnapshot,
  DashboardFirewallSnapshot,
  DashboardLogSnapshot,
  DashboardModuleCardState,
  DashboardPeripheralSnapshot,
  DashboardQuickEntryState
} from '../models/DashboardModels'

export class DashboardPresentationMapper {
  static buildModuleCards(
    admin: DashboardAdminSnapshot,
    firewall: DashboardFirewallSnapshot,
    log: DashboardLogSnapshot,
    peripheral: DashboardPeripheralSnapshot
  ): DashboardModuleCardState[] {
    return [
      DashboardPresentationMapper.buildAdminCard(admin),
      DashboardPresentationMapper.buildFirewallCard(firewall),
      DashboardPresentationMapper.buildLogCard(log),
      DashboardPresentationMapper.buildPeripheralCard(peripheral)
    ]
  }

  static buildAdminCard(admin: DashboardAdminSnapshot): DashboardModuleCardState {
    return {
      id: 'admin',
      title: DashboardStrings.adminTitle,
      primaryText: admin.activated ? DashboardStrings.adminReady : DashboardStrings.adminPending,
      secondaryText: admin.activated ? DashboardStrings.adminReadyDetail : DashboardStrings.adminPendingDetail,
      accentStart: AppColors.WARNING,
      accentEnd: AppColors.GRADIENT_IDENTITY_END,
      icon: $r('app.media.identity'),
      clickable: false
    }
  }

  static buildFirewallCard(firewall: DashboardFirewallSnapshot): DashboardModuleCardState {
    return {
      id: 'firewall',
      title: DashboardStrings.firewallTitle,
      primaryText: firewall.enabled ? DashboardStrings.firewallEnabled : DashboardStrings.firewallDisabled,
      secondaryText: firewall.modeText,
      accentStart: DashboardStrings.firewallGradient.start,
      accentEnd: DashboardStrings.firewallGradient.end,
      icon: $r('app.media.firewall'),
      clickable: false
    }
  }

  static buildLogCard(log: DashboardLogSnapshot): DashboardModuleCardState {
    return {
      id: 'log',
      title: DashboardStrings.logTitle,
      primaryText: `${log.todayCount}`,
      secondaryText: `${DashboardStrings.logTodayDetailPrefix}${log.totalCount}${DashboardStrings.logTodayDetailSuffix}`,
      accentStart: DashboardStrings.logManageGradient.start,
      accentEnd: DashboardStrings.logManageGradient.end,
      icon: $r('app.media.log'),
      clickable: false
    }
  }

  static buildPeripheralCard(peripheral: DashboardPeripheralSnapshot): DashboardModuleCardState {
    return {
      id: 'peripheral',
      title: DashboardStrings.peripheralTitle,
      primaryText: `${peripheral.totalCount}`,
      secondaryText: `${DashboardStrings.peripheralDetailPrefix}${peripheral.connectCount}${DashboardStrings.peripheralDetailMiddle}${peripheral.disconnectCount}${DashboardStrings.peripheralDetailSuffix}`,
      accentStart: DashboardStrings.peripheralGradient.start,
      accentEnd: DashboardStrings.peripheralGradient.end,
      icon: $r('app.media.peripheral'),
      clickable: false
    }
  }

  static buildQuickEntries(): DashboardQuickEntryState[] {
    return [
      {
        id: 'firewall',
        title: DashboardStrings.firewallTitle,
        icon: $r('app.media.firewall'),
        accentStart: DashboardStrings.firewallGradient.start,
        accentEnd: DashboardStrings.firewallGradient.end,
        route: Routes.FIREWALL
      },
      {
        id: 'log',
        title: DashboardStrings.logTitle,
        icon: $r('app.media.log'),
        accentStart: DashboardStrings.logManageGradient.start,
        accentEnd: DashboardStrings.logManageGradient.end,
        route: Routes.LOG_MANAGE
      },
      {
        id: 'peripheral',
        title: DashboardStrings.peripheralTitle,
        icon: $r('app.media.peripheral'),
        accentStart: DashboardStrings.peripheralGradient.start,
        accentEnd: DashboardStrings.peripheralGradient.end,
        route: Routes.PERIPHERAL_MANAGE
      },
      {
        id: 'identity',
        title: DashboardStrings.identityTitle,
        icon: $r('app.media.identity'),
        accentStart: DashboardStrings.identityGradient.start,
        accentEnd: DashboardStrings.identityGradient.end,
        route: Routes.IDENTITY
      },
      {
        id: 'tool-settings',
        title: DashboardStrings.toolSettingsTitle,
        icon: $r('app.media.settings'),
        accentStart: DashboardStrings.toolSettingsGradient.start,
        accentEnd: DashboardStrings.toolSettingsGradient.end,
        route: Routes.TOOL_SETTINGS
      },
      {
        id: 'help-feedback',
        title: DashboardStrings.helpFeedbackTitle,
        icon: $r('app.media.help'),
        accentStart: DashboardStrings.helpFeedbackGradient.start,
        accentEnd: DashboardStrings.helpFeedbackGradient.end,
        route: Routes.HELP_FEEDBACK
      }
    ]
  }
}
