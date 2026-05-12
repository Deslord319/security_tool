import { describe, expect, it } from '@ohos/hypium'

import {
  LogDetailTableRow,
  LogEntry,
  LogEventType
} from '../../main/ets/models/LogModels'
import { LogEntryNormalizer } from '../../main/ets/services/log-manage/mapper/LogEntryNormalizer'
import {
  buildLogEntryWhereClause,
  deserializeLogEntryExtraData,
  LogEntryRepository,
  serializeLogEntryExtraData
} from '../../main/ets/services/log-manage/repository/LogEntryRepository'

export default function logEntryRepositoryTest() {
  describe('LogEntryRepository', () => {
    it('should expose repository instance in unit environment', 0, () => {
      expect(LogEntryRepository !== null).assertTrue()
    })

    it('should serialize and restore detail rows in extra json payload', 0, () => {
      let detailRows: LogDetailTableRow[] = [
        {
          key: 'sourceEventId',
          label: '事件 ID',
          value: '268435712'
        }
      ]
      let entry: LogEntry = {
        id: 'entry-1',
        timestamp: Date.now(),
        eventType: LogEventType.FILE,
        detail: 'detail',
        detailRows: detailRows
      }

      let payload = serializeLogEntryExtraData(entry)
      expect(payload !== null).assertTrue()

      let restored = deserializeLogEntryExtraData(payload ?? undefined)
      expect(restored.detailRows !== undefined).assertTrue()
      expect(restored.detailRows!.length).assertEqual(1)
      expect(restored.detailRows![0].key).assertEqual('sourceEventId')
      expect(restored.detailRows![0].label).assertEqual('事件 ID')
      expect(restored.detailRows![0].value).assertEqual('268435712')
    })

    it('should build timestamp lower bound query with existing filters', 0, () => {
      let where = buildLogEntryWhereClause({
        eventTypes: [LogEventType.FILE],
        startTimestamp: 1700000000000,
        keyword: 'Alpha'
      })

      expect(where.sql.indexOf('event_type IN (?)') >= 0).assertTrue()
      expect(where.sql.indexOf('timestamp >= ?') >= 0).assertTrue()
      expect(where.sql.indexOf('LOWER(detail) LIKE ?') >= 0).assertTrue()
      expect(where.args.length).assertEqual(5)
      expect(where.args[1] as number).assertEqual(1700000000000)
      expect(where.args[2] as string).assertEqual('%alpha%')
    })
  })

  describe('LogEntryNormalizer', () => {
    it('should normalize valid entries and keep declared event fields', 0, () => {
      let entries = LogEntryNormalizer.normalizeEntriesForAppend([
        {
          id: '1',
          timestamp: Date.now(),
          eventType: LogEventType.FILE,
          detail: 'alpha'
        },
        {
          id: '2',
          timestamp: Date.now(),
          eventType: LogEventType.PERMISSION,
          detail: 'beta'
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
          detail: longText
        }
      ])

      expect(entries.length).assertEqual(1)
      expect(entries[0].eventType).assertEqual(LogEventType.FILE)
      expect(entries[0].detail.length <= 1027).assertTrue()
      expect(entries[0].id.length > 0).assertTrue()
    })
  })
}
