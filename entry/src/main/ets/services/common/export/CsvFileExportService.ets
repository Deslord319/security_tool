import { common } from '@kit.AbilityKit'
import { fileIo, fileUri, picker } from '@kit.CoreFileKit'
import { LogUtils } from '../../../utils/LogUtils'

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
    try {
      let documentViewPicker = new picker.DocumentViewPicker(context)
      let saveOptions = new picker.DocumentSaveOptions()
      saveOptions.pickerMode = picker.DocumentPickerMode.DOWNLOAD
      let result = await documentViewPicker.save(saveOptions)
      if (result.length === 0) {
        return { success: false, code: 'user_canceled' }
      }
      let directoryUri = result[0]
      let targetPath = new fileUri.FileUri(`${directoryUri}/${fileName}`).path
      let file = fileIo.openSync(targetPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE)
      try {
        fileIo.writeSync(file.fd, content)
      } finally {
        fileIo.closeSync(file.fd)
      }
      return {
        success: true,
        code: 'ok',
        fileName,
        fullPath: targetPath
      }
    } catch (err) {
      LogUtils.error(TAG, `saveText failed: ${JSON.stringify(err)}`)
      return { success: false, code: 'io_failed' }
    }
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
    try {
      let documentViewPicker = new picker.DocumentViewPicker(context)
      let saveOptions = new picker.DocumentSaveOptions()
      saveOptions.pickerMode = picker.DocumentPickerMode.DOWNLOAD
      let result = await documentViewPicker.save(saveOptions)
      if (result.length === 0) {
        return { success: false, code: 'user_canceled' }
      }
      let directoryUri = result[0]
      let targetPath = new fileUri.FileUri(`${directoryUri}/${fileName}`).path
      let file = fileIo.openSync(targetPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE)
      try {
        let port: CsvFileWritePort = new CsvFileWritePortImpl(file.fd)
        await writer(port)
      } finally {
        fileIo.closeSync(file.fd)
      }
      return {
        success: true,
        code: 'ok',
        fileName,
        fullPath: targetPath
      }
    } catch (err) {
      LogUtils.error(TAG, `saveByWriter failed: ${JSON.stringify(err)}`)
      return { success: false, code: 'io_failed' }
    }
  }

  static escapeCsvValue(value: string): string {
    const normalized = value.replace(/"/g, '""')
    if (/[",\r\n]/.test(normalized)) {
      return `"${normalized}"`
    }
    return normalized
  }

  private static buildExportFileName(timestamp: number, prefix: string, extension: string): string {
    let date = new Date(timestamp)
    let pad = (n: number): string => n.toString().padStart(2, '0')
    let datePart = `${date.getFullYear()}${pad(date.getMonth() + 1)}${pad(date.getDate())}`
    let timePart = `${pad(date.getHours())}${pad(date.getMinutes())}${pad(date.getSeconds())}`
    return `${prefix}_${datePart}_${timePart}.${extension}`
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
