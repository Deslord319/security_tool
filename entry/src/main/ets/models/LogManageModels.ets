import { LogEntry } from './DataModels'
import { LogStorageSettingsState } from '../viewmodels/LogStorageSettingsViewModel'

export type LogManageMode = 'list' | 'settings'

export interface LogSummaryState {
  totalCount: number
  todayCount: number
  blockedCount: number
  currentShownCount: number
}

export interface LogCollectorState {
  running: boolean
  crashSubscribed: boolean
  fileSubscribed: boolean
  accountSubscribed: boolean
  permissionSubscribed: boolean
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

export interface LogManageState {
  loading: boolean
  active: boolean
  autoRefreshEnabled: boolean
  mode: LogManageMode
  summary: LogSummaryState
  collector: LogCollectorState
  filter: LogFilterState
  pagination: LogPaginationState
  list: LogListState
  detail: LogDetailState
  settings: LogStorageSettingsState
}

