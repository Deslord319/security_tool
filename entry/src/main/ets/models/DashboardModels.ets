export type DashboardModuleCardId = 'admin-status' | 'firewall' | 'log-manage' | 'peripheral-manage'

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
  id: 'firewall' | 'log-manage' | 'peripheral-manage' | 'identity' | 'tool-settings' | 'help-feedback'
  title: string
  icon: Resource
  accentStart: string
  accentEnd: string
  route: string
}
