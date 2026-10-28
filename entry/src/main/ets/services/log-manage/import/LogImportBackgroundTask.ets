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
import {
  LogManageKernelImportStrings,
  LogManageSystemImportStrings
} from '../../../constants/modules/LogManageStrings'

export interface LogImportPrepareTaskResult {
  success: boolean
  code: 'ok' | 'invalid_archive' | 'extract_failed'
  extractedFileCount: number
  scannedFileCount: number
  files: ImportedLogFile[]
}

/**
 * 在主线程构建导入分类文案映射（键为资源名），任务线程内静态文案门面不可见，
 * 文案必须由此解析后作为可序列化数据传入解析任务。
 */
export function buildLogImportCategoryLabels(): Record<string, string> {
  return {
    'log_manage_kernel_import_category_security_denied': LogManageKernelImportStrings.CATEGORY_SECURITY_DENIED,
    'log_manage_kernel_import_category_binder_permission': LogManageKernelImportStrings.CATEGORY_BINDER_PERMISSION,
    'log_manage_kernel_import_category_hmdec': LogManageKernelImportStrings.CATEGORY_HMDEC,
    'log_manage_kernel_import_category_fs_devfs': LogManageKernelImportStrings.CATEGORY_FS_DEVFS,
    'log_import_category_system_service_timeout': LogManageSystemImportStrings.CATEGORY_SERVICE_TIMEOUT,
    'log_import_category_system_window_exception': LogManageSystemImportStrings.CATEGORY_WINDOW_EXCEPTION,
    'log_import_category_system_hisi_diag': LogManageSystemImportStrings.CATEGORY_HISI_DIAG,
    'log_import_category_system_fsck': LogManageSystemImportStrings.CATEGORY_FSCK,
    'log_import_category_system_resize': LogManageSystemImportStrings.CATEGORY_RESIZE,
    'log_import_category_system_meminfo': LogManageSystemImportStrings.CATEGORY_MEMINFO,
    'log_import_category_system_memview': LogManageSystemImportStrings.CATEGORY_MEMVIEW,
    'log_import_category_system_memory_leak': LogManageSystemImportStrings.CATEGORY_MEMORY_LEAK,
    'log_import_category_system_updater_log': LogManageSystemImportStrings.CATEGORY_UPDATER_LOG,
    'log_import_category_system_updater_stage': LogManageSystemImportStrings.CATEGORY_UPDATER_STAGE,
    'log_import_category_system_installer': LogManageSystemImportStrings.CATEGORY_INSTALLER,
    'log_import_category_system_hsld': LogManageSystemImportStrings.CATEGORY_HSLD
  }
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
export async function runLogImportFileParseTask(
  file: ImportedLogFile,
  categoryLabels: Record<string, string>
): Promise<LogImportRuleResult> {
  let tag = 'LogImportBackgroundTask'
  let startedAt = Date.now()
  let rules: LogImportRule[] = [
    new KernelLogImportRule(categoryLabels),
    new CrashLogImportRule(),
    new SystemLogImportRule(categoryLabels)
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
