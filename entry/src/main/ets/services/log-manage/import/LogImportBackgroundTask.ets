import { LogEntry } from '../../../models/LogModels'
import { LogUtils } from '../../../utils/LogUtils'
import { LogArchiveExtractor } from './LogArchiveExtractor'
import { CrashLogImportRule } from './CrashLogImportRule'
import { KernelLogImportRule } from './KernelLogImportRule'
import { LogImportRule } from './LogImportRule'
import { SystemLogImportRule } from './SystemLogImportRule'

export interface LogImportParseTaskResult {
  success: boolean
  code: 'ok' | 'invalid_archive' | 'extract_failed'
  extractedFileCount: number
  scannedFileCount: number
  parsedEntryCount: number
  skippedBatchDuplicateCount: number
  droppedEntryCount: number
  failedEntryCount: number
  entries: LogEntry[]
}

@Concurrent
export async function runLogImportParseTask(archivePath: string, targetDirectory: string): Promise<LogImportParseTaskResult> {
  let tag = 'LogImportBackgroundTask'
  let importId = `import_task_${Date.now()}`
  let startedAt = Date.now()
  try {
    LogUtils.info(tag, `parse task start: importId=${importId}, archive=${archivePath}, target=${targetDirectory}`)
    let extractResult = await LogArchiveExtractor.extract(archivePath, targetDirectory)
    if (!extractResult.success) {
      LogUtils.warn(tag, `parse task extract failed: importId=${importId}, code=${extractResult.code}, elapsedMs=${Date.now() - startedAt}`)
      return {
        success: false,
        code: extractResult.code,
        extractedFileCount: extractResult.extractedFileCount,
        scannedFileCount: extractResult.scannedFileCount,
        parsedEntryCount: 0,
        skippedBatchDuplicateCount: 0,
        droppedEntryCount: 0,
        failedEntryCount: 0,
        entries: []
      }
    }

    let rules: LogImportRule[] = [new KernelLogImportRule(), new CrashLogImportRule(), new SystemLogImportRule()]
    let parsedEntries: LogEntry[] = []
    let droppedEntryCount = 0
    let failedEntryCount = 0
    let handledFileCount = 0
    for (let file of extractResult.files) {
      for (let rule of rules) {
        if (!rule.canHandle(file)) {
          continue
        }
        try {
          handledFileCount++
          let fileStartedAt = Date.now()
          LogUtils.info(tag, `rule parse start: importId=${importId}, rule=${rule.name}, file=${file.relativePath}, path=${file.path}`)
          let ruleResult = await rule.parse(file)
          parsedEntries = parsedEntries.concat(ruleResult.entries)
          droppedEntryCount += ruleResult.droppedCount
          failedEntryCount += ruleResult.failedCount
          LogUtils.info(tag, `rule parse done: importId=${importId}, rule=${rule.name}, file=${file.relativePath}, entries=${ruleResult.entries.length}, dropped=${ruleResult.droppedCount}, failed=${ruleResult.failedCount}, elapsedMs=${Date.now() - fileStartedAt}`)
        } catch (err) {
          failedEntryCount++
          LogUtils.warn(tag, `rule parse failed: importId=${importId}, rule=${rule.name}, file=${file.relativePath}, err=${JSON.stringify(err)}`)
        }
      }
    }

    let ids = new Set<string>()
    let entries: LogEntry[] = []
    for (let entry of parsedEntries) {
      if (ids.has(entry.id)) {
        continue
      }
      ids.add(entry.id)
      entries.push(entry)
    }
    let skippedBatchDuplicateCount = parsedEntries.length - entries.length
    LogUtils.info(tag, `parse dedupe done: importId=${importId}, handledFiles=${handledFileCount}, parsed=${parsedEntries.length}, unique=${entries.length}, batchDuplicates=${skippedBatchDuplicateCount}, elapsedMs=${Date.now() - startedAt}`)
    LogUtils.info(tag, `parse task done: importId=${importId}, extracted=${extractResult.extractedFileCount}, scanned=${extractResult.scannedFileCount}, parsed=${parsedEntries.length}, unique=${entries.length}, dropped=${droppedEntryCount}, failed=${failedEntryCount}, elapsedMs=${Date.now() - startedAt}`)
    return {
      success: true,
      code: 'ok',
      extractedFileCount: extractResult.extractedFileCount,
      scannedFileCount: extractResult.scannedFileCount,
      parsedEntryCount: parsedEntries.length,
      skippedBatchDuplicateCount,
      droppedEntryCount,
      failedEntryCount,
      entries
    }
  } catch (err) {
    LogUtils.error(tag, `parse task failed: importId=${importId}, err=${JSON.stringify(err)}, elapsedMs=${Date.now() - startedAt}`)
    return {
      success: false,
      code: 'extract_failed',
      extractedFileCount: 0,
      scannedFileCount: 0,
      parsedEntryCount: 0,
      skippedBatchDuplicateCount: 0,
      droppedEntryCount: 0,
      failedEntryCount: 0,
      entries: []
    }
  }
}
