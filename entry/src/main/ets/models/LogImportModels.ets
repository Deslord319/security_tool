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
