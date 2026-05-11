import { generateRandomSuffix } from '../utils/ValuePicker'
import {
  parseSecurityEventResult,
  normalizeSecurityEventResult,
  SecurityEventResult
} from './CommonModels'

export { SecurityEventResult as LogEventResult } from './CommonModels'

export enum LogEventType {
  CRASH = 0,
  FILE = 1,
  ACCOUNT = 2,
  PERMISSION = 3,
  POWER = 4,
  SYSTEM = 5,
  KERNEL = 6
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
  result: SecurityEventResult
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
  LogEventType.POWER,
  LogEventType.SYSTEM,
  LogEventType.KERNEL
]

export const ALL_LOG_EVENT_RESULTS: SecurityEventResult[] = [
  SecurityEventResult.SUCCESS,
  SecurityEventResult.BLOCKED,
  SecurityEventResult.FAILED
]

export const LOG_RETENTION_OPTIONS: number[] = [7, 14, 30, 90, 180]

export const LOG_MAX_ENTRIES_OPTIONS: number[] = [5000, 10000, 20000, 50000, 100000]

export const PREF_KEY_LOG_MAX_ENTRIES = 'log_max_entries'
export const PREF_KEY_LOG_RETENTION_DAYS = 'log_retention_days'
export const PREF_STORE_NAME_LOG = 'log_settings'

export function generateLogEntryId(): string {
  return `log_${Date.now()}_${generateRandomSuffix(9)}`
}

export function normalizeLogEventResult(
  value: SecurityEventResult,
  fallback: SecurityEventResult = SecurityEventResult.FAILED
): SecurityEventResult {
  return normalizeSecurityEventResult(value, fallback)
}

export function parseLogEventResult(
  rawValue: string,
  fallback: SecurityEventResult = SecurityEventResult.FAILED
): SecurityEventResult {
  return parseSecurityEventResult(rawValue, fallback)
}
