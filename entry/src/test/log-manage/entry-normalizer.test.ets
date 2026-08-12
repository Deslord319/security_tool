import { describe, expect, it } from '@ohos/hypium'
import { LogEntry, LogEventType } from '../../main/ets/models/LogModels'
import { LogEntryNormalizer } from '../../main/ets/services/log-manage/mapper/LogEntryNormalizer'

function createEntry(id: string = 'entry-1'): LogEntry {
  return { id, timestamp: Date.now(), eventType: LogEventType.FILE, eventKey: 'file.open', detail: 'detail' }
}

export default function entryNormalizerTest() {
  describe('LogEntryNormalizer', () => {
    it('should normalize invalid storage config values', 0, () => {
      expect(LogEntryNormalizer.normalizeMaxEntries(-1) > 0).assertTrue()
      expect(LogEntryNormalizer.normalizeMaxEntries(100001)).assertEqual(100000)
      expect(LogEntryNormalizer.normalizeRetentionDays(0) > 0).assertTrue()
      expect(LogEntryNormalizer.normalizeRetentionDays(5000)).assertEqual(3650)
    })

    it('should sanitize event key and deduplicate structured fields', 0, () => {
      const entry = createEntry(' ')
      entry.eventKey = ' '
      entry.fields = [
        { key: ' object.file_path ', value: ' /data/a.txt ' },
        { key: 'object.file_path', value: '/data/b.txt' },
        { key: ' ', value: 'ignored' }
      ]
      const normalized = LogEntryNormalizer.normalizeEntry(entry)

      expect(normalized.id.length > 0).assertTrue()
      expect(normalized.eventKey).assertEqual('file.unknown')
      expect(normalized.fields?.length).assertEqual(1)
      expect(normalized.fields?.[0].key).assertEqual('object.file_path')
      expect(normalized.fields?.[0].value).assertEqual('/data/a.txt')
    })

    it('should bound internal raw payload without placing it in display fields', 0, () => {
      const entry = createEntry()
      entry.rawPayload = { content: 'x'.repeat(70 * 1024), metadata: 'meta', truncated: false }
      const normalized = LogEntryNormalizer.normalizeEntry(entry)

      expect(normalized.rawPayload?.content?.length).assertEqual(64 * 1024)
      expect(normalized.rawPayload?.truncated).assertTrue()
      expect(normalized.fields === undefined).assertTrue()
    })

    it('should preserve append order and ignore invalid items', 0, () => {
      const result = LogEntryNormalizer.normalizeEntriesForAppend([
        createEntry('1'),
        undefined as never as LogEntry,
        createEntry('2')
      ])
      expect(result.length).assertEqual(2)
      expect(result[0].id).assertEqual('1')
      expect(result[1].id).assertEqual('2')
    })
  })
}
