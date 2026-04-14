import { describe, expect, it } from '@ohos/hypium'
import {
  LogDetailTableRow,
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
  timestamp: number = Date.now(),
  detailRows?: LogDetailTableRow[]
): LogEntry {
  const entry: LogEntry = {
    id: id,
    timestamp: timestamp,
    eventType: eventType,
    detail: detail,
    result: result,
    detailRows: detailRows
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

    it('should preserve append batch order and ignore invalid items', 0, () => {
      let first = createEntry('1', 'alpha')
      let second = createEntry('2', 'beta')

      let result = LogEntryNormalizer.normalizeEntriesForAppend([
        first,
        createUndefinedEntry(),
        second
      ])

      expect(result.length).assertEqual(2)
      expect(result[0].id).assertEqual('1')
      expect(result[1].id).assertEqual('2')
    })

    it('should normalize detail rows and drop empty values', 0, () => {
      let longText = 'x'.repeat(1100)
      let normalized = LogEntryNormalizer.normalizeEntry(createEntry(
        'entry-3',
        'detail',
        LogEventResult.SUCCESS,
        LogEventType.FILE,
        Date.now(),
        [
          {
            key: '  sourceEventId  ',
            label: '  事件 ID  ',
            value: '  12345  '
          },
          {
            key: ' ',
            label: 'bad',
            value: 'bad'
          },
          {
            key: 'long',
            label: 'long label',
            value: longText
          }
        ]
      ))

      expect(normalized.detailRows !== undefined).assertTrue()
      expect(normalized.detailRows!.length).assertEqual(2)
      expect(normalized.detailRows![0].key).assertEqual('sourceEventId')
      expect(normalized.detailRows![0].label).assertEqual('事件 ID')
      expect(normalized.detailRows![0].value).assertEqual('12345')
      expect(normalized.detailRows![1].value.length <= 1027).assertTrue()
    })

  })
}
