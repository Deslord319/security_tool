import { beforeEach, describe, expect, it } from '@ohos/hypium'
import { LogEntry, LogEventResult, LogEventType } from '../../main/ets/models/DataModels'
import { LogEntryNormalizer } from '../../main/ets/services/log-manage/mapper/LogEntryNormalizer'
import { LogConfigRepository } from '../../main/ets/services/log-manage/repository/LogConfigRepository'
import { LogRepository } from '../../main/ets/services/log-manage/repository/LogRepository'

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
  describe('LogRepository', () => {
    beforeEach(() => {
      LogConfigRepository.resetForTest()
      LogRepository.resetForTest()
    })

    it('should reject append before repository initialization', 0, async (done: Function) => {
      LogRepository.resetForTest([], false)

      let result = await LogRepository.addEntries([createEntry('1', 'alpha', LogEventResult.SUCCESS)])

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('not_initialized')
      done()
    })

    it('should filter query and snapshot with stable totals', 0, (done: Function) => {
      LogRepository.resetForTest([
        createEntry('1', 'file alpha', LogEventResult.SUCCESS),
        createEntry('2', 'permission beta', LogEventResult.BLOCKED, LogEventType.PERMISSION),
        createEntry('3', 'file gamma', LogEventResult.FAILED)
      ])

      let querySnapshot = LogRepository.snapshot({ keyword: 'beta' })
      let snapshot = LogRepository.snapshot({ results: [LogEventResult.FAILED] })

      expect(querySnapshot.entries.length).assertEqual(1)
      expect(querySnapshot.entries[0].id).assertEqual('2')
      expect(snapshot.totalCount).assertEqual(3)
      expect(snapshot.blockedCount).assertEqual(1)
      expect(snapshot.entries.length).assertEqual(1)
      expect(snapshot.entries[0].id).assertEqual('3')
      done()
    })

    it('should trim old entries when reconciling storage config', 0, async (done: Function) => {
      LogConfigRepository.setStorageConfigForTest({ maxLocalEntries: 2, retentionDays: 30 })
      LogRepository.resetForTest([
        createEntry('1', 'first', LogEventResult.SUCCESS),
        createEntry('2', 'second', LogEventResult.SUCCESS),
        createEntry('3', 'third', LogEventResult.SUCCESS)
      ])

      let result = await LogRepository.reconcileStorageConfig()
      let snapshot = LogRepository.snapshot()

      expect(result.success).assertTrue()
      expect(snapshot.totalCount).assertEqual(2)
      expect(snapshot.entries[0].id).assertEqual('1')
      expect(snapshot.entries[1].id).assertEqual('2')
      done()
    })

    it('should sanitize appended entries using normalizer rules', 0, async (done: Function) => {
      LogConfigRepository.setStorageConfigForTest({ maxLocalEntries: 10, retentionDays: 30 })
      LogRepository.resetForTest([], true)
      let longText = 'x'.repeat(1100)

      let result = await LogRepository.addEntries([
        createEntry(' ', longText, 999 as LogEventResult, 999 as LogEventType)
      ])
      let snapshot = LogRepository.snapshot()

      expect(result.success).assertTrue()
      expect(snapshot.entries.length).assertEqual(1)
      expect(snapshot.entries[0].eventType).assertEqual(LogEventType.FILE)
      expect(snapshot.entries[0].result).assertEqual(LogEventResult.SUCCESS)
      expect(snapshot.entries[0].detail.length <= 1027).assertTrue()
      done()
    })
  })
}
