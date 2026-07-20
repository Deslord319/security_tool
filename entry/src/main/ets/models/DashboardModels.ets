export type DashboardModuleCardId = 'admin-status' | 'firewall' | 'log-manage' | 'peripheral-manage'

export type DashboardQuickEntryId =
  'firewall' | 'log-manage' | 'peripheral-manage' | 'permission-manage' | 'identity' | 'tool-settings'

export interface DashboardModuleCardState {
  id: DashboardModuleCardId
  title: string
  primaryText: string
  secondaryText: string
  accentStart: string
  accentEnd: string
  icon: Resource
}

export interface DashboardQuickEntryState {
  id: DashboardQuickEntryId
  title: string
  icon: Resource
  accentStart: string
  accentEnd: string
  route: string
}
