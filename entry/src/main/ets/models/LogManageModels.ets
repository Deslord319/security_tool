import { LogEntry } from './DataModels'
import { CollectorStatus } from '../services/log-manage/common/LogManagePorts'

export type LogManageMode = 'list' | 'settings'

@Observed
export class LogCollectorState implements CollectorStatus {
  running: boolean = false
  auditReady: boolean = false
  crashReady: boolean = false
  pendingCount: number = 0
  degraded: boolean = false
  degradedReason?: 'audit_failed' | 'crash_failed' | 'partial'
}

@Observed
export class LogSummaryState {
  totalCount: number = 0
  todayCount: number = 0
  blockedCount: number = 0
  currentShownCount: number = 0
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
  pageSizeIndex: number = 0
  pageInputText: string = '1'
  totalPages: number = 1
}

@Observed
export class LogListState {
  allEntries: LogEntry[] = []
  pagedEntries: LogEntry[] = []
}

@Observed
export class LogDetailState {
  visible: boolean = false
  entryId: string = ''
}

@Observed
export class LogManageState {
  loading: boolean = false
  active: boolean = false
  autoRefreshEnabled: boolean = true
  mode: LogManageMode = 'list'
  summary: LogSummaryState = new LogSummaryState()
  collector: LogCollectorState = new LogCollectorState()
  filter: LogFilterState = new LogFilterState()
  pagination: LogPaginationState = new LogPaginationState()
  list: LogListState = new LogListState()
  detail: LogDetailState = new LogDetailState()
}

@Observed
export class LogStorageSettingsState {
  maxLocalEntries: number = 0
  retentionDays: number = 0
  dirty: boolean = false
  saving: boolean = false
}
