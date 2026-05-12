import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { common } from '@kit.AbilityKit'
import { LogEntry, LogEventType, LogStorageConfig } from '../../main/ets/models/LogModels'
import { LogImportPickerPort, LogImportService } from '../../main/ets/services/log-manage/import/LogImportService'
import { MutationResult } from '../../main/ets/services/log-manage/common/LogManagePorts'
import {
  ImportedLogFile,
  LogImportRule,
  LogImportRuleResult
} from '../../main/ets/services/log-manage/import/LogImportRule'
import { LogEntryRepository } from '../../main/ets/services/log-manage/repository/LogEntryRepository'
import { LogSettingsRepository } from '../../main/ets/services/log-manage/repository/LogSettingsRepository'
import { LogStorageMaintenanceService } from '../../main/ets/services/log-manage/maintenance/LogStorageMaintenanceService'

function createEntry(id: string): LogEntry {
  return {
    id,
    timestamp: Date.now(),
    eventType: LogEventType.KERNEL,
    detail: id,
    rawEventName: 'kernel_hmseh_denied'
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

class ThrowingRule implements LogImportRule {
  readonly name: string = 'throwing'

  canHandle(_file: ImportedLogFile): boolean {
    return true
  }

  async parse(_file: ImportedLogFile): Promise<LogImportRuleResult> {
    throw new Error('parse failed')
  }
}

class FakePicker implements LogImportPickerPort {
  private readonly zipPath: string | null
  private readonly directoryPath: string | null

  constructor(
    zipPath: string | null,
    directoryPath: string | null
  ) {
    this.zipPath = zipPath
    this.directoryPath = directoryPath
  }

  async pickZip(_context: common.UIAbilityContext): Promise<string | null> {
    return this.zipPath
  }

  async pickDirectory(_context: common.UIAbilityContext): Promise<string | null> {
    return this.directoryPath
  }
}

export default function logImportServiceTest() {
  describe('LogImportService', () => {
    let mockKit: MockKit
    let savedEntries: LogEntry[]
    let existingIds: Set<string>
    let saveResult: MutationResult

    beforeEach(() => {
      mockKit = new MockKit()
      savedEntries = []
      existingIds = new Set<string>()
      saveResult = { success: true, code: 'ok' }
      LogImportService.setRulesForTest([new FakeRule()])

      let hasEntryMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.hasEntry)
      let loadConfigMock = mockKit.mockFunc(LogSettingsRepository, LogSettingsRepository.loadStorageConfig)
      let appendEntriesMock = mockKit.mockFunc(LogStorageMaintenanceService, LogStorageMaintenanceService.appendEntries)
      let storageConfig: LogStorageConfig = {
        maxLocalEntries: 20000,
        retentionDays: 30
      }
      when(hasEntryMock)(ArgumentMatchers.any).afterAction((entryId: string) => {
        return Promise.resolve(existingIds.has(entryId))
      })
      when(loadConfigMock)().afterReturn(Promise.resolve(storageConfig))
      when(appendEntriesMock)(ArgumentMatchers.any).afterAction((entries: LogEntry[]) => {
        savedEntries = entries.slice()
        return Promise.resolve(saveResult)
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
      expect(result.skippedExpiredCount).assertEqual(0)
      expect(result.droppedEntryCount).assertEqual(2)
      expect(result.failedEntryCount).assertEqual(1)
      expect(savedEntries.length).assertEqual(1)
      expect(savedEntries[0].id).assertEqual('a')
    })

    it('should return user_canceled when zip picker is canceled', 0, async () => {
      LogImportService.setPickerForTest(new FakePicker(null, '/tmp/out'))

      let result = await LogImportService.import({} as common.UIAbilityContext)

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('user_canceled')
      expect(result.scannedFileCount).assertEqual(0)
      expect(savedEntries.length).assertEqual(0)
    })

    it('should return user_canceled when directory picker is canceled', 0, async () => {
      LogImportService.setPickerForTest(new FakePicker('/tmp/logs.zip', null))

      let result = await LogImportService.import({} as common.UIAbilityContext)

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('user_canceled')
      expect(result.scannedFileCount).assertEqual(0)
      expect(savedEntries.length).assertEqual(0)
    })

    it('should continue importing when one rule throws during parse', 0, async () => {
      LogImportService.setRulesForTest([new ThrowingRule(), new FakeRule()])

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
      expect(result.insertedEntryCount).assertEqual(2)
      expect(result.skippedDuplicateCount).assertEqual(1)
      expect(result.skippedExpiredCount).assertEqual(0)
      expect(result.droppedEntryCount).assertEqual(2)
      expect(result.failedEntryCount).assertEqual(2)
      expect(savedEntries.length).assertEqual(2)
    })

    it('should skip expired entries before appending imported logs', 0, async () => {
      let rule = new FakeRule()
      let expiredEntry = createEntry('expired')
      expiredEntry.timestamp = Date.now() - 40 * 24 * 60 * 60 * 1000
      let validEntry = createEntry('valid')
      rule.result = {
        entries: [expiredEntry, validEntry],
        droppedCount: 0,
        failedCount: 0
      }
      LogImportService.setRulesForTest([rule])

      let result = await LogImportService.importFiles([
        {
          path: '/tmp/hilog_kmsg.1',
          fileName: 'hilog_kmsg.1',
          relativePath: 'hilog/hilog_kmsg.1',
          normalizedPath: 'hilog/hilog_kmsg.1'
        }
      ])

      expect(result.success).assertTrue()
      expect(result.parsedEntryCount).assertEqual(2)
      expect(result.insertedEntryCount).assertEqual(1)
      expect(result.skippedDuplicateCount).assertEqual(0)
      expect(result.skippedExpiredCount).assertEqual(1)
      expect(savedEntries.length).assertEqual(1)
      expect(savedEntries[0].id).assertEqual('valid')
    })

    it('should return save_failed when parsed entries cannot be appended', 0, async () => {
      saveResult = { success: false, code: 'save_failed' }

      let result = await LogImportService.importFiles([
        {
          path: '/tmp/hilog_kmsg.1',
          fileName: 'hilog_kmsg.1',
          relativePath: 'hilog/hilog_kmsg.1',
          normalizedPath: 'hilog/hilog_kmsg.1'
        }
      ])

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('save_failed')
      expect(result.parsedEntryCount).assertEqual(3)
      expect(result.insertedEntryCount).assertEqual(0)
      expect(result.skippedDuplicateCount).assertEqual(1)
      expect(result.skippedExpiredCount).assertEqual(0)
      expect(result.droppedEntryCount).assertEqual(2)
      expect(result.failedEntryCount).assertEqual(1)
      expect(savedEntries.length).assertEqual(2)
    })
  })
}
