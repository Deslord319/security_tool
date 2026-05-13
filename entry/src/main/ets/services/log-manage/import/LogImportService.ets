import { common } from '@kit.AbilityKit'
import { fileUri, picker } from '@kit.CoreFileKit'
import { taskpool } from '@kit.ArkTS'
import { LogEntry } from '../../../models/LogModels'
import { LogUtils } from '../../../utils/LogUtils'
import { LogEntryRepository } from '../repository/LogEntryRepository'
import { buildLogStorageNaturalDayCutoff, LogStorageMaintenanceService } from '../maintenance/LogStorageMaintenanceService'
import { LogEntryNormalizer } from '../mapper/LogEntryNormalizer'
import { LogSettingsRepository } from '../repository/LogSettingsRepository'
import { LogArchiveExtractor } from './LogArchiveExtractor'
import { CrashLogImportRule } from './CrashLogImportRule'
import { KernelLogImportRule } from './KernelLogImportRule'
import { ImportedLogFile, LogImportRule } from './LogImportRule'
import { SystemLogImportRule } from './SystemLogImportRule'
import { LogImportParseTaskResult, runLogImportParseTask } from './LogImportBackgroundTask'

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
      let targetDirectory = await LogImportService.pickerPort.pickDirectory(context)
      if (!targetDirectory) {
        LogUtils.info(TAG, `import canceled: importId=${importId}, stage=pickDirectory`)
        return LogImportService.buildSelectionResult('user_canceled')
      }
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
    let skippedExpiredCount = 0
    let newEntries: LogEntry[] = []
    LogUtils.info(TAG, `dedupe done: importId=${importId}, handledFiles=${handledFileCount}, parsed=${parsedEntries.length}, unique=${uniqueEntries.length}, batchDuplicates=${skippedDuplicateCount}, elapsedMs=${Date.now() - startedAt}`)
    let storageConfig = await LogSettingsRepository.loadStorageConfig()
    let retentionDays = LogEntryNormalizer.normalizeRetentionDays(storageConfig.retentionDays)
    let cutoff = buildLogStorageNaturalDayCutoff(Date.now(), retentionDays)
    for (let entry of uniqueEntries) {
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
          extractedFileCount: baseStats?.extractedFileCount ?? files.length,
          scannedFileCount: baseStats?.scannedFileCount ?? files.length,
          parsedEntryCount: parsedEntries.length,
          skippedDuplicateCount,
          skippedExpiredCount,
          droppedEntryCount,
          failedEntryCount
        })
      }
    }
    LogUtils.info(TAG, `save done: importId=${importId}, newEntries=${newEntries.length}, skipped=${skippedDuplicateCount}, expired=${skippedExpiredCount}, elapsedMs=${Date.now() - startedAt}`)
    return LogImportService.buildResult('ok', {
      extractedFileCount: baseStats?.extractedFileCount ?? files.length,
      scannedFileCount: baseStats?.scannedFileCount ?? files.length,
      parsedEntryCount: parsedEntries.length,
      insertedEntryCount: newEntries.length,
      skippedDuplicateCount,
      skippedExpiredCount,
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
