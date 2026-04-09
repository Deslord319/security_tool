import { beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { LogEntry, LogEventResult, LogEventType } from '../../main/ets/models/DataModels'
import { LogEntryNormalizer } from '../../main/ets/services/log-manage/mapper/LogEntryNormalizer'
import { LogQuery } from '../../main/ets/services/log-manage/common/LogManagePorts'
import { LogRepository } from '../../main/ets/services/log-manage/repository/LogRepository'

interface LogRepositoryContractAccess {
  context: common.UIAbilityContext | null
  logEntries: LogEntry[]
  isInitialized: boolean
  initializedContextDir: string
  initPromise: Promise<Object> | null
  nextListenerId: number
  listeners: Map<number, () => void>
  lastPersistTruncateWarnAt: number
  notifyChanged(): void
  cleanExpiredEntries(): number
  buildPersistPayload(): string
  matchesQuery(entry: LogEntry, query: LogQuery): boolean
}

function createEntry(
  id: string,
  detail: string,
  result: LogEventResult,
  eventType: LogEventType = LogEventType.FILE
): LogEntry {
  const entry: LogEntry = {
    id,
    timestamp: Date.now(),
    eventType: eventType,
    detail,
    result
  }
  return entry
}

export default function logRepositoryTest() {
  describe('LogRepository Related Helpers', () => {
    let access: LogRepositoryContractAccess

    beforeEach(() => {
      let rawRepository = LogRepository as Object
      access = rawRepository as LogRepositoryContractAccess
      access.context = null
      access.logEntries = []
      access.isInitialized = false
      access.initializedContextDir = ''
      access.initPromise = null
      access.nextListenerId = 1
      access.listeners = new Map()
      access.lastPersistTruncateWarnAt = 0
    })

    it('should sanitize entries and keep valid values', 0, () => {
      let entries = LogEntryNormalizer.sanitizeEntries([
        createEntry('1', 'alpha', LogEventResult.SUCCESS),
        createEntry('2', 'beta', LogEventResult.BLOCKED, LogEventType.PERMISSION)
      ], 10)

      expect(entries.length).assertEqual(2)
      expect(entries[0].id).assertEqual('1')
      expect(entries[1].eventType).assertEqual(LogEventType.PERMISSION)
    })

    it('should normalize overlong or invalid append values', 0, () => {
      let longText = 'x'.repeat(1100)
      let entries = LogEntryNormalizer.normalizeEntriesForAppend([
        createEntry(' ', longText, 999 as LogEventResult, 999 as LogEventType)
      ])

      expect(entries.length).assertEqual(1)
      expect(entries[0].eventType).assertEqual(LogEventType.FILE)
      expect(entries[0].result).assertEqual(LogEventResult.SUCCESS)
      expect(entries[0].detail.length <= 1027).assertTrue()
    })

    it('should reject append before repository initialization', 0, async () => {
      let result = await LogRepository.addEntries([
        createEntry('1', 'alpha', LogEventResult.SUCCESS)
      ])

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('not_initialized')
    })

    it('should append normalized entries and notify listeners after initialization', 0, async () => {
      let notified = 0
      access.isInitialized = true
      LogRepository.addChangeListener(() => {
        notified++
      })

      let result = await LogRepository.addEntries([
        createEntry('1', 'alpha', LogEventResult.SUCCESS),
        createEntry('2', 'beta', LogEventResult.BLOCKED, LogEventType.PERMISSION)
      ])

      expect(result.success).assertTrue()
      expect(access.logEntries.length).assertEqual(2)
      expect(access.logEntries.some((entry: LogEntry) => entry.id === '1')).assertTrue()
      expect(access.logEntries.some((entry: LogEntry) => entry.id === '2')).assertTrue()
      expect(notified).assertEqual(1)
    })

    it('should build snapshot and statistics from in-memory entries', 0, () => {
      let now = Date.now()
      access.logEntries = [
        {
          id: 'a',
          timestamp: now,
          eventType: LogEventType.FILE,
          detail: 'blocked file write',
          result: LogEventResult.BLOCKED,
          processName: 'alpha'
        },
        {
          id: 'b',
          timestamp: now - 2 * 24 * 60 * 60 * 1000,
          eventType: LogEventType.PERMISSION,
          detail: 'allowed permission',
          result: LogEventResult.SUCCESS,
          filePath: '/data/demo'
        }
      ] as LogEntry[]

      let snapshot = LogRepository.snapshot({
        eventTypes: [LogEventType.FILE],
        results: [LogEventResult.BLOCKED],
        keyword: 'file'
      })
      let stats = LogRepository.getStatistics()

      expect(snapshot.totalCount).assertEqual(2)
      expect(snapshot.todayCount).assertEqual(1)
      expect(snapshot.blockedCount).assertEqual(1)
      expect(snapshot.entries.length).assertEqual(1)
      expect(stats.byType.get(LogEventType.FILE) ?? 0).assertEqual(1)
    })

    it('should clear entries successfully without storage backend', 0, async () => {
      access.logEntries = [
        createEntry('1', 'alpha', LogEventResult.SUCCESS)
      ]

      let result = await LogRepository.clear()

      expect(result.success).assertTrue()
      expect(access.logEntries.length).assertEqual(0)
    })

    it('should reconcile expired entries after initialization', 0, async () => {
      access.isInitialized = true
      access.logEntries = [
        createEntry('recent', 'recent entry', LogEventResult.SUCCESS),
        {
          id: 'expired',
          timestamp: Date.now() - 40 * 24 * 60 * 60 * 1000,
          eventType: LogEventType.FILE,
          detail: 'expired entry',
          result: LogEventResult.SUCCESS
        }
      ] as LogEntry[]

      let result = await LogRepository.reconcileStorageConfig()

      expect(result.success).assertTrue()
      expect(access.logEntries.length <= 2).assertTrue()
      expect(access.logEntries.some((entry: LogEntry) => entry.id === 'recent')).assertTrue()
    })

    it('should match query by keyword and result across fields', 0, () => {
      let entry: LogEntry = {
        id: 'kw',
        timestamp: Date.now(),
        eventType: LogEventType.PERMISSION,
        detail: 'permission denied for app',
        processName: 'demo-process',
        filePath: '/data/demo/file.txt',
        result: LogEventResult.BLOCKED
      }

      expect(access.matchesQuery(entry, { keyword: 'process' })).assertTrue()
      expect(access.matchesQuery(entry, { keyword: 'file.txt' })).assertTrue()
      expect(access.matchesQuery(entry, { keyword: 'missing' })).assertFalse()
      expect(access.matchesQuery(entry, { results: [LogEventResult.SUCCESS] })).assertFalse()
    })

    it('should truncate oversized persist payload to a safe fallback', 0, () => {
      access.logEntries = [
        createEntry('1', 'x'.repeat(1024 * 1024 + 32), LogEventResult.SUCCESS)
      ]

      let payload = access.buildPersistPayload()

      expect(payload).assertEqual('[]')
    })
  })
}
