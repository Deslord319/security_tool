export interface DashboardModuleCardState {
  id: 'admin-status' | 'firewall' | 'log-manage' | 'peripheral-manage'
  title: string
  primaryText: string
  secondaryText: string
  accentStart: string
  accentEnd: string
  icon: Resource
}

export interface DashboardQuickEntryState {
  id: 'firewall' | 'log-manage' | 'peripheral-manage' | 'permission-manage' | 'identity' | 'tool-settings'
  title: string
  icon: Resource
  accentStart: string
  accentEnd: string
  route: string
}
