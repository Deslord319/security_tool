import {
  ALL_LOG_EVENT_TYPES,
  DEFAULT_LOG_STORAGE_CONFIG,
  LogDetailTableRow,
  LogEntry,
  LogEventResult,
  LogEventType
} from '../../../models/DataModels'
import { generateRandomSuffix } from '../../../utils/ValuePicker'

const MAX_IN_MEMORY_ENTRIES = 100000
const MAX_DETAIL_LENGTH = 1024
const MAX_PROCESS_NAME_LENGTH = 128
const MAX_FILE_PATH_LENGTH = 512
const MAX_REMOTE_ADDR_LENGTH = 256
const MAX_RAW_EVENT_NAME_LENGTH = 128
const MAX_RAW_OUTCOME_LENGTH = 64
const MAX_RAW_ACTION_LENGTH = 64
const MAX_DETAIL_ROW_KEY_LENGTH = 64
const MAX_DETAIL_ROW_LABEL_LENGTH = 128
const MAX_DETAIL_ROW_VALUE_LENGTH = 1024

export class LogEntryNormalizer {
  private static nowProvider: () => number = () => Date.now()

  static normalizeMaxEntries(maxEntries: number): number {
    if (!Number.isFinite(maxEntries) || maxEntries <= 0) {
      return DEFAULT_LOG_STORAGE_CONFIG.maxLocalEntries
    }
    if (maxEntries > MAX_IN_MEMORY_ENTRIES) {
      return MAX_IN_MEMORY_ENTRIES
    }
    return Math.floor(maxEntries)
  }

  static normalizeRetentionDays(days: number): number {
    if (!Number.isFinite(days)) {
      return DEFAULT_LOG_STORAGE_CONFIG.retentionDays
    }
    let normalized = Math.floor(days)
    if (normalized <= 0) {
      return DEFAULT_LOG_STORAGE_CONFIG.retentionDays
    }
    return normalized > 3650 ? 3650 : normalized
  }

  static normalizeEntry(entry: LogEntry): LogEntry {
    return {
      id: LogEntryNormalizer.normalizeEntryId(entry.id),
      timestamp: LogEntryNormalizer.normalizeTimestamp(entry.timestamp),
      eventType: LogEntryNormalizer.normalizeEventType(entry.eventType),
      detail: LogEntryNormalizer.truncateString(entry.detail, MAX_DETAIL_LENGTH) || '',
      processName: LogEntryNormalizer.truncateString(entry.processName, MAX_PROCESS_NAME_LENGTH),
      pid: entry.pid,
      uid: entry.uid,
      filePath: LogEntryNormalizer.truncateString(entry.filePath, MAX_FILE_PATH_LENGTH),
      remoteAddr: LogEntryNormalizer.truncateString(entry.remoteAddr, MAX_REMOTE_ADDR_LENGTH),
      sourceEventId: entry.sourceEventId,
      rawEventName: LogEntryNormalizer.truncateString(entry.rawEventName, MAX_RAW_EVENT_NAME_LENGTH),
      rawOutcome: LogEntryNormalizer.truncateString(entry.rawOutcome, MAX_RAW_OUTCOME_LENGTH),
      rawAction: LogEntryNormalizer.truncateString(entry.rawAction, MAX_RAW_ACTION_LENGTH),
      detailRows: LogEntryNormalizer.normalizeDetailRows(entry.detailRows),
      result: LogEntryNormalizer.normalizeEventResult(entry.result)
    }
  }

  static normalizeEntriesForAppend(entries: LogEntry[]): LogEntry[] {
    let normalizedBatch: LogEntry[] = []
    for (let entry of entries) {
      if (!entry || typeof entry !== 'object') {
        continue
      }
      normalizedBatch.push(LogEntryNormalizer.normalizeEntry(entry))
    }
    return normalizedBatch
  }

  private static normalizeTimestamp(ts: number): number {
    if (!Number.isFinite(ts) || ts < 0) {
      return LogEntryNormalizer.nowProvider()
    }
    return Math.floor(ts)
  }

  private static normalizeEventType(type: LogEventType): LogEventType {
    if (ALL_LOG_EVENT_TYPES.includes(type)) {
      return type
    }
    return LogEventType.FILE
  }

  private static normalizeEventResult(result: LogEventResult): LogEventResult {
    if (result === LogEventResult.SUCCESS || result === LogEventResult.BLOCKED || result === LogEventResult.FAILED) {
      return result
    }
    return LogEventResult.SUCCESS
  }

  static normalizeDetailRows(rows?: LogDetailTableRow[] | null): LogDetailTableRow[] | undefined {
    if (!rows || rows.length === 0) {
      return undefined
    }
    let normalizedRows: LogDetailTableRow[] = []
    for (let row of rows) {
      if (!row || typeof row !== 'object') {
        continue
      }
      if (typeof row.key !== 'string' || typeof row.label !== 'string' || typeof row.value !== 'string') {
        continue
      }
      let key = LogEntryNormalizer.truncateString(row.key.trim(), MAX_DETAIL_ROW_KEY_LENGTH)
      let label = LogEntryNormalizer.truncateString(row.label.trim(), MAX_DETAIL_ROW_LABEL_LENGTH)
      let value = LogEntryNormalizer.truncateString(row.value.trim(), MAX_DETAIL_ROW_VALUE_LENGTH)
      if (!key || !label || !value) {
        continue
      }
      normalizedRows.push({
        key,
        label,
        value
      })
    }
    return normalizedRows.length > 0 ? normalizedRows : undefined
  }

  private static normalizeEntryId(id: string | undefined): string {
    if (id && id.trim().length > 0) {
      return id.trim()
    }
    return `persist_${LogEntryNormalizer.nowProvider()}_${generateRandomSuffix(7)}`
  }

  private static truncateString(value: string | undefined, limit: number): string | undefined {
    if (value === undefined) {
      return undefined
    }
    if (value.length <= limit) {
      return value
    }
    return `${value.substring(0, limit)}...`
  }
}
