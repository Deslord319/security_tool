import { common } from '@kit.AbilityKit'
import { fileUri, picker } from '@kit.CoreFileKit'
import { taskpool } from '@kit.ArkTS'
import fileIo from '@ohos.file.fs'
import { LogEntry } from '../../../models/LogModels'
import { ImportLogsCode, ImportLogsResult, LogImportSelectionResult } from '../../../models/LogImportModels'
import { LogUtils } from '../../../utils/LogUtils'
import { LogEntryRepository } from '../repository/LogEntryRepository'
import { buildLogStorageNaturalDayCutoff, LogStorageMaintenanceService } from '../maintenance/LogStorageMaintenanceService'
import { LogEntryNormalizer } from '../mapper/LogEntryNormalizer'
import { LogSettingsRepository } from '../repository/LogSettingsRepository'
import {
  LogImportPrepareTaskResult,
  runLogImportFileParseTask,
  runLogImportPrepareTask
} from './LogImportBackgroundTask'
import { ImportedLogFile, LogImportRuleResult } from './LogImportRule'

const TAG = 'LogImportService'
const IMPORT_WORKSPACE_DIR = 'log_import_tmp'
const IMPORT_PERSIST_BATCH_SIZE = 1000
const IMPORT_RECONCILE_INTERVAL = 10000

interface ImportResultStats {
  extractedFileCount: number
  scannedFileCount: number
  parsedEntryCount: number
  insertedEntryCount: number
  skippedDuplicateCount: number
  skippedExpiredCount: number
  droppedEntryCount: number
  failedEntryCount: number
}

interface ImportBatchPersistResult {
  success: boolean
  insertedEntryCount: number
  skippedDuplicateCount: number
  skippedExpiredCount: number
}

export interface LogImportPickerPort {
  pickZip(context: common.UIAbilityContext): Promise<string | null>
}

export interface LogImportWorkspacePort {
  buildRoot(context: common.UIAbilityContext): string
  cleanupRoot(path: string): Promise<void>
}

export interface LogImportTaskPort {
  prepare(archivePath: string, targetDirectory: string): Promise<LogImportPrepareTaskResult>
  parse(file: ImportedLogFile): Promise<LogImportRuleResult>
}

export interface LogImportStoragePort {
  findExistingEntryIds(entryIds: string[]): Promise<Set<string>>
  appendImportBatch(entries: LogEntry[]): Promise<boolean>
  reconcileImportStorage(notifyChanged: boolean): Promise<boolean>
}

class DefaultLogImportPicker implements LogImportPickerPort {
  async pickZip(context: common.UIAbilityContext): Promise<string | null> {
    let documentViewPicker = new picker.DocumentViewPicker(context)
    let options = new picker.DocumentSelectOptions()
    options.maxSelectNumber = 1
    options.selectMode = picker.DocumentSelectMode.FILE
    options.fileSuffixFilters = ['Zip archive|.zip']
    let result = await documentViewPicker.select(options)
    return result.length > 0 ? new fileUri.FileUri(result[0]).path : null
  }
}

class DefaultLogImportWorkspace implements LogImportWorkspacePort {
  buildRoot(context: common.UIAbilityContext): string {
    return LogImportService.joinPath(context.filesDir || '', IMPORT_WORKSPACE_DIR)
  }

  async cleanupRoot(path: string): Promise<void> {
    let normalizedPath = LogImportService.normalizePath(path)
    if (!normalizedPath.endsWith(`/${IMPORT_WORKSPACE_DIR}`)) {
      return
    }
    if (normalizedPath.length <= IMPORT_WORKSPACE_DIR.length + 1) {
      return
    }
    await LogImportService.deleteDirectoryRecursively(normalizedPath)
  }
}

class DefaultLogImportTasks implements LogImportTaskPort {
  async prepare(archivePath: string, targetDirectory: string): Promise<LogImportPrepareTaskResult> {
    let task = new taskpool.LongTask(runLogImportPrepareTask, archivePath, targetDirectory)
    try {
      return await taskpool.execute(task) as LogImportPrepareTaskResult
    } catch (err) {
      LogUtils.warn(TAG, `execute prepare task failed: err=${JSON.stringify(err)}`)
      throw err as Error
    } finally {
      try {
        taskpool.terminateTask(task)
      } catch (err) {
        LogUtils.warn(TAG, `terminate prepare task failed: err=${JSON.stringify(err)}`)
      }
    }
  }

