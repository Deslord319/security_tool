export type DashboardModuleCardId = 'admin' | 'firewall' | 'log' | 'peripheral'

export type DashboardStatusKind = 'success' | 'warning' | 'neutral'

export interface DashboardModuleCardState {
  id: DashboardModuleCardId
  title: string
  primaryText: string
  secondaryText: string
  statusText: string
  statusKind: DashboardStatusKind
  accentStart: string
  accentEnd: string
  icon: Resource
  route?: string
  clickable: boolean
}

export interface DashboardQuickEntryState {
  id: 'identity' | 'tool-settings' | 'help-feedback'
  title: string
  icon: Resource
  accentStart: string
  accentEnd: string
  route: string
}
