import { describe, expect, it } from '@ohos/hypium'
import {
  LogEntry,
  LogEventResult,
  LogEventType
} from '../../main/ets/models/DataModels'
import { LogEntryNormalizer } from '../../main/ets/services/log-manage/mapper/LogEntryNormalizer'

function createEntry(partial?: Partial<LogEntry>): LogEntry {
  return {
    id: 'entry-1',
    timestamp: Date.now(),
    eventType: LogEventType.FILE,
    detail: 'detail',
    result: LogEventResult.SUCCESS,
    ...partial
  }
}

export default function entryNormalizerTest() {
  describe('LogEntryNormalizer', () => {
    it('should normalize invalid storage config values', 0, () => {
      expect(LogEntryNormalizer.normalizeMaxEntries(-1) > 0).assertTrue()
      expect(LogEntryNormalizer.normalizeRetentionDays(0) > 0).assertTrue()
      expect(LogEntryNormalizer.normalizeRetentionDays(5000)).assertEqual(3650)
    })

    it('should sanitize invalid entry fields into stable business values', 0, () => {
      let normalized = LogEntryNormalizer.normalizeEntry(createEntry({
        id: '  ',
        timestamp: -1,
        eventType: 999 as LogEventType,
        result: 999 as LogEventResult
      }))

      expect(normalized.id.length > 0).assertTrue()
      expect(normalized.timestamp >= 0).assertTrue()
      expect(normalized.eventType).assertEqual(LogEventType.FILE)
      expect(normalized.result).assertEqual(LogEventResult.SUCCESS)
    })

    it('should reverse append batches and ignore invalid items', 0, () => {
      let first = createEntry({ id: '1', detail: 'alpha' })
      let second = createEntry({ id: '2', detail: 'beta' })

      let result = LogEntryNormalizer.normalizeEntriesForAppend([
        first,
        undefined as unknown as LogEntry,
        second
      ])

      expect(result.length).assertEqual(2)
      expect(result[0].id).assertEqual('2')
      expect(result[1].id).assertEqual('1')
    })

    it('should sanitize persisted entries within max limit', 0, () => {
      let entries: LogEntry[] = [
        createEntry({ id: '1' }),
        undefined as unknown as LogEntry,
        createEntry({ id: '2' }),
        createEntry({ id: '3' })
      ]

      let result = LogEntryNormalizer.sanitizeEntries(entries, 2)

      expect(result.length).assertEqual(2)
      expect(result[0].id).assertEqual('1')
      expect(result[1].id).assertEqual('2')
    })
  })
}