  async parse(file: ImportedLogFile): Promise<LogImportRuleResult> {
    try {
      return await taskpool.execute(runLogImportFileParseTask, file) as LogImportRuleResult
    } catch (err) {
      LogUtils.warn(TAG, `execute file task failed: file=${file.relativePath}, err=${JSON.stringify(err)}`)
      throw err as Error
    }
  }
}

class DefaultLogImportStorage implements LogImportStoragePort {
  findExistingEntryIds(entryIds: string[]): Promise<Set<string>> {
    return LogEntryRepository.findExistingEntryIds(entryIds)
  }

  async appendImportBatch(entries: LogEntry[]): Promise<boolean> {
    let result = await LogStorageMaintenanceService.appendImportBatch(entries)
    return result.success
  }

  async reconcileImportStorage(notifyChanged: boolean): Promise<boolean> {
    let result = await LogStorageMaintenanceService.reconcileImportStorage(notifyChanged)
    return result.success
  }
}

export class LogImportService {
  private static pickerPort: LogImportPickerPort = new DefaultLogImportPicker()
  private static workspacePort: LogImportWorkspacePort = new DefaultLogImportWorkspace()
  private static taskPort: LogImportTaskPort = new DefaultLogImportTasks()
  private static storagePort: LogImportStoragePort = new DefaultLogImportStorage()

  static setPickerForTest(pickerPort: LogImportPickerPort): void {
    LogImportService.pickerPort = pickerPort
  }

  static setWorkspaceForTest(workspacePort: LogImportWorkspacePort): void {
    LogImportService.workspacePort = workspacePort
  }

  static setTaskPortForTest(taskPort: LogImportTaskPort): void {
    LogImportService.taskPort = taskPort
  }

  static setStoragePortForTest(storagePort: LogImportStoragePort): void {
    LogImportService.storagePort = storagePort
  }

  static resetTestPorts(): void {
    LogImportService.pickerPort = new DefaultLogImportPicker()
    LogImportService.workspacePort = new DefaultLogImportWorkspace()
    LogImportService.taskPort = new DefaultLogImportTasks()
    LogImportService.storagePort = new DefaultLogImportStorage()
  }

  static async import(context: common.UIAbilityContext): Promise<ImportLogsResult> {
    let selection = await LogImportService.pickImportTargets(context)
    if (!selection.success) {
      return LogImportService.buildResult(selection.code)
    }
    return LogImportService.importSelected(selection.archivePath, selection.targetDirectory)
  }

  static async pickImportTargets(context: common.UIAbilityContext): Promise<LogImportSelectionResult> {
    let importId = LogImportService.buildImportId()
    try {
      let archivePath = await LogImportService.pickerPort.pickZip(context)
      if (!archivePath) {
        LogUtils.info(TAG, `import canceled: importId=${importId}, stage=pickZip`)
        return LogImportService.buildSelectionResult('user_canceled')
      }
      let targetDirectory = LogImportService.workspacePort.buildRoot(context)
      await LogImportService.cleanupWorkspaceRoot(targetDirectory, importId, 'before_import')
      return {
        success: true,
        code: 'ok',
        archivePath,
        targetDirectory
      }
    } catch (err) {
      LogUtils.error(TAG, `pick import targets failed: importId=${importId}, err=${JSON.stringify(err)}`)
      return LogImportService.buildSelectionResult('user_canceled')
    }
  }

  static async importSelected(archivePath: string, targetDirectory: string): Promise<ImportLogsResult> {
    let importId = LogImportService.buildImportId()
    let startedAt = Date.now()
    try {
      LogUtils.info(TAG, `import start: importId=${importId}, archive=${archivePath}, target=${targetDirectory}`)
      let prepareResult = await LogImportService.taskPort.prepare(archivePath, targetDirectory)
      if (!prepareResult.success) {
        let failedStats = LogImportService.buildEmptyStats(
          prepareResult.extractedFileCount,
          prepareResult.scannedFileCount
        )
        return LogImportService.buildResult(prepareResult.code, failedStats)
      }
      let result = await LogImportService.importPreparedFiles(prepareResult, importId, startedAt)
      LogUtils.info(TAG, `import done: importId=${importId}, code=${result.code}, extracted=${result.extractedFileCount}, scanned=${result.scannedFileCount}, parsed=${result.parsedEntryCount}, inserted=${result.insertedEntryCount}, skipped=${result.skippedDuplicateCount}, expired=${result.skippedExpiredCount}, dropped=${result.droppedEntryCount}, failed=${result.failedEntryCount}, elapsedMs=${Date.now() - startedAt}`)
      return result
    } catch (err) {
      LogUtils.error(TAG, `import failed: importId=${importId}, err=${JSON.stringify(err)}, elapsedMs=${Date.now() - startedAt}`)
      return LogImportService.buildResult('extract_failed')
    } finally {
      await LogImportService.cleanupWorkspaceRoot(targetDirectory, importId, 'after_import')
    }
  }

