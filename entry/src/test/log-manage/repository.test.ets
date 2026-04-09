import { describe, expect, it } from '@ohos/hypium'
import { LogEntry, LogEventResult, LogEventType } from '../../main/ets/models/DataModels'
import { LogEntryNormalizer } from '../../main/ets/services/log-manage/mapper/LogEntryNormalizer'

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
  })
}
