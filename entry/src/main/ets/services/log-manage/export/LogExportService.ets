import { common } from '@kit.AbilityKit'
import { fileIo, fileUri, picker } from '@kit.CoreFileKit'
import { LogUtils } from '../../../utils/LogUtils'
import {
  LogEntry,
  formatLogTimestamp,
  getLogEventResultLabel,
  getLogEventTypeLabel
} from '../../../models/DataModels'
import { LogManageStrings } from '../../../constants/modules/LogManageStrings'
import { ExportLogsResult } from '../common/LogManagePorts'

const TAG = 'LogExportService'

interface ExportPickerPort {
  save(options: picker.DocumentSaveOptions): Promise<string[]>
}

interface ExportFileHandle {
  fd: number
}

interface LogExportServiceTestDeps {
  nowProvider?: () => number
  pickerFactory?: (context: common.UIAbilityContext) => ExportPickerPort
  buildPathFn?: (directoryUri: string, fileName: string) => string
  openFileFn?: (path: string) => ExportFileHandle
  writeFileFn?: (fd: number, content: string) => void
  closeFileFn?: (fd: number) => void
}

export class LogExportService {
  private static nowProvider: () => number = () => Date.now()
  private static pickerFactory: (context: common.UIAbilityContext) => ExportPickerPort =
    (context: common.UIAbilityContext): ExportPickerPort => new picker.DocumentViewPicker(context)
  private static buildPathFn: (directoryUri: string, fileName: string) => string =
    (directoryUri: string, fileName: string): string => new fileUri.FileUri(`${directoryUri}/${fileName}`).path
  private static openFileFn: (path: string) => ExportFileHandle =
    (path: string): ExportFileHandle => {
      let file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE)
      return { fd: file.fd }
    }
  private static writeFileFn: (fd: number, content: string) => void =
    (fd: number, content: string): void => {
      fileIo.writeSync(fd, content)
    }
  private static closeFileFn: (fd: number) => void =
    (fd: number): void => {
      fileIo.closeSync(fd)
    }

  static async export(
    context: common.UIAbilityContext | null,
    entries: LogEntry[],
    fileNamePrefix: string = 'security_log'
  ): Promise<ExportLogsResult> {
    if (!context) {
      return { success: false, code: 'context_missing' }
    }
    if (entries.length === 0) {
      return { success: false, code: 'empty' }
    }
    let csvContent = LogExportService.buildCsvContent(entries).trim()
    return LogExportService.saveCsvContent(context, csvContent, fileNamePrefix)
  }

  static async saveCsvContent(
    context: common.UIAbilityContext | null,
    csvContent: string,
    fileNamePrefix: string = 'security_log'
  ): Promise<ExportLogsResult> {
    if (!context) {
      return { success: false, code: 'context_missing' }
    }
    if (csvContent.length === 0) {
      return { success: false, code: 'empty' }
    }
    let timestamp = LogExportService.nowProvider()
    let fileName = LogExportService.buildExportFileName(timestamp, fileNamePrefix)
    try {
      let documentViewPicker = LogExportService.pickerFactory(context)
      let saveOptions = new picker.DocumentSaveOptions()
      saveOptions.pickerMode = picker.DocumentPickerMode.DOWNLOAD
      let result = await documentViewPicker.save(saveOptions)
      if (result.length === 0) {
        return { success: false, code: 'user_canceled' }
      }
      let directoryUri = result[0]
      let targetPath = LogExportService.buildPathFn(directoryUri, fileName)
      let file = LogExportService.openFileFn(targetPath)
      try {
        LogExportService.writeFileFn(file.fd, csvContent)
      } finally {
        LogExportService.closeFileFn(file.fd)
      }
      return {
        success: true,
        code: 'ok',
        fileName,
        fullPath: targetPath
      }
    } catch (err) {
      LogUtils.error(TAG, `export failed: ${JSON.stringify(err)}`)
      return { success: false, code: 'io_failed' }
    }
  }

  static buildCsvContent(entries: LogEntry[]): string {
    let header = LogManageStrings.buildCsvHeader()
    let lines: string[] = [header]
    for (let entry of entries) {
      let time = formatLogTimestamp(entry.timestamp)
      let type = getLogEventTypeLabel(entry.eventType)
      let detail = `"${entry.detail.replace(/"/g, '""')}"`
      let process = entry.processName || ''
      let pid = entry.pid !== undefined ? entry.pid.toString() : ''
      let result = getLogEventResultLabel(entry.result)
      lines.push(`${time},${type},${detail},${process},${pid},${result}`)
    }
    return lines.join('\r\n')
  }

  private static buildExportFileName(timestamp: number, prefix: string): string {
    let date = new Date(timestamp)
    let pad = (n: number): string => n.toString().padStart(2, '0')
    let datePart = `${date.getFullYear()}${pad(date.getMonth() + 1)}${pad(date.getDate())}`
    let timePart = `${pad(date.getHours())}${pad(date.getMinutes())}${pad(date.getSeconds())}`
    return `${prefix}_${datePart}_${timePart}.csv`
  }

  static setTestDeps(deps: LogExportServiceTestDeps): void {
    if (deps.nowProvider) {
      LogExportService.nowProvider = deps.nowProvider
    }
    if (deps.pickerFactory) {
      LogExportService.pickerFactory = deps.pickerFactory
    }
    if (deps.buildPathFn) {
      LogExportService.buildPathFn = deps.buildPathFn
    }
    if (deps.openFileFn) {
      LogExportService.openFileFn = deps.openFileFn
    }
    if (deps.writeFileFn) {
      LogExportService.writeFileFn = deps.writeFileFn
    }
    if (deps.closeFileFn) {
      LogExportService.closeFileFn = deps.closeFileFn
    }
  }

  static resetForTest(): void {
    LogExportService.nowProvider = () => Date.now()
    LogExportService.pickerFactory = (context: common.UIAbilityContext): ExportPickerPort =>
      new picker.DocumentViewPicker(context)
    LogExportService.buildPathFn = (directoryUri: string, fileName: string): string =>
      new fileUri.FileUri(`${directoryUri}/${fileName}`).path
    LogExportService.openFileFn = (path: string): ExportFileHandle => {
      let file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE)
      return { fd: file.fd }
    }
    LogExportService.writeFileFn = (fd: number, content: string): void => {
      fileIo.writeSync(fd, content)
    }
    LogExportService.closeFileFn = (fd: number): void => {
      fileIo.closeSync(fd)
    }
  }
}