  private static async importPreparedFiles(
    prepareResult: LogImportPrepareTaskResult,
    importId: string,
    startedAt: number
  ): Promise<ImportLogsResult> {
    let stats = LogImportService.buildEmptyStats(
      prepareResult.extractedFileCount,
      prepareResult.scannedFileCount
    )
    let storageConfig = await LogSettingsRepository.loadStorageConfig()
    let retentionDays = LogEntryNormalizer.normalizeRetentionDays(storageConfig.retentionDays)
    let cutoff = buildLogStorageNaturalDayCutoff(Date.now(), retentionDays)
    let insertedSinceReconcile = 0
    for (let file of prepareResult.files) {
      let fileResult: LogImportRuleResult
      try {
        fileResult = await LogImportService.taskPort.parse(file)
      } catch (err) {
        stats.failedEntryCount++
        LogUtils.warn(TAG, `file task failed: importId=${importId}, file=${file.relativePath}, err=${JSON.stringify(err)}`)
        continue
      }

      stats.parsedEntryCount += fileResult.entries.length
      stats.droppedEntryCount += fileResult.droppedCount
      stats.failedEntryCount += fileResult.failedCount
      let persistResult = await LogImportService.persistFileEntries(fileResult.entries, cutoff, importId, file.relativePath)
      stats.insertedEntryCount += persistResult.insertedEntryCount
      stats.skippedDuplicateCount += persistResult.skippedDuplicateCount
      stats.skippedExpiredCount += persistResult.skippedExpiredCount
      if (!persistResult.success) {
        return LogImportService.buildResult('save_failed', stats)
      }
      insertedSinceReconcile += persistResult.insertedEntryCount
      if (insertedSinceReconcile >= IMPORT_RECONCILE_INTERVAL) {
        let reconciled = await LogImportService.storagePort.reconcileImportStorage(false)
        if (!reconciled) {
          LogUtils.warn(TAG, `periodic reconcile failed: importId=${importId}, inserted=${stats.insertedEntryCount}, elapsedMs=${Date.now() - startedAt}`)
          return LogImportService.buildResult('save_failed', stats)
        }
        insertedSinceReconcile = 0
      }
      LogUtils.info(TAG, `file persist done: importId=${importId}, file=${file.relativePath}, parsed=${fileResult.entries.length}, inserted=${persistResult.insertedEntryCount}, duplicate=${persistResult.skippedDuplicateCount}, expired=${persistResult.skippedExpiredCount}, elapsedMs=${Date.now() - startedAt}`)
    }

    let finalReconciled = await LogImportService.storagePort.reconcileImportStorage(true)
    if (!finalReconciled) {
      LogUtils.warn(TAG, `final reconcile failed: importId=${importId}, inserted=${stats.insertedEntryCount}, elapsedMs=${Date.now() - startedAt}`)
      return LogImportService.buildResult('save_failed', stats)
    }
    return LogImportService.buildResult('ok', stats)
  }

