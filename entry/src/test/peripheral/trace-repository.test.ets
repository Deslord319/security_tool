import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import {
  LogEventResult,
  PeripheralMatchedPolicyKind,
  PeripheralTraceQuery,
  PeripheralTraceRecord,
  PeripheralType
} from '../../main/ets/models/DataModels'
import { PeripheralTraceEntryRepository } from '../../main/ets/services/peripheral/connection-record/PeripheralTraceEntryRepository'
import { PeripheralTraceMaintenanceService } from '../../main/ets/services/peripheral/connection-record/PeripheralTraceMaintenanceService'

const DEFAULT_RETENTION_DAYS = 180
const DEFAULT_MAX_ENTRIES = 200000
const TEST_CONTEXT = {} as common.UIAbilityContext

interface TraceRecordOverrides {
  collectAt?: number
  deviceName?: string
  deviceType?: PeripheralType
  deviceId?: string
  action?: 'connect' | 'disconnect' | 'discover' | 'intercept' | 'unknown'
  decision?: 'allow' | 'deny' | 'unknown'
  result?: LogEventResult
  source?: 'runtime_event' | 'audit_event' | 'policy_snapshot'
  summary?: string
  detail?: string
  processName?: string
  matchedPolicyKind?: PeripheralMatchedPolicyKind
}

function createTraceRecord(recordId: string, occurAt: number, extra?: TraceRecordOverrides): PeripheralTraceRecord {
  let record: PeripheralTraceRecord = {
    recordId,
    occurAt,
    collectAt: occurAt + 1,
    deviceName: `Device-${recordId}`,
    deviceType: PeripheralType.USB_STORAGE,
    deviceId: `VID:${recordId} PID:${recordId}`,
    action: 'connect',
    decision: 'allow',
    result: LogEventResult.SUCCESS,
    source: 'runtime_event',
    summary: `summary-${recordId}`
  }
  if (extra) {
    if (extra.collectAt !== undefined) {
      record.collectAt = extra.collectAt
    }
    if (extra.deviceName !== undefined) {
      record.deviceName = extra.deviceName
    }
    if (extra.deviceType !== undefined) {
      record.deviceType = extra.deviceType
    }
    if (extra.deviceId !== undefined) {
      record.deviceId = extra.deviceId
    }
    if (extra.action !== undefined) {
      record.action = extra.action
    }
    if (extra.decision !== undefined) {
      record.decision = extra.decision
    }
    if (extra.result !== undefined) {
      record.result = extra.result
    }
    if (extra.source !== undefined) {
      record.source = extra.source
    }
    if (extra.summary !== undefined) {
      record.summary = extra.summary
    }
    if (extra.detail !== undefined) {
      record.detail = extra.detail
    }
    if (extra.processName !== undefined) {
      record.processName = extra.processName
    }
    if (extra.matchedPolicyKind !== undefined) {
      record.matchedPolicyKind = extra.matchedPolicyKind
    }
  }
  return record
}

function normalizeDeviceId(deviceId?: string): string {
  let value = (deviceId || '').trim()
  if (value.length === 0) {
    return 'UNKNOWN'
  }
  return value.replace(/\s+/g, ' ').toUpperCase()
}

function sortRecords(records: PeripheralTraceRecord[]): PeripheralTraceRecord[] {
  return records.slice().sort((left: PeripheralTraceRecord, right: PeripheralTraceRecord) => {
    if (left.occurAt === right.occurAt) {
      return right.collectAt - left.collectAt
    }
    return right.occurAt - left.occurAt
  })
}

function filterRecords(records: PeripheralTraceRecord[], query?: PeripheralTraceQuery, limit?: number, offset?: number): PeripheralTraceRecord[] {
  let filtered = sortRecords(records).filter((record: PeripheralTraceRecord) => {
    if (query?.startTime !== undefined && record.occurAt < query.startTime) {
      return false
    }
    if (query?.endTime !== undefined && record.occurAt > query.endTime) {
      return false
    }
    if (query?.deviceId && normalizeDeviceId(record.deviceId) !== normalizeDeviceId(query.deviceId)) {
      return false
    }
    if (query?.deviceTypes && query.deviceTypes.length > 0 && !query.deviceTypes.includes(record.deviceType)) {
      return false
    }
    if (query?.actions && query.actions.length > 0 && !query.actions.includes(record.action)) {
      return false
    }
    if (query?.decisions && query.decisions.length > 0 && !query.decisions.includes(record.decision)) {
      return false
    }
    if (query?.results && query.results.length > 0 && !query.results.includes(record.result)) {
      return false
    }
    if (query?.sources && query.sources.length > 0 && !query.sources.includes(record.source)) {
      return false
    }
    if (query?.keyword && query.keyword.trim().length > 0) {
      let keyword = query.keyword.trim().toLowerCase()
      let joined = `${record.deviceName} ${record.deviceId} ${record.summary} ${record.detail ?? ''} ${record.processName ?? ''}`.toLowerCase()
      if (joined.indexOf(keyword) < 0) {
        return false
      }
    }
    return true
  })
  if (offset !== undefined && offset > 0) {
    filtered = filtered.slice(offset)
  }
  if (limit !== undefined) {
    filtered = filtered.slice(0, limit)
  }
  return filtered
}

