import {
  ALL_LOG_EVENT_TYPES,
  DEFAULT_LOG_STORAGE_CONFIG,
  LogField,
  LogEntry,
  LogEventType,
  LogRawPayload
} from '../../../models/LogModels'
import { generateRandomSuffix } from '../../../utils/ValuePicker'

const MAX_IN_MEMORY_ENTRIES = 100000
const MAX_DETAIL_LENGTH = 1024
const MAX_EVENT_KEY_LENGTH = 96
const MAX_PROCESS_NAME_LENGTH = 128
const MAX_FILE_PATH_LENGTH = 512
const MAX_REMOTE_ADDR_LENGTH = 256
const MAX_RAW_EVENT_NAME_LENGTH = 128
const MAX_FIELD_KEY_LENGTH = 96
const MAX_FIELD_STRING_VALUE_LENGTH = 64 * 1024
const MAX_RAW_PAYLOAD_LENGTH = 64 * 1024
const TRUNCATION_SUFFIX = '...'

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
      eventKey: LogEntryNormalizer.normalizeEventKey(entry.eventKey, entry.eventType),
      detail: LogEntryNormalizer.truncateString(entry.detail, MAX_DETAIL_LENGTH) || '',
      processName: LogEntryNormalizer.truncateString(entry.processName, MAX_PROCESS_NAME_LENGTH),
      pid: entry.pid,
      uid: entry.uid,
      filePath: LogEntryNormalizer.truncateString(entry.filePath, MAX_FILE_PATH_LENGTH),
      remoteAddr: LogEntryNormalizer.truncateString(entry.remoteAddr, MAX_REMOTE_ADDR_LENGTH),
      sourceEventId: entry.sourceEventId,
      rawEventName: LogEntryNormalizer.truncateString(entry.rawEventName, MAX_RAW_EVENT_NAME_LENGTH),
      fields: LogEntryNormalizer.normalizeFields(entry.fields),
      rawPayload: LogEntryNormalizer.normalizeRawPayload(entry.rawPayload)
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

  static normalizeFields(fields?: LogField[] | null): LogField[] | undefined {
    if (!fields || fields.length === 0) {
      return undefined
    }
    let normalizedFields: LogField[] = []
    let seenKeys = new Set<string>()
    for (let field of fields) {
      if (!field || typeof field !== 'object' || typeof field.key !== 'string') {
        continue
      }
      let key = LogEntryNormalizer.truncateString(field.key.trim(), MAX_FIELD_KEY_LENGTH)
      if (!key || seenKeys.has(key)) {
        continue
      }
      let value = field.value
      if (typeof value === 'string') {
        value = LogEntryNormalizer.truncateString(value.trim(), MAX_FIELD_STRING_VALUE_LENGTH) || ''
      }
      if ((typeof value !== 'string' && typeof value !== 'number' && typeof value !== 'boolean') ||
        (typeof value === 'string' && value.length === 0) ||
        (typeof value === 'number' && !Number.isFinite(value))) {
        continue
      }
      seenKeys.add(key)
      normalizedFields.push({ key, value })
    }
    return normalizedFields.length > 0 ? normalizedFields : undefined
  }

  static normalizeRawPayload(payload?: LogRawPayload | null): LogRawPayload | undefined {
    if (!payload) {
      return undefined
    }
    const content = payload.content || ''
    const metadata = payload.metadata || ''
    if (content.length === 0 && metadata.length === 0) {
      return undefined
    }
    const normalizedContent = content.substring(0, MAX_RAW_PAYLOAD_LENGTH)
    const remaining = Math.max(0, MAX_RAW_PAYLOAD_LENGTH - normalizedContent.length)
    const normalizedMetadata = metadata.substring(0, remaining)
    return {
      content: normalizedContent.length > 0 ? normalizedContent : undefined,
      metadata: normalizedMetadata.length > 0 ? normalizedMetadata : undefined,
      truncated: payload.truncated || content.length > normalizedContent.length || metadata.length > normalizedMetadata.length
    }
  }

  private static normalizeEventKey(eventKey: string | undefined, eventType: LogEventType): string {
    const normalized = LogEntryNormalizer.truncateString((eventKey || '').trim(), MAX_EVENT_KEY_LENGTH)
    return normalized || `${LogEntryNormalizer.eventTypePrefix(eventType)}.unknown`
  }

  private static eventTypePrefix(eventType: LogEventType): string {
    switch (eventType) {
      case LogEventType.CRASH: return 'crash'
      case LogEventType.FILE: return 'file'
      case LogEventType.ACCOUNT: return 'account'
      case LogEventType.PERMISSION: return 'permission'
      case LogEventType.POWER: return 'device'
      case LogEventType.SYSTEM: return 'system'
      case LogEventType.KERNEL: return 'kernel'
      default: return 'audit'
    }
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
    if (limit <= TRUNCATION_SUFFIX.length) {
      return value.substring(0, limit)
    }
    return `${value.substring(0, limit - TRUNCATION_SUFFIX.length)}${TRUNCATION_SUFFIX}`
  }
}
