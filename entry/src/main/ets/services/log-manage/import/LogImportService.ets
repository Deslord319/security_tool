import { common } from '@kit.AbilityKit'
import { fileUri, picker } from '@kit.CoreFileKit'
import { LogEntry } from '../../../models/DataModels'
import { LogUtils } from '../../../utils/LogUtils'
import { LogEntryRepository } from '../repository/LogEntryRepository'
import { LogStorageMaintenanceService } from '../maintenance/LogStorageMaintenanceService'
import { LogArchiveExtractor } from './LogArchiveExtractor'
import { CrashLogImportRule } from './CrashLogImportRule'
import { KernelLogImportRule } from './KernelLogImportRule'
import { ImportedLogFile, LogImportRule } from './LogImportRule'
import { SystemLogImportRule } from './SystemLogImportRule'

const TAG = 'LogImportService'

export type ImportLogsCode = 'ok' | 'user_canceled' | 'invalid_archive' | 'extract_failed' | 'save_failed'

export interface ImportLogsResult {
  success: boolean
  code: ImportLogsCode
  extractedFileCount: number
  scannedFileCount: number
  parsedEntryCount: number
  insertedEntryCount: number
  skippedDuplicateCount: number
  droppedEntryCount: number
  failedEntryCount: number
}

interface ImportBaseStats {
  extractedFileCount?: number
  scannedFileCount?: number
}

interface ImportResultStats extends ImportBaseStats {
  parsedEntryCount?: number
  insertedEntryCount?: number
  skippedDuplicateCount?: number
  droppedEntryCount?: number
  failedEntryCount?: number
}

export interface LogImportPickerPort {
  pickZip(context: common.UIAbilityContext): Promise<string | null>
  pickDirectory(context: common.UIAbilityContext): Promise<string | null>
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

  async pickDirectory(context: common.UIAbilityContext): Promise<string | null> {
    let documentViewPicker = new picker.DocumentViewPicker(context)
    let options = new picker.DocumentSelectOptions()
    options.maxSelectNumber = 1
    options.selectMode = picker.DocumentSelectMode.FOLDER
    let result = await documentViewPicker.select(options)
    return result.length > 0 ? new fileUri.FileUri(result[0]).path : null
  }
}

export class LogImportService {
  private static rules: LogImportRule[] = [new KernelLogImportRule(), new CrashLogImportRule(), new SystemLogImportRule()]
  private static pickerPort: LogImportPickerPort = new DefaultLogImportPicker()

  static setRulesForTest(rules: LogImportRule[]): void {
    LogImportService.rules = rules
  }

  static setPickerForTest(pickerPort: LogImportPickerPort): void {
    LogImportService.pickerPort = pickerPort
  }

  static resetTestPorts(): void {
    LogImportService.rules = [new KernelLogImportRule(), new CrashLogImportRule(), new SystemLogImportRule()]
    LogImportService.pickerPort = new DefaultLogImportPicker()
  }

  static async import(context: common.UIAbilityContext): Promise<ImportLogsResult> {
    let importId = LogImportService.buildImportId()
    let startedAt = Date.now()
    try {
      let archivePath = await LogImportService.pickerPort.pickZip(context)
      if (!archivePath) {
        LogUtils.info(TAG, `import canceled: importId=${importId}, stage=pickZip`)
        return LogImportService.buildResult('user_canceled')
      }
      let targetDirectory = await LogImportService.pickerPort.pickDirectory(context)
      if (!targetDirectory) {
        LogUtils.info(TAG, `import canceled: importId=${importId}, stage=pickDirectory`)
        return LogImportService.buildResult('user_canceled')
      }
      LogUtils.info(TAG, `import start: importId=${importId}, archive=${archivePath}, target=${targetDirectory}`)
      let extractResult = await LogArchiveExtractor.extract(archivePath, targetDirectory)
      if (!extractResult.success) {
        LogUtils.warn(TAG, `import extract failed: importId=${importId}, code=${extractResult.code}, root=${extractResult.rootPath}, elapsedMs=${Date.now() - startedAt}`)
        let failedStats: ImportResultStats = {
          extractedFileCount: extractResult.extractedFileCount,
          scannedFileCount: extractResult.scannedFileCount
        }
        return LogImportService.buildResult(extractResult.code, failedStats)
      }
      let baseStats: ImportBaseStats = {
        extractedFileCount: extractResult.extractedFileCount,
        scannedFileCount: extractResult.scannedFileCount
      }
      let result = await LogImportService.importFiles(extractResult.files, baseStats, importId, startedAt)
      LogUtils.info(TAG, `import done: importId=${importId}, code=${result.code}, extracted=${result.extractedFileCount}, scanned=${result.scannedFileCount}, parsed=${result.parsedEntryCount}, inserted=${result.insertedEntryCount}, skipped=${result.skippedDuplicateCount}, dropped=${result.droppedEntryCount}, failed=${result.failedEntryCount}, elapsedMs=${Date.now() - startedAt}`)
      return result
    } catch (err) {
      LogUtils.error(TAG, `import failed: importId=${importId}, err=${JSON.stringify(err)}, elapsedMs=${Date.now() - startedAt}`)
      return LogImportService.buildResult('extract_failed')
    }
  }

