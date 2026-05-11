import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { LogEntry, LogEventResult, LogEventType } from '../../main/ets/models/DataModels'
import { LogImportService } from '../../main/ets/services/log-manage/import/LogImportService'
import { MutationResult } from '../../main/ets/services/log-manage/common/LogManagePorts'
import {
  ImportedLogFile,
  LogImportRule,
  LogImportRuleResult
} from '../../main/ets/services/log-manage/import/LogImportRule'
import { LogEntryRepository } from '../../main/ets/services/log-manage/repository/LogEntryRepository'
import { LogStorageMaintenanceService } from '../../main/ets/services/log-manage/maintenance/LogStorageMaintenanceService'

function createEntry(id: string): LogEntry {
  return {
    id,
    timestamp: Date.now(),
    eventType: LogEventType.KERNEL,
    detail: id,
    rawEventName: 'kernel_hmseh_denied',
    result: LogEventResult.FAILED
  }
}

class FakeRule implements LogImportRule {
  readonly name: string = 'fake'
  result: LogImportRuleResult = {
    entries: [createEntry('a'), createEntry('a'), createEntry('b')],
    droppedCount: 2,
    failedCount: 1
  }

  canHandle(_file: ImportedLogFile): boolean {
    return true
  }

  async parse(_file: ImportedLogFile): Promise<LogImportRuleResult> {
    return this.result
  }
}

export default function logImportServiceTest() {
  describe('LogImportService', () => {
    let mockKit: MockKit
    let savedEntries: LogEntry[]
    let existingIds: Set<string>

    beforeEach(() => {
      mockKit = new MockKit()
      savedEntries = []
      existingIds = new Set<string>()
      LogImportService.setRulesForTest([new FakeRule()])

      let hasEntryMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.hasEntry)
      let appendEntriesMock = mockKit.mockFunc(LogStorageMaintenanceService, LogStorageMaintenanceService.appendEntries)
      when(hasEntryMock)(ArgumentMatchers.any).afterAction((entryId: string) => {
        return Promise.resolve(existingIds.has(entryId))
      })
      when(appendEntriesMock)(ArgumentMatchers.any).afterAction((entries: LogEntry[]) => {
        savedEntries = entries.slice()
        let result: MutationResult = { success: true, code: 'ok' }
        return Promise.resolve(result)
      })
    })

    afterEach(() => {
      LogImportService.resetTestPorts()
      mockKit.clearAll()
    })

    it('should dedupe batch entries and skip existing database records', 0, async () => {
      existingIds.add('b')

      let result = await LogImportService.importFiles([
        {
          path: '/tmp/hilog_kmsg.1',
          fileName: 'hilog_kmsg.1',
          relativePath: 'hilog/hilog_kmsg.1',
          normalizedPath: 'hilog/hilog_kmsg.1'
        }
      ])

      expect(result.success).assertTrue()
      expect(result.parsedEntryCount).assertEqual(3)
      expect(result.insertedEntryCount).assertEqual(1)
      expect(result.skippedDuplicateCount).assertEqual(2)
      expect(result.droppedEntryCount).assertEqual(2)
      expect(result.failedEntryCount).assertEqual(1)
      expect(savedEntries.length).assertEqual(1)
      expect(savedEntries[0].id).assertEqual('a')
    })
  })
}
