import { LogEntry } from './DataModels'
import { CollectorStatus } from '../services/log-manage/common/LogManagePorts'

export class LogCollectorUiStatus implements CollectorStatus {
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
}

@Observed
export class LogFilterUiState {
  eventTypeIndex: number = 0
  resultIndex: number = 0
  keywordText: string = ''
}

@Observed
export class LogPaginationState {
  currentPage: number = 1
  totalPages: number = 1
  pageSize: number = 20
  pageInputText: string = '1'
}

@Observed
export class LogListPageState {
  loading: boolean = false
  active: boolean = false
  autoRefreshEnabled: boolean = true
  collectorStatus: LogCollectorUiStatus = new LogCollectorUiStatus()
  summary: LogSummaryState = new LogSummaryState()
  filter: LogFilterUiState = new LogFilterUiState()
  pagination: LogPaginationState = new LogPaginationState()
  entries: LogEntry[] = []
  pagedEntries: LogEntry[] = []
  selectedEntryId: string = ''
  hintMessage: string = ''
}

@Observed
export class LogStorageSettingsState {
  maxLocalEntries: number = 0
  retentionDays: number = 0
  dirty: boolean = false
  saving: boolean = false
}
