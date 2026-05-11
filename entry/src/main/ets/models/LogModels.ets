import { generateRandomSuffix } from '../utils/ValuePicker'

export enum LogEventType {
  CRASH = 0,
  FILE = 1,
  ACCOUNT = 2,
  PERMISSION = 3,
  POWER = 4
}

export enum LogEventResult {
  SUCCESS = 0,
  BLOCKED = 1,
  FAILED = 2
}

export interface LogDetailTableRow {
  key: string
  label: string
  value: string
}

export interface LogEntry {
  id: string
  timestamp: number
  eventType: LogEventType
  detail: string
  processName?: string
  pid?: number
  uid?: number
  filePath?: string
  remoteAddr?: string
  sourceEventId?: number
  rawEventName?: string
  rawOutcome?: string
  rawAction?: string
  detailRows?: LogDetailTableRow[]
  result: LogEventResult
}

export interface LogStorageConfig {
  maxLocalEntries: number
  retentionDays: number
}

export interface LogStatistics {
  totalCount: number
  todayCount: number
  blockedCount: number
  byType: Map<LogEventType, number>
}

export const DEFAULT_LOG_STORAGE_CONFIG: LogStorageConfig = {
  maxLocalEntries: 20000,
  retentionDays: 30
}

export const ALL_LOG_EVENT_TYPES: LogEventType[] = [
  LogEventType.CRASH,
  LogEventType.FILE,
  LogEventType.ACCOUNT,
  LogEventType.PERMISSION,
  LogEventType.POWER
]

export const LOG_RETENTION_OPTIONS: number[] = [7, 14, 30, 90, 180]

export const LOG_MAX_ENTRIES_OPTIONS: number[] = [5000, 10000, 20000, 50000, 100000]

export const PREF_KEY_LOG_MAX_ENTRIES = 'log_max_entries'
export const PREF_KEY_LOG_RETENTION_DAYS = 'log_retention_days'
export const PREF_STORE_NAME_LOG = 'log_settings'

export function generateLogEntryId(): string {
  return `log_${Date.now()}_${generateRandomSuffix(9)}`
}

export function normalizeLogEventResult(value: LogEventResult, fallback: LogEventResult = LogEventResult.FAILED): LogEventResult {
  if (value === LogEventResult.SUCCESS || value === LogEventResult.BLOCKED || value === LogEventResult.FAILED) {
    return value
  }
  return fallback
}

export function parseLogEventResult(rawValue: string, fallback: LogEventResult = LogEventResult.FAILED): LogEventResult {
  let numeric = Number(rawValue)
  if (numeric === LogEventResult.SUCCESS || numeric === LogEventResult.BLOCKED || numeric === LogEventResult.FAILED) {
    return numeric as LogEventResult
  }
  return fallback
}
