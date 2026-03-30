export type DashboardModuleCardId = 'admin' | 'firewall' | 'log' | 'peripheral'

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
  id: 'firewall' | 'log' | 'peripheral' | 'identity' | 'tool-settings' | 'help-feedback'
  title: string
  icon: Resource
  accentStart: string
  accentEnd: string
  route: string
}
