export type DashboardModuleCardId = 'admin-status' | 'firewall' | 'log-manage' | 'peripheral-manage'

export type DashboardQuickEntryId =
  'firewall' | 'log-manage' | 'peripheral-manage' | 'permission-manage' | 'identity' | 'tool-settings'

export interface DashboardModuleCardState {
  id: DashboardModuleCardId
  title: string
  primaryText: string
  secondaryText: string
  accentStart: ResourceColor
  accentEnd: ResourceColor
  icon: Resource
}

export interface DashboardQuickEntryState {
  id: DashboardQuickEntryId
  title: string
  icon: Resource
  accentStart: ResourceColor
  accentEnd: ResourceColor
  route: string
}
