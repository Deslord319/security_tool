import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { MockKit, when } from '@ohos/hamock'
import { common } from '@kit.AbilityKit'
import { LogEntry, LogEventType, LogStorageConfig } from '../../main/ets/models/LogModels'
import {
  LogImportPickerPort,
  LogImportService,
  LogImportStoragePort,
  LogImportTaskPort,
  LogImportWorkspacePort
} from '../../main/ets/services/log-manage/import/LogImportService'
import { LogSettingsRepository } from '../../main/ets/services/log-manage/repository/LogSettingsRepository'
import { LogImportPrepareTaskResult } from '../../main/ets/services/log-manage/import/LogImportBackgroundTask'
import { ImportedLogFile, LogImportRuleResult } from '../../main/ets/services/log-manage/import/LogImportRule'

function createEntry(id: string): LogEntry {
  return {
    id,
    timestamp: Date.now(),
    eventType: LogEventType.KERNEL,
    detail: id,
    rawEventName: 'kernel_hmseh_denied'
  }
}

function createEntries(count: number, prefix: string = 'entry'): LogEntry[] {
  let entries: LogEntry[] = []
  for (let index = 0; index < count; index++) {
    entries.push(createEntry(`${prefix}-${index}`))
  }
  return entries
}

function createFile(name: string): ImportedLogFile {
  return {
    path: `/tmp/${name}`,
    fileName: name,
    relativePath: `remoteLog/hilog/${name}`,
    normalizedPath: `remoteLog/hilog/${name}`
  }
}

function createPrepareResult(
  files: ImportedLogFile[],
  code: 'ok' | 'invalid_archive' | 'extract_failed' = 'ok'
): LogImportPrepareTaskResult {
  return {
    success: code === 'ok',
    code,
    extractedFileCount: files.length + 2,
    scannedFileCount: files.length + 2,
    files: code === 'ok' ? files : []
  }
}

