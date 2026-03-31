import { LogEntry } from './DataModels'

export type LogManageMode = 'list' | 'settings'

export interface LogSummaryState {
  totalCount: number
  todayCount: number
  blockedCount: number
}

export interface LogFilterState {
  eventTypeIndex: number
  resultIndex: number
  keyword: string
  hintMessage: string
}

export interface LogPaginationState {
  currentPage: number
  pageSizeIndex: number
  pageInputText: string
  totalPages: number
}

export interface LogDetailState {
  visible: boolean
  entryId: string
}

export interface LogListState {
  allEntries: LogEntry[]
  pagedEntries: LogEntry[]
}

export interface LogStorageSettingsState {
  maxEntriesIndex: number
  retentionIndex: number
  initialMaxEntriesIndex: number
  initialRetentionIndex: number
  hasChanges: boolean
}

export interface LogManageState {
  loading: boolean
  mode: LogManageMode
  summary: LogSummaryState
  filter: LogFilterState
  pagination: LogPaginationState
  list: LogListState
  detail: LogDetailState
  settings: LogStorageSettingsState
}
