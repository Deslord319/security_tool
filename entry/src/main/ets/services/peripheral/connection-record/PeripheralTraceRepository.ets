import { LogUtils } from '../../../utils/LogUtils'
import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'

import {
  LogEventResult,
  PeripheralRecordAction,
  PeripheralRecordPolicyHit,
  PeripheralRecordSource,
  PeripheralTraceQuery,
  PeripheralTraceRecord,
  PeripheralTraceStats,
  PeripheralType
} from '../../../models/DataModels'

const TAG = 'PeripheralTraceRepo'
const PREF_STORE_NAME = 'peripheral_trace_settings'
const PREF_KEY_TRACE_RECORDS = 'peripheral_trace_records'
const RETENTION_DAYS_DEFAULT = 180
const MAX_TRACE_ENTRIES_DEFAULT = 200000
const PERSIST_MAX_ENTRIES = 12000
const PERSIST_MAX_PAYLOAD_CHARS = 4 * 1024 * 1024

interface TraceChangeEvent {
  totalCount: number
  addedCount: number
  timestamp: number
}

type TraceChangeListener = (event: TraceChangeEvent) => void

interface TraceRetentionConfig {
  retentionDays: number
  maxEntries: number
}

export class PeripheralTraceRepository {
  private static context: common.UIAbilityContext | null = null
  private static initPromise: Promise<boolean> | null = null
  private static initialized: boolean = false
  private static records: PeripheralTraceRecord[] = []
  private static nextListenerId: number = 1
  private static listeners: Map<number, TraceChangeListener> = new Map()
  private static retentionDays: number = RETENTION_DAYS_DEFAULT
  private static maxEntries: number = MAX_TRACE_ENTRIES_DEFAULT
  private static nowProvider: () => number = () => Date.now()

  static async init(context: common.UIAbilityContext): Promise<boolean> {
    PeripheralTraceRepository.context = context
    if (PeripheralTraceRepository.initialized) {
      return true
    }
    if (PeripheralTraceRepository.initPromise) {
      return PeripheralTraceRepository.initPromise
    }
    PeripheralTraceRepository.initPromise = PeripheralTraceRepository.doInit()
    let ok = await PeripheralTraceRepository.initPromise
    PeripheralTraceRepository.initPromise = null
    return ok
  }

  static async configure(retentionDays?: number, maxEntries?: number): Promise<void> {
    if (retentionDays !== undefined && Number.isFinite(retentionDays) && retentionDays > 0) {
      PeripheralTraceRepository.retentionDays = Math.floor(retentionDays)
    }
    if (maxEntries !== undefined && Number.isFinite(maxEntries) && maxEntries > 0) {
      PeripheralTraceRepository.maxEntries = Math.floor(maxEntries)
    }
    let removed = PeripheralTraceRepository.cleanupInMemory()
    if (removed > 0) {
      await PeripheralTraceRepository.saveRecords()
    }
  }

  static addChangeListener(listener: TraceChangeListener): number {
    let id = PeripheralTraceRepository.nextListenerId++
    PeripheralTraceRepository.listeners.set(id, listener)
    return id
  }

  static removeChangeListener(listenerId: number): void {
    PeripheralTraceRepository.listeners.delete(listenerId)
  }

  static async append(record: PeripheralTraceRecord): Promise<boolean> {
    return PeripheralTraceRepository.appendBatch([record])
  }

