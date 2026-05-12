import fileIo from '@ohos.file.fs'
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

interface DecodedUtf8Chunk {
  text: string
  pending: Uint8Array
}

export class LogImportLineReader {
  static decodeUtf8ChunksForTest(chunks: Uint8Array[]): string {
    let result = ''
    let pendingBytes = new Uint8Array()
    for (let chunk of chunks) {
      let decoded = LogImportLineReader.decodeChunk(pendingBytes, chunk)
      result += decoded.text
      pendingBytes = decoded.pending
    }
    return `${result}${LogImportLineReader.flushDecoder(pendingBytes)}`
  }

  static async forEachUtf8Line(
    path: string,
    onLine: LogImportLineHandler,
    options?: LogImportLineReaderOptions
  ): Promise<LogImportLineReaderResult> {
    let file = LogImportLineReader.openReadOnly(path)
    let pendingBytes = new Uint8Array()
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
        let decoded = LogImportLineReader.decodeChunk(pendingBytes, new Uint8Array(buffer, 0, readCount))
        let chunk = decoded.text
        pendingBytes = decoded.pending
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
      let finalChunk = LogImportLineReader.flushDecoder(pendingBytes)
      if (finalChunk.length > 0) {
        pending = `${pending}${finalChunk}`
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

  private static decodeChunk(pendingBytes: Uint8Array, input: Uint8Array): DecodedUtf8Chunk {
    let bytes = LogImportLineReader.concatBytes(pendingBytes, input)
    let completeLength = LogImportLineReader.findCompleteUtf8Length(bytes)
    let completeBytes = LogImportLineReader.copyRange(bytes, 0, completeLength)
    return {
      text: completeBytes.length > 0 ? LogImportLineReader.decodeCompleteUtf8(completeBytes) : '',
      pending: LogImportLineReader.copyRange(bytes, completeLength, bytes.length)
    }
  }

  private static flushDecoder(pendingBytes: Uint8Array): string {
    if (pendingBytes.length === 0) {
      return ''
    }
    return LogImportLineReader.decodeCompleteUtf8(pendingBytes)
  }

  private static decodeCompleteUtf8(input: Uint8Array): string {
    let output = ''
    let index = 0
    while (index < input.length) {
      let first = input[index]
      if (first < 0x80) {
        output += String.fromCharCode(first)
        index++
      } else if ((first & 0xE0) === 0xC0 && LogImportLineReader.hasContinuationBytes(input, index, 1)) {
        let codePoint = ((first & 0x1F) << 6) | (input[index + 1] & 0x3F)
        output += String.fromCharCode(codePoint)
        index += 2
      } else if ((first & 0xF0) === 0xE0 && LogImportLineReader.hasContinuationBytes(input, index, 2)) {
        let codePoint = ((first & 0x0F) << 12) | ((input[index + 1] & 0x3F) << 6) | (input[index + 2] & 0x3F)
        output += String.fromCharCode(codePoint)
        index += 3
      } else if ((first & 0xF8) === 0xF0 && LogImportLineReader.hasContinuationBytes(input, index, 3)) {
        let codePoint = ((first & 0x07) << 18) |
          ((input[index + 1] & 0x3F) << 12) |
          ((input[index + 2] & 0x3F) << 6) |
          (input[index + 3] & 0x3F)
        output += LogImportLineReader.fromCodePoint(codePoint)
        index += 4
      } else {
        output += '\uFFFD'
        index++
      }
    }
    return output
  }

  private static concatBytes(first: Uint8Array, second: Uint8Array): Uint8Array {
    if (first.length === 0) {
      return second
    }
    let result = new Uint8Array(first.length + second.length)
    for (let index = 0; index < first.length; index++) {
      result[index] = first[index]
    }
    for (let index = 0; index < second.length; index++) {
      result[first.length + index] = second[index]
    }
    return result
  }

  private static copyRange(source: Uint8Array, start: number, end: number): Uint8Array {
    let length = Math.max(0, end - start)
    let result = new Uint8Array(length)
    for (let index = 0; index < length; index++) {
      result[index] = source[start + index]
    }
    return result
  }

  private static findCompleteUtf8Length(bytes: Uint8Array): number {
    if (bytes.length === 0) {
      return 0
    }
    let index = bytes.length - 1
    while (index >= 0 && LogImportLineReader.isUtf8ContinuationByte(bytes[index])) {
      index--
    }
    if (index < 0) {
      return bytes.length
    }
    let expectedLength = LogImportLineReader.getUtf8SequenceLength(bytes[index])
    if (expectedLength <= 1) {
      return bytes.length
    }
    let availableLength = bytes.length - index
    return availableLength < expectedLength ? index : bytes.length
  }

  private static isUtf8ContinuationByte(byte: number): boolean {
    return (byte & 0xC0) === 0x80
  }

  private static hasContinuationBytes(input: Uint8Array, start: number, count: number): boolean {
    if (start + count >= input.length) {
      return false
    }
    for (let offset = 1; offset <= count; offset++) {
      if (!LogImportLineReader.isUtf8ContinuationByte(input[start + offset])) {
        return false
      }
    }
    return true
  }

  private static fromCodePoint(codePoint: number): string {
    if (codePoint <= 0xFFFF) {
      return String.fromCharCode(codePoint)
    }
    let normalized = codePoint - 0x10000
    let high = 0xD800 + (normalized >> 10)
    let low = 0xDC00 + (normalized & 0x3FF)
    return `${String.fromCharCode(high)}${String.fromCharCode(low)}`
  }

  private static getUtf8SequenceLength(byte: number): number {
    if ((byte & 0x80) === 0) {
      return 1
    }
    if ((byte & 0xE0) === 0xC0) {
      return 2
    }
    if ((byte & 0xF0) === 0xE0) {
      return 3
    }
    if ((byte & 0xF8) === 0xF0) {
      return 4
    }
    return 1
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
