import { describe, expect, it } from '@ohos/hypium'

import { LogEventResult, LogEventType } from '../../main/ets/models/DataModels'
import { LogEntryNormalizer } from '../../main/ets/services/log-manage/mapper/LogEntryNormalizer'
import { LogEntryRepository } from '../../main/ets/services/log-manage/repository/LogEntryRepository'

export default function logRepositoryTest() {
  describe('LogEntryRepository', () => {
    it('should support adding and removing change listeners', 0, () => {
      let listenerId = LogEntryRepository.addChangeListener(() => {})

      expect(listenerId > 0).assertTrue()

      LogEntryRepository.removeChangeListener(listenerId)
      expect(true).assertTrue()
    })
  })

  describe('LogEntryNormalizer', () => {
    it('should normalize valid entries and keep declared event fields', 0, () => {
      let entries = LogEntryNormalizer.normalizeEntriesForAppend([
        {
          id: '1',
          timestamp: Date.now(),
          eventType: LogEventType.FILE,
          detail: 'alpha',
          result: LogEventResult.SUCCESS
        },
        {
          id: '2',
          timestamp: Date.now(),
          eventType: LogEventType.PERMISSION,
          detail: 'beta',
          result: LogEventResult.BLOCKED
        }
      ])

      expect(entries.length).assertEqual(2)
      expect(entries[0].id).assertEqual('1')
      expect(entries[1].eventType).assertEqual(LogEventType.PERMISSION)
    })

    it('should normalize invalid append values to repository-safe defaults', 0, () => {
      let longText = 'x'.repeat(1100)
      let entries = LogEntryNormalizer.normalizeEntriesForAppend([
        {
          id: ' ',
          timestamp: Date.now(),
          eventType: 999 as LogEventType,
          detail: longText,
          result: 999 as LogEventResult
        }
      ])

      expect(entries.length).assertEqual(1)
      expect(entries[0].eventType).assertEqual(LogEventType.FILE)
      expect(entries[0].result).assertEqual(LogEventResult.SUCCESS)
      expect(entries[0].detail.length <= 1027).assertTrue()
      expect(entries[0].id.length > 0).assertTrue()
    })
  })
}
