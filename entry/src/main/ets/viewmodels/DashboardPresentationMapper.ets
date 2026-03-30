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
      }
    ]
  }

  static buildAdminCard(snapshot: DashboardAdminSnapshot): DashboardModuleCardState {
    return {
      id: 'admin',
      title: DashboardStrings.adminTitle,
      primaryText: snapshot.activated ? DashboardStrings.adminReady : DashboardStrings.adminPending,
      secondaryText: snapshot.activated ? DashboardStrings.adminReadyDetail : DashboardStrings.adminPendingDetail,
      statusText: snapshot.activated ? DashboardStrings.adminReady : DashboardStrings.adminPending,
      statusKind: snapshot.activated ? 'success' : 'warning',
      accentStart: AppColors.WARNING,
      accentEnd: AppColors.GRADIENT_IDENTITY_END,
      icon: $r('app.media.identity'),
      clickable: false
    }
  }

  static buildFirewallCard(snapshot: DashboardFirewallSnapshot): DashboardModuleCardState {
    return {
      id: 'firewall',
      title: DashboardStrings.firewallTitle,
      primaryText: snapshot.enabled ? DashboardStrings.firewallEnabled : DashboardStrings.firewallDisabled,
      secondaryText: snapshot.modeText,
      statusText: snapshot.enabled ? DashboardStrings.firewallEnabledDetail : DashboardStrings.firewallDisabledDetail,
      statusKind: snapshot.enabled ? 'success' : 'warning',
      accentStart: DashboardStrings.firewallGradient.start,
      accentEnd: DashboardStrings.firewallGradient.end,
      icon: $r('app.media.firewall'),
      clickable: false
    }
  }

  static buildLogCard(snapshot: DashboardLogSnapshot): DashboardModuleCardState {
    return {
      id: 'log',
      title: DashboardStrings.logTitle,
      primaryText: `${snapshot.todayCount}`,
      secondaryText: `${DashboardStrings.logTodayDetailPrefix}${snapshot.totalCount}${DashboardStrings.logTodayDetailSuffix}`,
      statusText: snapshot.collecting ? DashboardStrings.collecting : DashboardStrings.collectStopped,
      statusKind: snapshot.collecting ? 'success' : 'warning',
      accentStart: DashboardStrings.logManageGradient.start,
      accentEnd: DashboardStrings.logManageGradient.end,
      icon: $r('app.media.log'),
      clickable: false
    }
  }

  static buildPeripheralCard(snapshot: DashboardPeripheralSnapshot): DashboardModuleCardState {
    return {
      id: 'peripheral',
      title: DashboardStrings.peripheralTitle,
      primaryText: `${snapshot.totalCount}`,
      secondaryText: `${DashboardStrings.peripheralDetailPrefix}${snapshot.connectCount}${DashboardStrings.peripheralDetailMiddle}${snapshot.disconnectCount}${DashboardStrings.peripheralDetailSuffix}`,
      statusText: snapshot.listening ? DashboardStrings.listening : DashboardStrings.listenStopped,
      statusKind: snapshot.listening ? 'success' : 'warning',
      accentStart: DashboardStrings.peripheralGradient.start,
      accentEnd: DashboardStrings.peripheralGradient.end,
      icon: $r('app.media.peripheral'),
      clickable: false
    }
  }
}
