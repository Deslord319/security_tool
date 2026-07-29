import { LogUtils } from '../../../utils/LogUtils'
import { LogArchiveExtractor } from './LogArchiveExtractor'
import { CrashLogImportRule } from './CrashLogImportRule'
import { KernelLogImportRule } from './KernelLogImportRule'
import {
  createEmptyLogImportRuleResult,
  ImportedLogFile,
  LogImportRule,
  LogImportRuleResult
} from './LogImportRule'
import { SystemLogImportRule } from './SystemLogImportRule'

export interface LogImportPrepareTaskResult {
  success: boolean
  code: 'ok' | 'invalid_archive' | 'extract_failed'
  extractedFileCount: number
  scannedFileCount: number
  files: ImportedLogFile[]
}

@Concurrent
export async function runLogImportPrepareTask(
  archivePath: string,
  targetDirectory: string
): Promise<LogImportPrepareTaskResult> {
  let tag = 'LogImportBackgroundTask'
  let importId = `import_prepare_${Date.now()}`
  let startedAt = Date.now()
  try {
    LogUtils.info(tag, `prepare start: importId=${importId}, archive=${archivePath}, target=${targetDirectory}`)
    let extractResult = await LogArchiveExtractor.extract(archivePath, targetDirectory)
    if (!extractResult.success) {
      LogUtils.warn(tag, `prepare extract failed: importId=${importId}, code=${extractResult.code}, elapsedMs=${Date.now() - startedAt}`)
      return {
        success: false,
        code: extractResult.code,
        extractedFileCount: extractResult.extractedFileCount,
        scannedFileCount: extractResult.scannedFileCount,
        files: []
      }
    }

    let rules: LogImportRule[] = [
      new KernelLogImportRule(),
      new CrashLogImportRule(),
      new SystemLogImportRule()
    ]
    let files: ImportedLogFile[] = []
    for (let file of extractResult.files) {
      for (let rule of rules) {
        if (rule.canHandle(file)) {
          files.push(file)
          break
        }
      }
    }
    LogUtils.info(tag, `prepare done: importId=${importId}, extracted=${extractResult.extractedFileCount}, scanned=${extractResult.scannedFileCount}, candidates=${files.length}, elapsedMs=${Date.now() - startedAt}`)
    return {
      success: true,
      code: 'ok',
      extractedFileCount: extractResult.extractedFileCount,
      scannedFileCount: extractResult.scannedFileCount,
      files
    }
  } catch (err) {
    LogUtils.error(tag, `prepare failed: importId=${importId}, err=${JSON.stringify(err)}, elapsedMs=${Date.now() - startedAt}`)
    return {
      success: false,
      code: 'extract_failed',
      extractedFileCount: 0,
      scannedFileCount: 0,
      files: []
    }
  }
}

@Concurrent
export async function runLogImportFileParseTask(file: ImportedLogFile): Promise<LogImportRuleResult> {
  let tag = 'LogImportBackgroundTask'
  let startedAt = Date.now()
  let rules: LogImportRule[] = [
    new KernelLogImportRule(),
    new CrashLogImportRule(),
    new SystemLogImportRule()
  ]
  for (let rule of rules) {
    if (!rule.canHandle(file)) {
      continue
    }
    try {
      LogUtils.info(tag, `file parse start: rule=${rule.name}, file=${file.relativePath}`)
      let result = await rule.parse(file)
      LogUtils.info(tag, `file parse done: rule=${rule.name}, file=${file.relativePath}, entries=${result.entries.length}, dropped=${result.droppedCount}, failed=${result.failedCount}, elapsedMs=${Date.now() - startedAt}`)
      return result
    } catch (err) {
      LogUtils.warn(tag, `file parse failed: rule=${rule.name}, file=${file.relativePath}, err=${JSON.stringify(err)}, elapsedMs=${Date.now() - startedAt}`)
      return {
        entries: [],
        droppedCount: 0,
        failedCount: 1
      }
    }
  }
  return createEmptyLogImportRuleResult()
}
