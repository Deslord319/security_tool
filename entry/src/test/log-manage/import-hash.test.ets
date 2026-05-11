import { describe, expect, it } from '@ohos/hypium'
import { LogEntry, LogEventResult, LogEventType } from '../../main/ets/models/DataModels'
import { LogImportHash } from '../../main/ets/services/log-manage/import/LogImportHash'

function createEntry(detail: string, sourceFile: string): LogEntry {
  return {
    id: '',
    timestamp: 1,
    eventType: LogEventType.KERNEL,
    detail,
    processName: 'demo',
    rawEventName: 'kernel_hmseh_denied',
    detailRows: [
      { key: 'import.sourceFile', label: '来源文件', value: sourceFile }
    ],
    result: LogEventResult.FAILED
  }
}

export default function logImportHashTest() {
  describe('LogImportHash', () => {
    it('should ignore source metadata for duplicate detection', 0, () => {
      let first = LogImportHash.buildId(createEntry('alpha   beta', 'a/hilog_kmsg.1'))
      let second = LogImportHash.buildId(createEntry(' alpha beta ', 'b/hilog_kmsg.2'))

      expect(first).assertEqual(second)
    })

    it('should include event type and rule id', 0, () => {
      let first = createEntry('alpha beta', 'a')
      let second = createEntry('alpha beta', 'a')
      second.rawEventName = 'kernel_hmdec_rule'
      let third = createEntry('alpha beta', 'a')
      third.eventType = LogEventType.SYSTEM

      expect(LogImportHash.buildId(first) === LogImportHash.buildId(second)).assertFalse()
      expect(LogImportHash.buildId(first) === LogImportHash.buildId(third)).assertFalse()
    })
  })
}
