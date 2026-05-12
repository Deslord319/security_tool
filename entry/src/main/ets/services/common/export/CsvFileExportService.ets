import { common } from '@kit.AbilityKit'
import { fileIo, fileUri, picker } from '@kit.CoreFileKit'
import { LogUtils } from '../../../utils/LogUtils'
import { formatCompactDateTime } from '../../../utils/DateTimeFormatUtils'

const TAG = 'CsvFileExportService'

export interface CsvFileExportResult {
  success: boolean
  code: 'ok' | 'empty' | 'user_canceled' | 'io_failed' | 'context_missing'
  fileName?: string
  fullPath?: string
}

export interface CsvFileWritePort {
  append(content: string): void
}

type CsvExportWriter = (fd: number) => Promise<void>

class CsvFileWritePortImpl implements CsvFileWritePort {
  private fd: number

  constructor(fd: number) {
    this.fd = fd
  }

  append(content: string): void {
    if (content.length > 0) {
      CsvFileExportService.writeChunk(this.fd, content)
    }
  }
}

export class CsvFileExportService {
  static readonly UTF8_BOM: string = '\uFEFF'

  static async saveText(
    context: common.UIAbilityContext | null,
    content: string,
    fileNamePrefix: string = 'security_export',
    fileExtension: string = 'csv'
  ): Promise<CsvFileExportResult> {
    if (!context) {
      return { success: false, code: 'context_missing' }
    }
    if (content.length === 0) {
      return { success: false, code: 'empty' }
    }
    let fileName = CsvFileExportService.buildExportFileName(Date.now(), fileNamePrefix, fileExtension)
    return CsvFileExportService.withExportFile(
      context,
      fileName,
      'saveText',
      async (fd: number): Promise<void> => {
        CsvFileExportService.writeChunk(fd, content)
      }
    )
  }

  static async saveByWriter(
    context: common.UIAbilityContext | null,
    fileNamePrefix: string,
    writer: (port: CsvFileWritePort) => Promise<void>,
    fileExtension: string = 'csv'
  ): Promise<CsvFileExportResult> {
    if (!context) {
      return { success: false, code: 'context_missing' }
    }
    let fileName = CsvFileExportService.buildExportFileName(Date.now(), fileNamePrefix, fileExtension)
    return CsvFileExportService.withExportFile(
      context,
      fileName,
      'saveByWriter',
      async (fd: number): Promise<void> => {
        let port: CsvFileWritePort = new CsvFileWritePortImpl(fd)
        await writer(port)
      }
    )
  }

  private static async withExportFile(
    context: common.UIAbilityContext,
    fileName: string,
    operationName: string,
    writer: CsvExportWriter
  ): Promise<CsvFileExportResult> {
    try {
      let targetPath = await CsvFileExportService.pickTargetPath(context, fileName)
      if (!targetPath) {
        return { success: false, code: 'user_canceled' }
      }
      let file = CsvFileExportService.openExportFile(targetPath)
      try {
        await writer(file.fd)
      } finally {
        CsvFileExportService.closeExportFile(file.fd, targetPath)
      }
      return {
        success: true,
        code: 'ok',
        fileName,
        fullPath: targetPath
      }
    } catch (err) {
      LogUtils.error(TAG, `${operationName} failed: ${JSON.stringify(err)}`)
      return { success: false, code: 'io_failed' }
    }
  }

  private static async pickTargetPath(context: common.UIAbilityContext, fileName: string): Promise<string | null> {
    let documentViewPicker = new picker.DocumentViewPicker(context)
    let saveOptions = new picker.DocumentSaveOptions()
    saveOptions.pickerMode = picker.DocumentPickerMode.DOWNLOAD
    let result = await documentViewPicker.save(saveOptions)
    if (result.length === 0) {
      return null
    }
    let directoryUri = result[0]
    return new fileUri.FileUri(`${directoryUri}/${fileName}`).path
  }

  private static openExportFile(path: string): fileIo.File {
    try {
      return fileIo.openSync(path, CsvFileExportService.buildWritableOpenMode())
    } catch (err) {
      throw new Error(`open export file failed: ${JSON.stringify(err)}`)
    }
  }

  private static closeExportFile(fd: number, path: string): void {
    try {
      fileIo.closeSync(fd)
    } catch (err) {
      throw new Error(`close export file failed: path=${path}, err=${JSON.stringify(err)}`)
    }
  }

  static escapeCsvValue(value: string): string {
    const normalized = value.replace(/"/g, '""')
    if (/[",\r\n]/.test(normalized)) {
      return `"${normalized}"`
    }
    return normalized
  }

  static buildCsvLine(values: string[]): string {
    return values.map((value: string) => CsvFileExportService.escapeCsvValue(value)).join(',')
  }

  static buildCsvContent(headers: string[], rows: string[][], lineBreak: string = '\n', includeBom: boolean = true): string {
    let lines: string[] = [
      CsvFileExportService.buildCsvLine(headers)
    ]
    for (const row of rows) {
      lines.push(CsvFileExportService.buildCsvLine(row))
    }
    return `${includeBom ? CsvFileExportService.UTF8_BOM : ''}${lines.join(lineBreak)}`
  }

  private static buildExportFileName(timestamp: number, prefix: string, extension: string): string {
    return `${prefix}_${formatCompactDateTime(timestamp)}.${extension}`
  }

  private static buildWritableOpenMode(): number {
    return fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC
  }

  static buildWritableOpenModeForTest(): number {
    return CsvFileExportService.buildWritableOpenMode()
  }

  static writeChunk(fd: number, content: string): void {
    try {
      fileIo.writeSync(fd, content)
    } catch (err) {
      LogUtils.error(TAG, `writeChunk failed: ${JSON.stringify(err)}`)
      throw new Error('writeChunk failed')
    }
  }
}