  static async importFiles(
    files: ImportedLogFile[],
    baseStats?: ImportBaseStats,
    importId: string = LogImportService.buildImportId(),
    startedAt: number = Date.now()
  ): Promise<ImportLogsResult> {
    let parsedEntries: LogEntry[] = []
    let droppedEntryCount = 0
    let failedEntryCount = 0
    let handledFileCount = 0
    LogUtils.info(TAG, `importFiles start: importId=${importId}, files=${files.length}`)
    for (let file of files) {
      for (let rule of LogImportService.rules) {
        if (!rule.canHandle(file)) {
          continue
        }
        try {
          handledFileCount++
          let fileStartedAt = Date.now()
          LogUtils.info(TAG, `rule parse start: importId=${importId}, rule=${rule.name}, file=${file.relativePath}, path=${file.path}`)
          let ruleResult = await rule.parse(file)
          parsedEntries = parsedEntries.concat(ruleResult.entries)
          droppedEntryCount += ruleResult.droppedCount
          failedEntryCount += ruleResult.failedCount
          LogUtils.info(TAG, `rule parse done: importId=${importId}, rule=${rule.name}, file=${file.relativePath}, entries=${ruleResult.entries.length}, dropped=${ruleResult.droppedCount}, failed=${ruleResult.failedCount}, elapsedMs=${Date.now() - fileStartedAt}`)
        } catch (err) {
          failedEntryCount++
          LogUtils.warn(TAG, `rule parse failed: importId=${importId}, rule=${rule.name}, file=${file.relativePath}, err=${JSON.stringify(err)}`)
        }
      }
    }
    let uniqueEntries = LogImportService.uniqueById(parsedEntries)
    let skippedDuplicateCount = parsedEntries.length - uniqueEntries.length
    let newEntries: LogEntry[] = []
    LogUtils.info(TAG, `dedupe done: importId=${importId}, handledFiles=${handledFileCount}, parsed=${parsedEntries.length}, unique=${uniqueEntries.length}, batchDuplicates=${skippedDuplicateCount}, elapsedMs=${Date.now() - startedAt}`)
    for (let entry of uniqueEntries) {
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
          extractedFileCount: baseStats?.extractedFileCount ?? files.length,
          scannedFileCount: baseStats?.scannedFileCount ?? files.length,
          parsedEntryCount: parsedEntries.length,
          skippedDuplicateCount,
          droppedEntryCount,
          failedEntryCount
        })
      }
    }
    LogUtils.info(TAG, `save done: importId=${importId}, newEntries=${newEntries.length}, skipped=${skippedDuplicateCount}, elapsedMs=${Date.now() - startedAt}`)
    return LogImportService.buildResult('ok', {
      extractedFileCount: baseStats?.extractedFileCount ?? files.length,
      scannedFileCount: baseStats?.scannedFileCount ?? files.length,
      parsedEntryCount: parsedEntries.length,
      insertedEntryCount: newEntries.length,
      skippedDuplicateCount,
      droppedEntryCount,
      failedEntryCount
    })
  }

  private static buildImportId(): string {
    return `import_${Date.now()}`
  }

  private static uniqueById(entries: LogEntry[]): LogEntry[] {
    let ids = new Set<string>()
    let result: LogEntry[] = []
    for (let entry of entries) {
      if (ids.has(entry.id)) {
        continue
      }
      ids.add(entry.id)
      result.push(entry)
    }
    return result
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
      droppedEntryCount: stats?.droppedEntryCount ?? 0,
      failedEntryCount: stats?.failedEntryCount ?? 0
    }
  }
}
