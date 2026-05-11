import { CsvFileExportResult } from '../../main/ets/services/common/export/CsvFileExportService'

export function createCsvFileExportResult(
  success: boolean,
  code: 'ok' | 'empty' | 'user_canceled' | 'io_failed' | 'context_missing',
  fileName?: string,
  fullPath?: string
): CsvFileExportResult {
  return {
    success,
    code,
    fileName,
    fullPath
  }
}

export function createSuccessfulCsvFileExportResult(fileName: string, fullPath: string): CsvFileExportResult {
  return createCsvFileExportResult(true, 'ok', fileName, fullPath)
}