  static async appendBatch(records: PeripheralTraceRecord[]): Promise<boolean> {
    try {
      if (records.length === 0) {
        return true
      }
      let normalized: PeripheralTraceRecord[] = []
      for (let item of records) {
        if (!item) {
          continue
        }
        normalized.push(PeripheralTraceRepository.normalizeRecord(item))
      }
      if (normalized.length === 0) {
        return true
      }

      // Newest first. Notify listeners immediately after the in-memory state changes
      // so UI consumers can refresh without waiting for persistence to finish.
      PeripheralTraceRepository.records = normalized.concat(PeripheralTraceRepository.records)
      PeripheralTraceRepository.cleanupInMemory()
      PeripheralTraceRepository.notifyChanged(normalized.length)
      await PeripheralTraceRepository.saveRecords()
      return true
    } catch (err) {
      LogUtils.error(TAG, `appendBatch failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static query(query?: PeripheralTraceQuery): PeripheralTraceRecord[] {
    if (!query) {
      return PeripheralTraceRepository.records.slice()
    }
    let pageOffset = query.pageOffset && query.pageOffset > 0 ? Math.floor(query.pageOffset) : 0
    let pageSize = query.pageSize && query.pageSize > 0 ? Math.floor(query.pageSize) : 0

    let filtered = PeripheralTraceRepository.records.filter((record: PeripheralTraceRecord) => {
      if (
        query.startTime !== undefined &&
        Number.isFinite(query.startTime) &&
        record.occurAt < query.startTime
      ) {
        return false
      }
      if (
        query.endTime !== undefined &&
        Number.isFinite(query.endTime) &&
        record.occurAt > query.endTime
      ) {
        return false
      }

      if (query.deviceId && query.deviceId.length > 0) {
        let target = PeripheralTraceRepository.normalizeDeviceId(query.deviceId)
        if (PeripheralTraceRepository.normalizeDeviceId(record.deviceId) !== target) {
          return false
        }
      }

      if (query.deviceTypes && query.deviceTypes.length > 0 && !query.deviceTypes.includes(record.deviceType)) {
        return false
      }
      if (query.actions && query.actions.length > 0 && !query.actions.includes(record.action)) {
        return false
      }
      if (query.decisions && query.decisions.length > 0 && !query.decisions.includes(record.decision)) {
        return false
      }
      if (query.results && query.results.length > 0 && !query.results.includes(record.result)) {
        return false
      }
      if (query.sources && query.sources.length > 0 && !query.sources.includes(record.source)) {
        return false
      }
      if (query.keyword && query.keyword.length > 0) {
        let keyword = query.keyword.toLowerCase()
        let text = `${record.deviceName} ${record.deviceId} ${record.summary} ${record.detail || ''} ${record.processName || ''}`.toLowerCase()
        if (!text.includes(keyword)) {
          return false
        }
      }
      return true
    })

    if (pageOffset > 0) {
      filtered = filtered.slice(pageOffset)
    }
    if (pageSize > 0) {
      filtered = filtered.slice(0, pageSize)
    }
    return filtered
  }

  static getStats(query?: PeripheralTraceQuery): PeripheralTraceStats {
    let records = PeripheralTraceRepository.query(query)
    let stats: PeripheralTraceStats = {
      total: records.length,
      connects: 0,
      disconnects: 0,
      intercepts: 0,
      allows: 0,
      denies: 0,
      unknowns: 0,
      runtimeCount: 0,
      auditCount: 0,
      snapshotCount: 0
    }
    for (let record of records) {
      if (record.action === 'connect') {
        stats.connects++
      } else if (record.action === 'disconnect') {
        stats.disconnects++
      } else if (record.action === 'intercept') {
        stats.intercepts++
      }

      if (record.decision === 'allow') {
        stats.allows++
      } else if (record.decision === 'deny') {
        stats.denies++
      } else {
        stats.unknowns++
      }

      if (record.source === 'runtime_event') {
        stats.runtimeCount++
      } else if (record.source === 'audit_event') {
        stats.auditCount++
      } else {
        stats.snapshotCount++
      }
    }
    return stats
  }

  static exportJson(query?: PeripheralTraceQuery): string {
    let records = PeripheralTraceRepository.query(query)
    return JSON.stringify(records, null, 2)
  }

  static getRetentionConfig(): TraceRetentionConfig {
    let config: TraceRetentionConfig = {
      retentionDays: PeripheralTraceRepository.retentionDays,
      maxEntries: PeripheralTraceRepository.maxEntries
    }
    return config
  }

  static async forceCleanup(retentionDays?: number, maxEntries?: number): Promise<number> {
    if (retentionDays !== undefined && Number.isFinite(retentionDays) && retentionDays > 0) {
      PeripheralTraceRepository.retentionDays = Math.floor(retentionDays)
    }
    if (maxEntries !== undefined && Number.isFinite(maxEntries) && maxEntries > 0) {
      PeripheralTraceRepository.maxEntries = Math.floor(maxEntries)
    }
    let removed = PeripheralTraceRepository.cleanupInMemory()
    if (removed > 0) {
      await PeripheralTraceRepository.saveRecords()
      PeripheralTraceRepository.notifyChanged(0)
    }
    return removed
  }

  static async clearAll(): Promise<boolean> {
    try {
      PeripheralTraceRepository.records = []
      await PeripheralTraceRepository.saveRecords()
      PeripheralTraceRepository.notifyChanged(0)
      LogUtils.info(TAG, 'clearAll success')
      return true
    } catch (err) {
      LogUtils.error(TAG, `clearAll failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static resetForTest(): void {
    PeripheralTraceRepository.context = null
    PeripheralTraceRepository.initPromise = null
    PeripheralTraceRepository.initialized = false
    PeripheralTraceRepository.records = []
    PeripheralTraceRepository.listeners = new Map()
    PeripheralTraceRepository.nextListenerId = 1
    PeripheralTraceRepository.retentionDays = RETENTION_DAYS_DEFAULT
    PeripheralTraceRepository.maxEntries = MAX_TRACE_ENTRIES_DEFAULT
    PeripheralTraceRepository.nowProvider = () => Date.now()
  }

  static setRecordsForTest(records: PeripheralTraceRecord[]): void {
    PeripheralTraceRepository.records = PeripheralTraceRepository.sanitizeRecords(records)
  }

  private static async doInit(): Promise<boolean> {
    if (!PeripheralTraceRepository.context) {
      return false
    }
    try {
      let store = await preferences.getPreferences(PeripheralTraceRepository.context, PREF_STORE_NAME)
      let raw = await store.get(PREF_KEY_TRACE_RECORDS, '[]') as string
      let parsed = JSON.parse(raw) as PeripheralTraceRecord[]
      PeripheralTraceRepository.records = PeripheralTraceRepository.sanitizeRecords(parsed)
      PeripheralTraceRepository.cleanupInMemory()
      PeripheralTraceRepository.initialized = true
      LogUtils.info(TAG, `init complete, records=${PeripheralTraceRepository.records.length}`)
      return true
    } catch (err) {
      PeripheralTraceRepository.initialized = false
      PeripheralTraceRepository.records = []
      LogUtils.error(TAG, `init failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  private static sanitizeRecords(records: PeripheralTraceRecord[]): PeripheralTraceRecord[] {
    let result: PeripheralTraceRecord[] = []
    if (!Array.isArray(records)) {
      return result
    }
    for (let item of records) {
      if (!item || typeof item !== 'object') {
        continue
      }
      result.push(PeripheralTraceRepository.normalizeRecord(item))
    }
    result.sort((a: PeripheralTraceRecord, b: PeripheralTraceRecord) => {
      if (a.occurAt === b.occurAt) {
        return b.collectAt - a.collectAt
      }
      return b.occurAt - a.occurAt
    })
    return result
  }

  private static normalizeRecord(record: PeripheralTraceRecord): PeripheralTraceRecord {
    let now = PeripheralTraceRepository.nowProvider()
    let occurAt = Number.isFinite(record.occurAt) && record.occurAt > 0 ? Math.floor(record.occurAt) : now
    let collectAt = Number.isFinite(record.collectAt) && record.collectAt > 0 ? Math.floor(record.collectAt) : now
    let result = PeripheralTraceRepository.normalizeResult(record.result)
    let action = PeripheralTraceRepository.normalizeAction(record.action)
    let decision = PeripheralTraceRepository.normalizeDecision(record.decision)
    let source = PeripheralTraceRepository.normalizeSource(record.source)
    return {
      recordId: record.recordId && record.recordId.length > 0 ?
        record.recordId :
        `ptr_${collectAt}_${Math.random().toString(36).substring(2, 8)}`,
      occurAt: occurAt,
      collectAt: collectAt,
      deviceName: record.deviceName || 'Unknown Device',
      deviceType: record.deviceType || PeripheralType.USB_OTHER,
      deviceId: PeripheralTraceRepository.normalizeDeviceId(record.deviceId),
      action: action,
      decision: decision,
      result: result,
      source: source,
      summary: record.summary || '',
      correlationId: record.correlationId,
      policyVersion: record.policyVersion,
      rawEventId: record.rawEventId,
      rawEventName: record.rawEventName,
      rawOutcome: record.rawOutcome,
      rawAction: record.rawAction,
      rawPayload: record.rawPayload,
      detail: record.detail,
      processName: record.processName,
      usbPolicy: record.usbPolicy,
      effectivePolicyLabel: record.effectivePolicyLabel,
      matchedPolicyKind: record.matchedPolicyKind || 'unknown'
    }
  }

  private static normalizeResult(result: LogEventResult): LogEventResult {
    if (
      result === LogEventResult.SUCCESS ||
      result === LogEventResult.BLOCKED ||
      result === LogEventResult.FAILED
    ) {
      return result
    }
    return LogEventResult.SUCCESS
  }

  private static normalizeAction(action: PeripheralRecordAction): PeripheralRecordAction {
    if (
      action === 'connect' ||
      action === 'disconnect' ||
      action === 'intercept' ||
      action === 'unknown'
    ) {
      return action
    }
    return 'unknown'
  }

  private static normalizeDecision(decision: PeripheralRecordPolicyHit): PeripheralRecordPolicyHit {
    if (decision === 'allow' || decision === 'deny' || decision === 'unknown') {
      return decision
    }
    return 'unknown'
  }

  private static normalizeSource(source: PeripheralRecordSource): PeripheralRecordSource {
    if (source === 'runtime_event' || source === 'audit_event' || source === 'policy_snapshot') {
      return source
    }
    return 'audit_event'
  }

  private static normalizeDeviceId(deviceId: string): string {
    let value = (deviceId || '').trim()
    if (value.length === 0) {
      return 'UNKNOWN'
    }
    return value.replace(/\s+/g, ' ').toUpperCase()
  }

  private static cleanupInMemory(): number {
    let now = PeripheralTraceRepository.nowProvider()
    let retentionMs = PeripheralTraceRepository.retentionDays * 24 * 60 * 60 * 1000
    let cutoff = now - retentionMs
    let before = PeripheralTraceRepository.records.length

    let filtered = PeripheralTraceRepository.records.filter((item: PeripheralTraceRecord) => item.occurAt >= cutoff)
    if (filtered.length > PeripheralTraceRepository.maxEntries) {
      filtered = filtered
        .sort((a: PeripheralTraceRecord, b: PeripheralTraceRecord) => b.occurAt - a.occurAt)
        .slice(0, PeripheralTraceRepository.maxEntries)
    }
    PeripheralTraceRepository.records = filtered
    return before - filtered.length
  }

  private static async saveRecords(): Promise<void> {
    if (!PeripheralTraceRepository.context) {
      return
    }
    try {
      let persistRecords = PeripheralTraceRepository.records.slice(
        0,
        Math.min(PERSIST_MAX_ENTRIES, PeripheralTraceRepository.records.length)
      )
      let payload = JSON.stringify(persistRecords)
      while (payload.length > PERSIST_MAX_PAYLOAD_CHARS && persistRecords.length > 1) {
        persistRecords = persistRecords.slice(0, Math.max(1, Math.floor(persistRecords.length * 0.8)))
        payload = JSON.stringify(persistRecords)
      }
      if (payload.length > PERSIST_MAX_PAYLOAD_CHARS) {
        payload = '[]'
      }
      let store = await preferences.getPreferences(PeripheralTraceRepository.context, PREF_STORE_NAME)
      await store.put(PREF_KEY_TRACE_RECORDS, payload)
      await store.flush()
    } catch (err) {
      LogUtils.error(TAG, `saveRecords failed: ${JSON.stringify(err)}`)
    }
  }

  private static notifyChanged(addedCount: number): void {
    if (PeripheralTraceRepository.listeners.size <= 0) {
      return
    }
    let event: TraceChangeEvent = {
      totalCount: PeripheralTraceRepository.records.length,
      addedCount: addedCount,
      timestamp: PeripheralTraceRepository.nowProvider()
    }
    PeripheralTraceRepository.listeners.forEach((listener: TraceChangeListener) => {
      try {
        listener(event)
      } catch (err) {
        LogUtils.warn(TAG, `listener failed: ${JSON.stringify(err)}`)
      }
    })
  }
}