  private static async persistFileEntries(
    entries: LogEntry[],
    cutoff: number,
    importId: string,
    relativePath: string
  ): Promise<ImportBatchPersistResult> {
    let result: ImportBatchPersistResult = {
      success: true,
      insertedEntryCount: 0,
      skippedDuplicateCount: 0,
      skippedExpiredCount: 0
    }
    for (let start = 0; start < entries.length; start += IMPORT_PERSIST_BATCH_SIZE) {
      let sourceBatch = entries.slice(start, start + IMPORT_PERSIST_BATCH_SIZE)
      let batchIds = new Set<string>()
      let candidates: LogEntry[] = []
      for (let entry of sourceBatch) {
        if (entry.timestamp < cutoff) {
          result.skippedExpiredCount++
          continue
        }
        if (batchIds.has(entry.id)) {
          result.skippedDuplicateCount++
          continue
        }
        batchIds.add(entry.id)
        candidates.push(entry)
      }
      if (candidates.length === 0) {
        continue
      }

      try {
        let existingIds = await LogImportService.storagePort.findExistingEntryIds(
          candidates.map((entry: LogEntry) => entry.id)
        )
        let newEntries: LogEntry[] = []
        for (let entry of candidates) {
          if (existingIds.has(entry.id)) {
            result.skippedDuplicateCount++
          } else {
            newEntries.push(entry)
          }
        }
        if (newEntries.length === 0) {
          continue
        }
        let saved = await LogImportService.storagePort.appendImportBatch(newEntries)
        if (!saved) {
          LogUtils.warn(TAG, `import batch save failed: importId=${importId}, file=${relativePath}, start=${start}, count=${newEntries.length}`)
          result.success = false
          return result
        }
        result.insertedEntryCount += newEntries.length
      } catch (err) {
        LogUtils.warn(TAG, `import batch failed: importId=${importId}, file=${relativePath}, start=${start}, err=${JSON.stringify(err)}`)
        result.success = false
        return result
      }
    }
    return result
  }

  private static buildImportId(): string {
    return `import_${Date.now()}`
  }

  private static async cleanupWorkspaceRoot(path: string, importId: string, stage: string): Promise<void> {
    try {
      await LogImportService.workspacePort.cleanupRoot(path)
    } catch (err) {
      LogUtils.error(TAG, `cleanup workspace failed: importId=${importId}, stage=${stage}, path=${path}, err=${JSON.stringify(err)}`)
    }
  }

  static joinPath(parent: string, child: string): string {
    let cleanParent = parent.replace(/\\/g, '/').replace(/\/+$/g, '')
    let cleanChild = child.replace(/\\/g, '/').replace(/^\/+/g, '')
    if (cleanParent.length === 0) {
      return cleanChild
    }
    return `${cleanParent}/${cleanChild}`
  }

  static normalizePath(path: string): string {
    return path.replace(/\\/g, '/').replace(/\/+/g, '/')
  }

  static async deleteDirectoryRecursively(path: string): Promise<void> {
    try {
      if (!await fileIo.access(path)) {
        return
      }
      let entries = await fileIo.listFile(path)
      for (let entry of entries) {
        let childPath = LogImportService.joinPath(path, entry)
        let stat = await fileIo.stat(childPath)
        if (stat.isDirectory()) {
          await LogImportService.deleteDirectoryRecursively(childPath)
        } else {
          await fileIo.unlink(childPath)
        }
      }
      await fileIo.rmdir(path)
    } catch (err) {
      LogUtils.error(TAG, `delete workspace path failed: path=${path}, err=${JSON.stringify(err)}`)
      return
    }
  }

  private static buildSelectionResult(code: 'user_canceled'): LogImportSelectionResult {
    return {
      success: false,
      code,
      archivePath: '',
      targetDirectory: ''
    }
  }

  private static buildResult(
    code: ImportLogsCode,
    stats?: ImportResultStats
  ): ImportLogsResult {
    return {
      success: code === 'ok',
      code,
      extractedFileCount: stats?.extractedFileCount ?? 0,
      scannedFileCount: stats?.scannedFileCount ?? 0,
      parsedEntryCount: stats?.parsedEntryCount ?? 0,
      insertedEntryCount: stats?.insertedEntryCount ?? 0,
      skippedDuplicateCount: stats?.skippedDuplicateCount ?? 0,
      skippedExpiredCount: stats?.skippedExpiredCount ?? 0,
      droppedEntryCount: stats?.droppedEntryCount ?? 0,
      failedEntryCount: stats?.failedEntryCount ?? 0
    }
  }

  private static buildEmptyStats(
    extractedFileCount: number = 0,
    scannedFileCount: number = 0
  ): ImportResultStats {
    return {
      extractedFileCount,
      scannedFileCount,
      parsedEntryCount: 0,
      insertedEntryCount: 0,
      skippedDuplicateCount: 0,
      skippedExpiredCount: 0,
      droppedEntryCount: 0,
      failedEntryCount: 0
    }
  }
}
