import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { common } from '@kit.AbilityKit'
import { LogEntry, LogEventType, LogStorageConfig } from '../../main/ets/models/LogModels'
import {
  LogImportPickerPort,
  LogImportService,
  LogImportWorkspacePort
} from '../../main/ets/services/log-manage/import/LogImportService'
import { MutationResult } from '../../main/ets/services/log-manage/common/LogManagePorts'
import { LogEntryRepository } from '../../main/ets/services/log-manage/repository/LogEntryRepository'
import { LogSettingsRepository } from '../../main/ets/services/log-manage/repository/LogSettingsRepository'
import { LogStorageMaintenanceService } from '../../main/ets/services/log-manage/maintenance/LogStorageMaintenanceService'
import { LogImportParseTaskResult } from '../../main/ets/services/log-manage/import/LogImportBackgroundTask'

function createEntry(id: string): LogEntry {
  return {
    id,
    timestamp: Date.now(),
    eventType: LogEventType.KERNEL,
    detail: id,
    rawEventName: 'kernel_hmseh_denied'
  }
}

function createParseResult(entries: LogEntry[], batchDuplicates: number = 0): LogImportParseTaskResult {
  return {
    success: true,
    code: 'ok',
    extractedFileCount: 2,
    scannedFileCount: 2,
    parsedEntryCount: entries.length + batchDuplicates,
    skippedBatchDuplicateCount: batchDuplicates,
    droppedEntryCount: 3,
    failedEntryCount: 1,
    entries
  }
}

function createFailedParseResult(code: 'invalid_archive' | 'extract_failed'): LogImportParseTaskResult {
  return {
    success: false,
    code,
    extractedFileCount: 1,
    scannedFileCount: 1,
    parsedEntryCount: 0,
    skippedBatchDuplicateCount: 0,
    droppedEntryCount: 2,
    failedEntryCount: 1,
    entries: []
  }
}

class FakePicker implements LogImportPickerPort {
  private readonly zipPath: string | null

  constructor(zipPath: string | null) {
    this.zipPath = zipPath
  }

  async pickZip(_context: common.UIAbilityContext): Promise<string | null> {
    return this.zipPath
  }
}

class FakeWorkspace implements LogImportWorkspacePort {
  readonly cleanupCalls: string[] = []

  buildRoot(context: common.UIAbilityContext): string {
    return `${context.filesDir}/log_import_tmp`
  }

  async cleanupRoot(path: string): Promise<void> {
    this.cleanupCalls.push(path)
  }
}

export default function logImportServiceTest() {
  describe('LogImportService', () => {
    let mockKit: MockKit
    let savedEntries: LogEntry[]
    let existingIds: Set<string>
    let saveResult: MutationResult
    let workspace: FakeWorkspace

    beforeEach(() => {
      mockKit = new MockKit()
      savedEntries = []
      existingIds = new Set<string>()
      saveResult = { success: true, code: 'ok' }
      workspace = new FakeWorkspace()
      LogImportService.setWorkspaceForTest(workspace)

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

    it('should return user_canceled when import zip picker is canceled', 0, async () => {
      LogImportService.setPickerForTest(new FakePicker(null))

      let result = await LogImportService.import({} as common.UIAbilityContext)

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('user_canceled')
      expect(result.scannedFileCount).assertEqual(0)
      expect(savedEntries.length).assertEqual(0)
    })

    it('should return user_canceled when zip picker is canceled', 0, async () => {
      LogImportService.setPickerForTest(new FakePicker(null))

      let result = await LogImportService.pickImportTargets({} as common.UIAbilityContext)

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('user_canceled')
      expect(result.archivePath).assertEqual('')
      expect(result.targetDirectory).assertEqual('')
    })

    it('should pick zip and use default import workspace root', 0, async () => {
      LogImportService.setPickerForTest(new FakePicker('/tmp/logs.zip'))

      let result = await LogImportService.pickImportTargets({
        filesDir: '/data/storage/el2/base/files'
      } as common.UIAbilityContext)

      expect(result.success).assertTrue()
      expect(result.code).assertEqual('ok')
      expect(result.archivePath).assertEqual('/tmp/logs.zip')
      expect(result.targetDirectory).assertEqual('/data/storage/el2/base/files/log_import_tmp')
      expect(workspace.cleanupCalls.length).assertEqual(1)
      expect(workspace.cleanupCalls[0]).assertEqual('/data/storage/el2/base/files/log_import_tmp')
    })

    it('should persist parsed entries and keep background batch duplicate count', 0, async () => {
      existingIds.add('existing')
      let expiredEntry = createEntry('expired')
      expiredEntry.timestamp = Date.now() - 40 * 24 * 60 * 60 * 1000
      let validEntry = createEntry('valid')
      let existingEntry = createEntry('existing')

      let result = await LogImportService.importParsedEntries(
        createParseResult([expiredEntry, validEntry, existingEntry], 2)
      )

      expect(result.success).assertTrue()
      expect(result.parsedEntryCount).assertEqual(5)
      expect(result.insertedEntryCount).assertEqual(1)
      expect(result.skippedDuplicateCount).assertEqual(3)
      expect(result.skippedExpiredCount).assertEqual(1)
      expect(result.droppedEntryCount).assertEqual(3)
      expect(result.failedEntryCount).assertEqual(1)
      expect(savedEntries.length).assertEqual(1)
      expect(savedEntries[0].id).assertEqual('valid')
    })

    it('should return save_failed when parsed entries cannot be persisted', 0, async () => {
      saveResult = { success: false, code: 'save_failed' }

      let result = await LogImportService.importParsedEntries(createParseResult([createEntry('valid')], 1))

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('save_failed')
      expect(result.parsedEntryCount).assertEqual(2)
      expect(result.insertedEntryCount).assertEqual(0)
      expect(result.skippedDuplicateCount).assertEqual(1)
      expect(result.skippedExpiredCount).assertEqual(0)
      expect(result.droppedEntryCount).assertEqual(3)
      expect(result.failedEntryCount).assertEqual(1)
      expect(savedEntries.length).assertEqual(1)
    })

    it('should return parse failure result when background parse fails', 0, async () => {
      let result = await LogImportService.importParsedEntries(createFailedParseResult('invalid_archive'))

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('invalid_archive')
      expect(result.extractedFileCount).assertEqual(1)
      expect(result.scannedFileCount).assertEqual(1)
      expect(result.parsedEntryCount).assertEqual(0)
      expect(result.insertedEntryCount).assertEqual(0)
      expect(result.skippedDuplicateCount).assertEqual(0)
      expect(result.skippedExpiredCount).assertEqual(0)
      expect(result.droppedEntryCount).assertEqual(2)
      expect(result.failedEntryCount).assertEqual(1)
      expect(savedEntries.length).assertEqual(0)
    })
  })
}