export default function peripheralTraceRepositoryTest() {
  describe('PeripheralTraceStorage', () => {
    let now: number
    let mockKit: MockKit
    let store: PeripheralTraceRecord[]

    beforeEach(async () => {
      now = Date.now()
      store = []
      mockKit = new MockKit()

      let initMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.init)
      let isReadyMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.isReady)
      let upsertMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.upsertBatch)
      let listMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.listByQuery)
      let countMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.countByQuery)
      let deleteExpiredMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.deleteExpired)
      let trimMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.trimToMaxEntries)
      let clearAllMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.clearAll)

      when(initMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(true))
      when(isReadyMock)().afterReturn(true)
      when(upsertMock)(ArgumentMatchers.any).afterAction((records: PeripheralTraceRecord[]) => {
        for (let record of records) {
          let index = store.findIndex((item: PeripheralTraceRecord) => item.recordId === record.recordId)
          if (index >= 0) {
            store[index] = record
          } else {
            store.push(record)
          }
        }
        return Promise.resolve(true)
      })
      when(listMock)(ArgumentMatchers.any).afterAction((query?: PeripheralTraceQuery, limit?: number, offset?: number) => {
        return Promise.resolve(filterRecords(store, query, limit, offset))
      })
      when(countMock)(ArgumentMatchers.any).afterAction((query?: PeripheralTraceQuery) => {
        return Promise.resolve(filterRecords(store, query).length)
      })
      when(deleteExpiredMock)(ArgumentMatchers.any).afterAction((cutoffTimestamp: number) => {
        store = store.filter((record: PeripheralTraceRecord) => record.occurAt >= cutoffTimestamp)
        return Promise.resolve(true)
      })
      when(trimMock)(ArgumentMatchers.any).afterAction((maxEntries: number) => {
        store = sortRecords(store).slice(0, maxEntries)
        return Promise.resolve(true)
      })
      when(clearAllMock)().afterAction(() => {
        store = []
        return Promise.resolve(true)
      })

      await PeripheralTraceMaintenanceService.initialize(TEST_CONTEXT)
      await PeripheralTraceMaintenanceService.configure(DEFAULT_RETENTION_DAYS, DEFAULT_MAX_ENTRIES)
      await PeripheralTraceMaintenanceService.clearAll()
    })

    afterEach(() => {
      mockKit.clearAll()
    })

    it('should append and query normalized records', 0, async () => {
      let ok = await PeripheralTraceMaintenanceService.appendEntries([createTraceRecord('0001', now, {
        deviceId: ' vid:0001   pid:0001 ',
        matchedPolicyKind: 'default_allow'
      })])
      let records = await PeripheralTraceEntryRepository.listByQuery()

      expect(ok.success).assertTrue()
      expect(records.length).assertEqual(1)
      expect(records[0].deviceId).assertEqual('VID:0001 PID:0001')
      expect(records[0].matchedPolicyKind).assertEqual('default_allow')
    })

    it('should preserve bluetooth discovery action during normalization', 0, async () => {
      let ok = await PeripheralTraceMaintenanceService.appendEntries([createTraceRecord('bt-discover', now, {
        deviceType: PeripheralType.BLUETOOTH,
        action: 'discover',
        decision: 'unknown',
        matchedPolicyKind: 'bluetooth_discovery'
      })])
      let records = await PeripheralTraceEntryRepository.listByQuery()

      expect(ok.success).assertTrue()
      expect(records.length).assertEqual(1)
      expect(records[0].action).assertEqual('discover')
    })

    it('should normalize invalid results to failed', 0, async () => {
      let invalidResultRecord = createTraceRecord('invalid-result', now)
      invalidResultRecord.result = 99 as LogEventResult

      let ok = await PeripheralTraceMaintenanceService.appendEntries([invalidResultRecord])
      let records = await PeripheralTraceEntryRepository.listByQuery()

      expect(ok.success).assertTrue()
      expect(records.length).assertEqual(1)
      expect(records[0].result).assertEqual(LogEventResult.FAILED)
    })

    it('should filter records by query dimensions and pagination', 0, async () => {
      const base = Date.now()
      await PeripheralTraceMaintenanceService.appendEntries([
        createTraceRecord('runtime-usb', base + 500, {
          deviceName: 'Alpha USB',
          deviceId: 'VID:0001 PID:0001',
          deviceType: PeripheralType.USB_STORAGE,
          action: 'connect',
          decision: 'allow',
          result: LogEventResult.SUCCESS,
          source: 'runtime_event',
          detail: 'mounted alpha volume',
          processName: 'usb-service'
        }),
        createTraceRecord('audit-bt', base + 400, {
          deviceName: 'Beta Headset',
          deviceId: 'MAC: AA:BB:CC:DD:EE:FF',
          deviceType: PeripheralType.BLUETOOTH,
          action: 'disconnect',
          decision: 'deny',
          result: LogEventResult.BLOCKED,
          source: 'audit_event',
          summary: 'beta blocked',
          detail: 'audit detail'
        }),
        createTraceRecord('snapshot-usb', base + 300, {
          deviceName: 'Gamma Camera',
          deviceId: 'VID:0002 PID:0002',
          deviceType: PeripheralType.USB_CAMERA,
          action: 'intercept',
          decision: 'unknown',
          result: LogEventResult.FAILED,
          source: 'policy_snapshot',
          summary: 'gamma snapshot'
        })
      ])

      expect((await PeripheralTraceEntryRepository.listByQuery({ deviceId: ' vid:0001   pid:0001 ' })).length).assertEqual(1)
      expect((await PeripheralTraceEntryRepository.listByQuery({ deviceTypes: [PeripheralType.BLUETOOTH] })).length).assertEqual(1)
      expect((await PeripheralTraceEntryRepository.listByQuery({ actions: ['disconnect'] })).length).assertEqual(1)
      expect((await PeripheralTraceEntryRepository.listByQuery({ decisions: ['deny'] })).length).assertEqual(1)
      expect((await PeripheralTraceEntryRepository.listByQuery({ results: [LogEventResult.FAILED] })).length).assertEqual(1)
      expect((await PeripheralTraceEntryRepository.listByQuery({ sources: ['policy_snapshot'] })).length).assertEqual(1)
      expect((await PeripheralTraceEntryRepository.listByQuery({ keyword: 'alpha volume' })).length).assertEqual(1)
      expect((await PeripheralTraceEntryRepository.listByQuery({ startTime: base + 350, endTime: base + 500 })).length).assertEqual(2)

      let paged = await PeripheralTraceEntryRepository.listByQuery(undefined, 1, 1)
      expect(paged.length).assertEqual(1)
      expect(paged[0].recordId).assertEqual('audit-bt')
    })

    it('should report aggregated stats for filtered records', 0, async () => {
      const base = Date.now()
      await PeripheralTraceMaintenanceService.appendEntries([
        createTraceRecord('connect-allow', base + 500, { action: 'connect', decision: 'allow', source: 'runtime_event' }),
        createTraceRecord('disconnect-deny', base + 400, { action: 'disconnect', decision: 'deny', source: 'audit_event' }),
        createTraceRecord('intercept-unknown', base + 300, { action: 'intercept', decision: 'unknown', source: 'policy_snapshot' })
      ])

      let stats = await PeripheralTraceEntryRepository.getStatistics()
      let runtimeStats = await PeripheralTraceEntryRepository.getStatistics({ sources: ['runtime_event'] })

      expect(stats.total).assertEqual(3)
      expect(stats.runtimeCount).assertEqual(1)
      expect(stats.auditCount).assertEqual(1)
      expect(stats.snapshotCount).assertEqual(1)
      expect(runtimeStats.total).assertEqual(1)
    })

    it('should notify listeners on append and clear and stop after removal', 0, async () => {
      let notificationCount = 0
      let listenerId = PeripheralTraceEntryRepository.addChangeListener(() => {
        notificationCount++
      })

      await PeripheralTraceMaintenanceService.appendEntries([createTraceRecord('listener-1', now)])
      let cleared = await PeripheralTraceMaintenanceService.clearAll()
      PeripheralTraceEntryRepository.removeChangeListener(listenerId)
      await PeripheralTraceMaintenanceService.appendEntries([createTraceRecord('listener-2', now + 100)])

      expect(cleared.success).assertTrue()
      expect(notificationCount).assertEqual(2)
    })

    it('should update retention config and cleanup expired or overflow records', 0, async () => {
      let cleanupNow = Date.now()
      await PeripheralTraceMaintenanceService.appendEntries([
        createTraceRecord('expired', cleanupNow - 10 * 24 * 60 * 60 * 1000),
        createTraceRecord('recent-a', cleanupNow - 1 * 24 * 60 * 60 * 1000),
        createTraceRecord('recent-b', cleanupNow - 12 * 60 * 60 * 1000)
      ])

      await PeripheralTraceMaintenanceService.configure(180, 200000)
      await PeripheralTraceMaintenanceService.configure(2, 5)
      let config = PeripheralTraceMaintenanceService.getRetentionConfig()
      let retainedRecords = await PeripheralTraceEntryRepository.listByQuery()
      let beforeTrim = await PeripheralTraceEntryRepository.countByQuery()
      await PeripheralTraceMaintenanceService.configure(undefined, 1)
      let records = await PeripheralTraceEntryRepository.listByQuery()

      expect(config.retentionDays).assertEqual(2)
      expect(config.maxEntries).assertEqual(5)
      expect(retainedRecords.length).assertEqual(2)
      expect(beforeTrim - records.length).assertEqual(1)
      expect(records[0].recordId).assertEqual('recent-b')
    })
  })
}
