import { describe, expect, it } from '@ohos/hypium'

import {
  LogDetailTableRow,
  LogEntry,
  LogEventType
} from '../../main/ets/models/LogModels'
import { LogEntryNormalizer } from '../../main/ets/services/log-manage/mapper/LogEntryNormalizer'
import {
  buildExistingEntryIdsQuery,
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

    it('should build one existing-id query for up to 1000 import entries', 0, () => {
      let entryIds: string[] = []
      for (let index = 0; index < 1000; index++) {
        entryIds.push(`entry-${index}`)
      }

      let query = buildExistingEntryIdsQuery(entryIds)

      expect(query.sql.indexOf('SELECT record_id FROM log_entries WHERE record_id IN (') === 0).assertTrue()
      expect(query.args.length).assertEqual(1000)
      expect(query.args[0] as string).assertEqual('entry-0')
      expect(query.args[999] as string).assertEqual('entry-999')
    })

    it('should reject an import existing-id query larger than 1000', 0, () => {
      let entryIds: string[] = []
      for (let index = 0; index < 1001; index++) {
        entryIds.push(`entry-${index}`)
      }
      let thrown = false

      try {
        buildExistingEntryIdsQuery(entryIds)
      } catch (_) {
        thrown = true
      }

      expect(thrown).assertTrue()
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
