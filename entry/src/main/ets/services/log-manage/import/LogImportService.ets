import { common } from '@kit.AbilityKit'
import { fileUri, picker } from '@kit.CoreFileKit'
import { LogEntry } from '../../../models/DataModels'
import { LogUtils } from '../../../utils/LogUtils'
import { LogEntryRepository } from '../repository/LogEntryRepository'
import { LogStorageMaintenanceService } from '../maintenance/LogStorageMaintenanceService'
import { LogArchiveExtractor } from './LogArchiveExtractor'
import { KernelLogImportRule } from './KernelLogImportRule'
import { ImportedLogFile, LogImportRule } from './LogImportRule'

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
  private static rules: LogImportRule[] = [new KernelLogImportRule()]
  private static pickerPort: LogImportPickerPort = new DefaultLogImportPicker()

  static setRulesForTest(rules: LogImportRule[]): void {
    LogImportService.rules = rules
  }

  static setPickerForTest(pickerPort: LogImportPickerPort): void {
    LogImportService.pickerPort = pickerPort
  }

  static resetTestPorts(): void {
    LogImportService.rules = [new KernelLogImportRule()]
    LogImportService.pickerPort = new DefaultLogImportPicker()
  }

  static async import(context: common.UIAbilityContext): Promise<ImportLogsResult> {
    try {
      let archivePath = await LogImportService.pickerPort.pickZip(context)
      if (!archivePath) {
        return LogImportService.buildResult('user_canceled')
      }
      let targetDirectory = await LogImportService.pickerPort.pickDirectory(context)
      if (!targetDirectory) {
        return LogImportService.buildResult('user_canceled')
      }
      let extractResult = await LogArchiveExtractor.extract(archivePath, targetDirectory)
      if (!extractResult.success) {
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
      return LogImportService.importFiles(extractResult.files, baseStats)
    } catch (err) {
      LogUtils.error(TAG, `import failed: ${JSON.stringify(err)}`)
      return LogImportService.buildResult('extract_failed')
    }
  }

  static async importFiles(
    files: ImportedLogFile[],
    baseStats?: ImportBaseStats
  ): Promise<ImportLogsResult> {
    let parsedEntries: LogEntry[] = []
    let droppedEntryCount = 0
    let failedEntryCount = 0
    for (let file of files) {
      for (let rule of LogImportService.rules) {
        if (!rule.canHandle(file)) {
          continue
        }
        try {
          let ruleResult = await rule.parse(file)
          parsedEntries = parsedEntries.concat(ruleResult.entries)
          droppedEntryCount += ruleResult.droppedCount
          failedEntryCount += ruleResult.failedCount
        } catch (err) {
          failedEntryCount++
          LogUtils.warn(TAG, `rule parse failed: rule=${rule.name}, file=${file.relativePath}, err=${JSON.stringify(err)}`)
        }
      }
    }
    let uniqueEntries = LogImportService.uniqueById(parsedEntries)
    let skippedDuplicateCount = parsedEntries.length - uniqueEntries.length
    let newEntries: LogEntry[] = []
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
