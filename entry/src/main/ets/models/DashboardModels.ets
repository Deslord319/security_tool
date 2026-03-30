export type DashboardModuleCardId = 'admin' | 'firewall' | 'log' | 'peripheral'

export interface DashboardModuleCardState {
  id: DashboardModuleCardId
  title: string
  primaryText: string
  secondaryText: string
  accentStart: string
  accentEnd: string
  icon: Resource
  route?: string
  clickable: boolean
}

export interface DashboardQuickEntryState {
  id: 'firewall' | 'log' | 'peripheral' | 'identity' | 'tool-settings' | 'help-feedback'
  title: string
  icon: Resource
  accentStart: string
  accentEnd: string
  route: string
}

export interface DashboardAdminSnapshot {
  activated: boolean
}

export interface DashboardFirewallSnapshot {
  enabled: boolean
  modeText: string
}

export interface DashboardLogSnapshot {
  todayCount: number
  totalCount: number
  collecting: boolean
}

export interface DashboardPeripheralSnapshot {
  totalCount: number
  connectCount: number
  disconnectCount: number
  listening: boolean
}
