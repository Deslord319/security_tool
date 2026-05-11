import fileIo from '@ohos.file.fs'
import util from '@ohos.util'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'LogImportLineReader'
const READ_CHUNK_SIZE = 64 * 1024

export interface LogImportLineProgress {
  bytesRead: number
  linesRead: number
}

export interface LogImportLineReaderOptions {
  yieldEveryLines?: number
  byteProgressInterval?: number
  lineProgressInterval?: number
  onByteProgress?: (progress: LogImportLineProgress) => void
  onLineProgress?: (progress: LogImportLineProgress) => void
}

export interface LogImportLineReaderResult {
  bytesRead: number
  linesRead: number
}

type LogImportLineHandler = (line: string, lineNumber: number) => Promise<void>

export class LogImportLineReader {
  static async forEachUtf8Line(
    path: string,
    onLine: LogImportLineHandler,
    options?: LogImportLineReaderOptions
  ): Promise<LogImportLineReaderResult> {
    let file = LogImportLineReader.openReadOnly(path)
    let decoder = util.TextDecoder.create('utf-8')
    let pending = ''
    let lineNumber = 0
    let readOffset = 0
    let nextByteProgress = options?.byteProgressInterval ?? 0
    let nextLineProgress = options?.lineProgressInterval ?? 0
    try {
      while (true) {
        let buffer = new ArrayBuffer(READ_CHUNK_SIZE)
        let readCount = LogImportLineReader.read(file.fd, buffer, readOffset)
        if (readCount <= 0) {
          break
        }
        readOffset += readCount
        if (options?.byteProgressInterval && readOffset >= nextByteProgress) {
          options.onByteProgress?.({ bytesRead: readOffset, linesRead: lineNumber })
          nextByteProgress += options.byteProgressInterval
        }
        let chunk = decoder.decodeToString(new Uint8Array(buffer, 0, readCount))
        let lines = `${pending}${chunk}`.split(/\r?\n/)
        pending = lines.pop() ?? ''
        for (let line of lines) {
          lineNumber++
          await onLine(line, lineNumber)
          await LogImportLineReader.yieldIfNeeded(lineNumber, options?.yieldEveryLines)
          if (options?.lineProgressInterval && lineNumber >= nextLineProgress) {
            options.onLineProgress?.({ bytesRead: readOffset, linesRead: lineNumber })
            nextLineProgress += options.lineProgressInterval
          }
        }
      }
      if (pending.length > 0) {
        lineNumber++
        await onLine(pending, lineNumber)
      }
      return { bytesRead: readOffset, linesRead: lineNumber }
    } finally {
      LogImportLineReader.closeQuietly(file.fd, path)
    }
  }

  private static openReadOnly(path: string): fileIo.File {
    try {
      return fileIo.openSync(path, fileIo.OpenMode.READ_ONLY)
    } catch (err) {
      throw LogImportLineReader.toError(`open file ${path}`, err)
    }
  }

  private static read(fd: number, buffer: ArrayBuffer, offset: number): number {
    try {
      return fileIo.readSync(fd, buffer, {
        offset,
        length: READ_CHUNK_SIZE
      })
    } catch (err) {
      throw LogImportLineReader.toError('read file chunk', err)
    }
  }

  private static closeQuietly(fd: number, path: string): void {
    try {
      fileIo.closeSync(fd)
    } catch (err) {
      LogUtils.warn(TAG, `close file failed: path=${path}, err=${JSON.stringify(err)}`)
    }
  }

  private static async yieldIfNeeded(lineNumber: number, yieldEveryLines?: number): Promise<void> {
    if (!yieldEveryLines || lineNumber % yieldEveryLines !== 0) {
      return
    }
    await new Promise<void>((resolve: () => void) => {
      setTimeout(() => resolve(), 0)
    })
  }

  private static toError(action: string, err: Object): Error {
    return new Error(`${action} failed: ${JSON.stringify(err)}`)
  }
}