function createRuleResult(
  entries: LogEntry[],
  droppedCount: number = 0,
  failedCount: number = 0
): LogImportRuleResult {
  return {
    entries,
    droppedCount,
    failedCount
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

class FakeImportTasks implements LogImportTaskPort {
  prepareResult: LogImportPrepareTaskResult = createPrepareResult([])
  readonly parseResults: Map<string, LogImportRuleResult> = new Map()
  readonly parseFailures: Set<string> = new Set()
  readonly parseCalls: string[] = []

  async prepare(_archivePath: string, _targetDirectory: string): Promise<LogImportPrepareTaskResult> {
    return this.prepareResult
  }

  async parse(file: ImportedLogFile): Promise<LogImportRuleResult> {
    this.parseCalls.push(file.relativePath)
    if (this.parseFailures.has(file.relativePath)) {
      throw new Error('file_task_failed')
    }
    return this.parseResults.get(file.relativePath) ?? createRuleResult([])
  }
}

class FakeImportStorage implements LogImportStoragePort {
  readonly existingIds: Set<string> = new Set()
  readonly savedBatches: LogEntry[][] = []
  readonly lookupBatchSizes: number[] = []
  readonly reconcileCalls: boolean[] = []
  failOnSaveCall: number = -1
  saveCallCount: number = 0
  reconcileSuccess: boolean = true

  async findExistingEntryIds(entryIds: string[]): Promise<Set<string>> {
    this.lookupBatchSizes.push(entryIds.length)
    let result = new Set<string>()
    entryIds.forEach((entryId: string) => {
      if (this.existingIds.has(entryId)) {
        result.add(entryId)
      }
    })
    return result
  }

  async appendImportBatch(entries: LogEntry[]): Promise<boolean> {
    this.saveCallCount++
    this.savedBatches.push(entries.slice())
    if (this.saveCallCount === this.failOnSaveCall) {
      return false
    }
    entries.forEach((entry: LogEntry) => this.existingIds.add(entry.id))
    return true
  }

  async reconcileImportStorage(notifyChanged: boolean): Promise<boolean> {
    this.reconcileCalls.push(notifyChanged)
    return this.reconcileSuccess
  }
}

export default function logImportServiceTest() {
  describe('LogImportService', () => {
    let mockKit: MockKit
    let workspace: FakeWorkspace
    let taskPort: FakeImportTasks
    let storagePort: FakeImportStorage

    beforeEach(() => {
      mockKit = new MockKit()
      workspace = new FakeWorkspace()
      taskPort = new FakeImportTasks()
      storagePort = new FakeImportStorage()
      LogImportService.setWorkspaceForTest(workspace)
      LogImportService.setTaskPortForTest(taskPort)
      LogImportService.setStoragePortForTest(storagePort)

      let loadConfigMock = mockKit.mockFunc(
        LogSettingsRepository,
        LogSettingsRepository.loadStorageConfig
      )
      let storageConfig: LogStorageConfig = {
        maxLocalEntries: 20000,
        retentionDays: 30
      }
      when(loadConfigMock)().afterReturn(Promise.resolve(storageConfig))
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
      expect(taskPort.parseCalls.length).assertEqual(0)
      expect(storagePort.savedBatches.length).assertEqual(0)
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

    it('should filter expired and duplicate entries before import writes', 0, async () => {
      let file = createFile('hilog_kmsg.1.gz')
      let expiredEntry = createEntry('expired')
      expiredEntry.timestamp = Date.now() - 40 * 24 * 60 * 60 * 1000
      storagePort.existingIds.add('existing')
      taskPort.prepareResult = createPrepareResult([file])
      taskPort.parseResults.set(file.relativePath, createRuleResult([
        expiredEntry,
        createEntry('valid'),
        createEntry('valid'),
        createEntry('existing')
      ], 3, 1))

      let result = await LogImportService.importSelected('/tmp/logs.zip', '/tmp/log_import_tmp')

      expect(result.success).assertTrue()
      expect(result.parsedEntryCount).assertEqual(4)
      expect(result.insertedEntryCount).assertEqual(1)
      expect(result.skippedDuplicateCount).assertEqual(2)
      expect(result.skippedExpiredCount).assertEqual(1)
      expect(result.droppedEntryCount).assertEqual(3)
      expect(result.failedEntryCount).assertEqual(1)
      expect(storagePort.savedBatches.length).assertEqual(1)
      expect(storagePort.savedBatches[0][0].id).assertEqual('valid')
      expect(storagePort.reconcileCalls.length).assertEqual(1)
      expect(storagePort.reconcileCalls[0]).assertTrue()
    })

    it('should persist 2300 entries as 1000, 1000 and 300', 0, async () => {
      let file = createFile('hilog_kmsg.2.gz')
      taskPort.prepareResult = createPrepareResult([file])
      taskPort.parseResults.set(file.relativePath, createRuleResult(createEntries(2300)))

      let result = await LogImportService.importSelected('/tmp/logs.zip', '/tmp/log_import_tmp')

      expect(result.success).assertTrue()
      expect(result.insertedEntryCount).assertEqual(2300)
      expect(storagePort.savedBatches.length).assertEqual(3)
      expect(storagePort.savedBatches[0].length).assertEqual(1000)
      expect(storagePort.savedBatches[1].length).assertEqual(1000)
      expect(storagePort.savedBatches[2].length).assertEqual(300)
      expect(storagePort.lookupBatchSizes[0]).assertEqual(1000)
      expect(storagePort.lookupBatchSizes[1]).assertEqual(1000)
      expect(storagePort.lookupBatchSizes[2]).assertEqual(300)
    })

    it('should detect a duplicate from a previous batch', 0, async () => {
      let file = createFile('hilog_kmsg.3.gz')
      let entries = createEntries(1000)
      entries.push(createEntry('entry-0'))
      taskPort.prepareResult = createPrepareResult([file])
      taskPort.parseResults.set(file.relativePath, createRuleResult(entries))

      let result = await LogImportService.importSelected('/tmp/logs.zip', '/tmp/log_import_tmp')

      expect(result.success).assertTrue()
      expect(result.insertedEntryCount).assertEqual(1000)
      expect(result.skippedDuplicateCount).assertEqual(1)
      expect(storagePort.savedBatches.length).assertEqual(1)
      expect(storagePort.lookupBatchSizes.length).assertEqual(2)
    })

    it('should stop after an import batch save failure', 0, async () => {
      let firstFile = createFile('hilog_kmsg.4.gz')
      let secondFile = createFile('hilog_kmsg.5.gz')
      taskPort.prepareResult = createPrepareResult([firstFile, secondFile])
      taskPort.parseResults.set(firstFile.relativePath, createRuleResult(createEntries(1500, 'first')))
      taskPort.parseResults.set(secondFile.relativePath, createRuleResult(createEntries(1, 'second')))
      storagePort.failOnSaveCall = 2

      let result = await LogImportService.importSelected('/tmp/logs.zip', '/tmp/log_import_tmp')

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('save_failed')
      expect(result.insertedEntryCount).assertEqual(1000)
      expect(storagePort.savedBatches.length).assertEqual(2)
      expect(taskPort.parseCalls.length).assertEqual(1)
      expect(storagePort.reconcileCalls.length).assertEqual(0)
    })

    it('should continue after a single file task failure', 0, async () => {
      let failedFile = createFile('hilog_kmsg.6.gz')
      let validFile = createFile('hilog_kmsg.7.gz')
      taskPort.prepareResult = createPrepareResult([failedFile, validFile])
      taskPort.parseFailures.add(failedFile.relativePath)
      taskPort.parseResults.set(validFile.relativePath, createRuleResult([createEntry('valid')]))

      let result = await LogImportService.importSelected('/tmp/logs.zip', '/tmp/log_import_tmp')

      expect(result.success).assertTrue()
      expect(result.failedEntryCount).assertEqual(1)
      expect(result.insertedEntryCount).assertEqual(1)
      expect(taskPort.parseCalls.length).assertEqual(2)
    })

    it('should reconcile without notification after 10000 inserted entries', 0, async () => {
      let file = createFile('hilog_kmsg.8.gz')
      taskPort.prepareResult = createPrepareResult([file])
      taskPort.parseResults.set(file.relativePath, createRuleResult(createEntries(10000)))

      let result = await LogImportService.importSelected('/tmp/logs.zip', '/tmp/log_import_tmp')

      expect(result.success).assertTrue()
      expect(result.insertedEntryCount).assertEqual(10000)
      expect(storagePort.reconcileCalls.length).assertEqual(2)
      expect(storagePort.reconcileCalls[0]).assertFalse()
      expect(storagePort.reconcileCalls[1]).assertTrue()
    })

    it('should return prepare failure without parsing files', 0, async () => {
      taskPort.prepareResult = createPrepareResult([], 'invalid_archive')

      let result = await LogImportService.importSelected('/tmp/logs.txt', '/tmp/log_import_tmp')

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('invalid_archive')
      expect(taskPort.parseCalls.length).assertEqual(0)
      expect(storagePort.savedBatches.length).assertEqual(0)
      expect(workspace.cleanupCalls.length).assertEqual(1)
    })
  })
}
