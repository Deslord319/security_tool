import { common } from '@kit.AbilityKit'
import { fileUri, picker } from '@kit.CoreFileKit'
import { taskpool } from '@kit.ArkTS'
import fileIo from '@ohos.file.fs'
import { LogEntry } from '../../../models/LogModels'
import { LogUtils } from '../../../utils/LogUtils'
import { LogEntryRepository } from '../repository/LogEntryRepository'
import { buildLogStorageNaturalDayCutoff, LogStorageMaintenanceService } from '../maintenance/LogStorageMaintenanceService'
import { LogEntryNormalizer } from '../mapper/LogEntryNormalizer'
import { LogSettingsRepository } from '../repository/LogSettingsRepository'
import { LogImportParseTaskResult, runLogImportParseTask } from './LogImportBackgroundTask'

const TAG = 'LogImportService'
const IMPORT_WORKSPACE_DIR = 'log_import_tmp'

export type ImportLogsCode = 'ok' | 'user_canceled' | 'invalid_archive' | 'extract_failed' | 'save_failed'

export interface ImportLogsResult {
  success: boolean
  code: ImportLogsCode
  extractedFileCount: number
  scannedFileCount: number
  parsedEntryCount: number
  insertedEntryCount: number
  skippedDuplicateCount: number
  skippedExpiredCount: number
  droppedEntryCount: number
  failedEntryCount: number
}

export interface LogImportSelectionResult {
  success: boolean
  code: 'ok' | 'user_canceled'
  archivePath: string
  targetDirectory: string
}

interface ImportBaseStats {
  extractedFileCount?: number
  scannedFileCount?: number
}

interface ImportResultStats extends ImportBaseStats {
  parsedEntryCount?: number
  insertedEntryCount?: number
  skippedDuplicateCount?: number
  skippedExpiredCount?: number
  droppedEntryCount?: number
  failedEntryCount?: number
}

export interface LogImportPickerPort {
  pickZip(context: common.UIAbilityContext): Promise<string | null>
}

export interface LogImportWorkspacePort {
  buildRoot(context: common.UIAbilityContext): string
  cleanupRoot(path: string): Promise<void>
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

export class LogImportService {
  private static pickerPort: LogImportPickerPort = new DefaultLogImportPicker()
  private static workspacePort: LogImportWorkspacePort = new DefaultLogImportWorkspace()

  static setPickerForTest(pickerPort: LogImportPickerPort): void {
    LogImportService.pickerPort = pickerPort
  }

  static setWorkspaceForTest(workspacePort: LogImportWorkspacePort): void {
    LogImportService.workspacePort = workspacePort
  }

  static resetTestPorts(): void {
    LogImportService.pickerPort = new DefaultLogImportPicker()
    LogImportService.workspacePort = new DefaultLogImportWorkspace()
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
      let parseResult = await taskpool.execute(runLogImportParseTask, archivePath, targetDirectory) as LogImportParseTaskResult
      let result = await LogImportService.importParsedEntries(parseResult, importId, startedAt)
      LogUtils.info(TAG, `import done: importId=${importId}, code=${result.code}, extracted=${result.extractedFileCount}, scanned=${result.scannedFileCount}, parsed=${result.parsedEntryCount}, inserted=${result.insertedEntryCount}, skipped=${result.skippedDuplicateCount}, expired=${result.skippedExpiredCount}, dropped=${result.droppedEntryCount}, failed=${result.failedEntryCount}, elapsedMs=${Date.now() - startedAt}`)
      return result
    } catch (err) {
      LogUtils.error(TAG, `import failed: importId=${importId}, err=${JSON.stringify(err)}, elapsedMs=${Date.now() - startedAt}`)
      return LogImportService.buildResult('extract_failed')
    } finally {
      await LogImportService.cleanupWorkspaceRoot(targetDirectory, importId, 'after_import')
    }
  }

  static async importParsedEntries(
    parseResult: LogImportParseTaskResult,
    importId: string = LogImportService.buildImportId(),
    startedAt: number = Date.now()
  ): Promise<ImportLogsResult> {
    if (!parseResult.success) {
      return LogImportService.buildResult(parseResult.code, {
        extractedFileCount: parseResult.extractedFileCount,
        scannedFileCount: parseResult.scannedFileCount,
        parsedEntryCount: parseResult.parsedEntryCount,
        skippedDuplicateCount: parseResult.skippedBatchDuplicateCount,
        droppedEntryCount: parseResult.droppedEntryCount,
        failedEntryCount: parseResult.failedEntryCount
      })
    }

    let skippedDuplicateCount = parseResult.skippedBatchDuplicateCount
    let skippedExpiredCount = 0
    let newEntries: LogEntry[] = []
    LogUtils.info(TAG, `persist parsed entries start: importId=${importId}, unique=${parseResult.entries.length}, batchDuplicates=${skippedDuplicateCount}, elapsedMs=${Date.now() - startedAt}`)
    let storageConfig = await LogSettingsRepository.loadStorageConfig()
    let retentionDays = LogEntryNormalizer.normalizeRetentionDays(storageConfig.retentionDays)
    let cutoff = buildLogStorageNaturalDayCutoff(Date.now(), retentionDays)
    for (let entry of parseResult.entries) {
      if (entry.timestamp < cutoff) {
        skippedExpiredCount++
        continue
      }
      if (await LogEntryRepository.hasEntry(entry.id)) {
        skippedDuplicateCount++
        continue
      }
      newEntries.push(entry)
    }
    if (newEntries.length > 0) {
      let saveResult = await LogStorageMaintenanceService.appendEntries(newEntries)
      if (!saveResult.success) {
        LogUtils.warn(TAG, `save failed: importId=${importId}, newEntries=${newEntries.length}, elapsedMs=${Date.now() - startedAt}`)
        return LogImportService.buildResult('save_failed', {
          extractedFileCount: parseResult.extractedFileCount,
          scannedFileCount: parseResult.scannedFileCount,
          parsedEntryCount: parseResult.parsedEntryCount,
          skippedDuplicateCount,
          skippedExpiredCount,
          droppedEntryCount: parseResult.droppedEntryCount,
          failedEntryCount: parseResult.failedEntryCount
        })
      }
    }
    LogUtils.info(TAG, `save done: importId=${importId}, newEntries=${newEntries.length}, skipped=${skippedDuplicateCount}, expired=${skippedExpiredCount}, elapsedMs=${Date.now() - startedAt}`)
    return LogImportService.buildResult('ok', {
      extractedFileCount: parseResult.extractedFileCount,
      scannedFileCount: parseResult.scannedFileCount,
      parsedEntryCount: parseResult.parsedEntryCount,
      insertedEntryCount: newEntries.length,
      skippedDuplicateCount,
      skippedExpiredCount,
      droppedEntryCount: parseResult.droppedEntryCount,
      failedEntryCount: parseResult.failedEntryCount
    })
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
}
