import { describe, expect, it } from '@ohos/hypium'
import {
  LogEntry,
  LogEventResult,
  LogEventType
} from '../../main/ets/models/DataModels'
import { LogEntryNormalizer } from '../../main/ets/services/log-manage/mapper/LogEntryNormalizer'

class InvalidLogEntry implements LogEntry {
  id: string = '  '
  timestamp: number = -1
  eventType: LogEventType = 999 as LogEventType
  detail: string = 'detail'
  result: LogEventResult = 999 as LogEventResult
}

function createEntry(
  id: string = 'entry-1',
  detail: string = 'detail',
  result: LogEventResult = LogEventResult.SUCCESS,
  eventType: LogEventType = LogEventType.FILE,
  timestamp: number = Date.now()
): LogEntry {
  const entry: LogEntry = {
    id: id,
    timestamp: timestamp,
    eventType: eventType,
    detail: detail,
    result: result
  }
  return entry
}

function createInvalidLogEntry(): LogEntry {
  return new InvalidLogEntry()
}

function createUndefinedEntry(): LogEntry {
  return undefined as never as LogEntry
}

export default function entryNormalizerTest() {
  describe('LogEntryNormalizer', () => {
    it('should normalize invalid storage config values', 0, () => {
      expect(LogEntryNormalizer.normalizeMaxEntries(-1) > 0).assertTrue()
      expect(LogEntryNormalizer.normalizeRetentionDays(0) > 0).assertTrue()
      expect(LogEntryNormalizer.normalizeRetentionDays(5000)).assertEqual(3650)
    })

    it('should sanitize invalid entry fields into stable business values', 0, () => {
      let normalized = LogEntryNormalizer.normalizeEntry(createInvalidLogEntry())

      expect(normalized.id.length > 0).assertTrue()
      expect(normalized.timestamp >= 0).assertTrue()
      expect(normalized.eventType).assertEqual(LogEventType.FILE)
      expect(normalized.result).assertEqual(LogEventResult.SUCCESS)
    })

    it('should reverse append batches and ignore invalid items', 0, () => {
      let first = createEntry('1', 'alpha')
      let second = createEntry('2', 'beta')

      let result = LogEntryNormalizer.normalizeEntriesForAppend([
        first,
        createUndefinedEntry(),
        second
      ])

      expect(result.length).assertEqual(2)
      expect(result[0].id).assertEqual('2')
      expect(result[1].id).assertEqual('1')
    })

    it('should sanitize persisted entries within max limit', 0, () => {
      let entries: LogEntry[] = [
        createEntry('1'),
        createUndefinedEntry(),
        createEntry('2'),
        createEntry('3')
      ]

      let result = LogEntryNormalizer.sanitizeEntries(entries, 2)

      expect(result.length).assertEqual(2)
      expect(result[0].id).assertEqual('1')
      expect(result[1].id).assertEqual('2')
    })
  })
}
