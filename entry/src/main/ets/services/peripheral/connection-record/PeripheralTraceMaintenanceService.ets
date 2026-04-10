import { common } from '@kit.AbilityKit'
import {
  LogEventResult,
  PeripheralRecordAction,
  PeripheralRecordPolicyHit,
  PeripheralRecordSource,
  PeripheralTraceRecord,
  PeripheralType
} from '../../../models/DataModels'
import { LogUtils } from '../../../utils/LogUtils'
import { PeripheralTraceEntryRepository } from './PeripheralTraceEntryRepository'

const TAG = 'PeripheralTraceMaintenance'
const RETENTION_DAYS_DEFAULT = 180
const MAX_TRACE_ENTRIES_DEFAULT = 200000

interface TraceRetentionConfig {
  retentionDays: number
  maxEntries: number
}

export class PeripheralTraceMaintenanceService {
  private static retentionDays: number = RETENTION_DAYS_DEFAULT
  private static maxEntries: number = MAX_TRACE_ENTRIES_DEFAULT
  private static nowProvider: () => number = () => Date.now()

  static async initialize(context: common.UIAbilityContext): Promise<boolean> {
    let ready = await PeripheralTraceEntryRepository.init(context)
    if (!ready) {
      return false
    }
    return PeripheralTraceMaintenanceService.reconcileStorageConfig()
  }

  static async configure(retentionDays?: number, maxEntries?: number): Promise<boolean> {
    if (retentionDays !== undefined && Number.isFinite(retentionDays) && retentionDays > 0) {
      PeripheralTraceMaintenanceService.retentionDays = Math.floor(retentionDays)
    }
    if (maxEntries !== undefined && Number.isFinite(maxEntries) && maxEntries > 0) {
      PeripheralTraceMaintenanceService.maxEntries = Math.floor(maxEntries)
    }
    return PeripheralTraceMaintenanceService.reconcileStorageConfig()
  }

  static getRetentionConfig(): TraceRetentionConfig {
    return {
      retentionDays: PeripheralTraceMaintenanceService.retentionDays,
      maxEntries: PeripheralTraceMaintenanceService.maxEntries
    }
  }

  static async appendEntries(records: PeripheralTraceRecord[]): Promise<boolean> {
    try {
      if (records.length === 0) {
        return true
      }
      if (!PeripheralTraceEntryRepository.isReady()) {
        return false
      }
      let normalized: PeripheralTraceRecord[] = []
      for (let item of records) {
        if (!item) {
          continue
        }
        normalized.push(PeripheralTraceMaintenanceService.normalizeRecord(item))
      }
      if (normalized.length === 0) {
        return true
      }
      let saved = await PeripheralTraceEntryRepository.upsertBatch(normalized)
      if (!saved) {
        return false
      }
      let reconciled = await PeripheralTraceMaintenanceService.reconcileStorageConfig()
      if (!reconciled) {
        return false
      }
      return true
    } catch (err) {
      LogUtils.error(TAG, `appendEntries failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static async reconcileStorageConfig(): Promise<boolean> {
    try {
      if (!PeripheralTraceEntryRepository.isReady()) {
        return false
      }
      let now = PeripheralTraceMaintenanceService.nowProvider()
      let retentionMs = PeripheralTraceMaintenanceService.retentionDays * 24 * 60 * 60 * 1000
      let cutoff = now - retentionMs
      let deletedExpired = await PeripheralTraceEntryRepository.deleteExpired(cutoff)
      if (!deletedExpired) {
        return false
      }
      let trimmed = await PeripheralTraceEntryRepository.trimToMaxEntries(PeripheralTraceMaintenanceService.maxEntries)
      if (!trimmed) {
        return false
      }
      PeripheralTraceEntryRepository.notifyChanged()
      return true
    } catch (err) {
      LogUtils.error(TAG, `reconcileStorageConfig failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static async clearAll(): Promise<boolean> {
    try {
      if (!PeripheralTraceEntryRepository.isReady()) {
        return false
      }
      let cleared = await PeripheralTraceEntryRepository.clearAll()
      if (!cleared) {
        return false
      }
      PeripheralTraceEntryRepository.notifyChanged()
      return true
    } catch (err) {
      LogUtils.error(TAG, `clearAll failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  private static normalizeRecord(record: PeripheralTraceRecord): PeripheralTraceRecord {
    let now = PeripheralTraceMaintenanceService.nowProvider()
    let occurAt = Number.isFinite(record.occurAt) && record.occurAt > 0 ? Math.floor(record.occurAt) : now
    let collectAt = Number.isFinite(record.collectAt) && record.collectAt > 0 ? Math.floor(record.collectAt) : now
    let result = PeripheralTraceMaintenanceService.normalizeResult(record.result)
    let action = PeripheralTraceMaintenanceService.normalizeAction(record.action)
    let decision = PeripheralTraceMaintenanceService.normalizeDecision(record.decision)
    let source = PeripheralTraceMaintenanceService.normalizeSource(record.source)
    return {
      recordId: record.recordId && record.recordId.length > 0 ?
        record.recordId :
        `ptr_${collectAt}_${Math.random().toString(36).substring(2, 8)}`,
      occurAt: occurAt,
      collectAt: collectAt,
      deviceName: record.deviceName || 'Unknown Device',
      deviceType: record.deviceType || PeripheralType.USB_OTHER,
      deviceId: PeripheralTraceMaintenanceService.normalizeDeviceId(record.deviceId),
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
    if (result === LogEventResult.SUCCESS || result === LogEventResult.BLOCKED || result === LogEventResult.FAILED) {
      return result
    }
    return LogEventResult.FAILED
  }

  private static normalizeAction(action: PeripheralRecordAction): PeripheralRecordAction {
    if (action === 'connect' || action === 'disconnect' || action === 'discover' || action === 'intercept' || action === 'unknown') {
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
}
