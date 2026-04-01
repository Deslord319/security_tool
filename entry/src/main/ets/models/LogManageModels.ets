import { LogEntry } from './DataModels'

export type LogManageMode = 'list' | 'settings'

@Observed
export class LogSummaryState {
  totalCount: number = 0
  todayCount: number = 0
  blockedCount: number = 0
}

@Observed
export class LogFilterState {
  eventTypeIndex: number = 0
  resultIndex: number = 0
  keyword: string = ''
  hintMessage: string = ''
}

@Observed
export class LogPaginationState {
  currentPage: number = 1
  pageSizeIndex: number = 1
  pageInputText: string = '1'
  totalPages: number = 1
}

@Observed
export class LogDetailState {
  visible: boolean = false
  entryId: string = ''
}

@Observed
export class LogListState {
  allEntries: LogEntry[] = []
  pagedEntries: LogEntry[] = []
}

@Observed
export class LogStorageSettingsState {
  maxEntriesIndex: number = 0
  retentionIndex: number = 0
  initialMaxEntriesIndex: number = 0
  initialRetentionIndex: number = 0
  hasChanges: boolean = false
}

@Observed
export class LogManageState {
  loading: boolean = false
  mode: LogManageMode = 'list'
  summary: LogSummaryState = new LogSummaryState()
  filter: LogFilterState = new LogFilterState()
  pagination: LogPaginationState = new LogPaginationState()
  list: LogListState = new LogListState()
  detail: LogDetailState = new LogDetailState()
  settings: LogStorageSettingsState = new LogStorageSettingsState()
}
