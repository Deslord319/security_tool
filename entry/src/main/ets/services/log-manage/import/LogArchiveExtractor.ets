import zlib from '@ohos.zlib'
import fileIo from '@ohos.file.fs'
import { fileUri } from '@kit.CoreFileKit'
import { LogUtils } from '../../../utils/LogUtils'
import { ImportedLogFile } from './LogImportRule'

const TAG = 'LogArchiveExtractor'
const MAX_RECURSION_DEPTH = 4

export interface ExtractedLogFilesResult {
  success: boolean
  code: 'ok' | 'invalid_archive' | 'extract_failed'
  rootPath: string
  files: ImportedLogFile[]
  extractedFileCount: number
  scannedFileCount: number
  rejectedEntryCount: number
}

export class LogArchiveExtractor {
  static async extract(archiveUriOrPath: string, targetDirectoryUriOrPath: string): Promise<ExtractedLogFilesResult> {
    let archivePath = LogArchiveExtractor.toPath(archiveUriOrPath)
    let targetDirectory = LogArchiveExtractor.toPath(targetDirectoryUriOrPath)
    if (!LogArchiveExtractor.isZipFile(archivePath)) {
      return LogArchiveExtractor.buildFailedResult('invalid_archive', targetDirectory)
    }
    let rootPath = LogArchiveExtractor.joinPath(
      targetDirectory,
      `security_log_import_${Date.now()}`
    )
    try {
      await LogArchiveExtractor.ensureDirectory(rootPath)
      await LogArchiveExtractor.extractZipRecursively(archivePath, rootPath, 0)
      let files = await LogArchiveExtractor.collectFiles(rootPath)
      return {
        success: true,
        code: 'ok',
        rootPath,
        files,
        extractedFileCount: files.length,
        scannedFileCount: files.length,
        rejectedEntryCount: 0
      }
    } catch (err) {
      LogUtils.error(TAG, `extract failed: ${JSON.stringify(err)}`)
      return LogArchiveExtractor.buildFailedResult('extract_failed', rootPath)
    }
  }

  private static async extractZipRecursively(zipPath: string, targetDirectory: string, depth: number): Promise<void> {
    if (depth > MAX_RECURSION_DEPTH) {
      return
    }
    await LogArchiveExtractor.ensureDirectory(targetDirectory)
    await LogArchiveExtractor.decompressZip(zipPath, targetDirectory)
    let nestedZipPaths = await LogArchiveExtractor.findFiles(targetDirectory, (path: string) => LogArchiveExtractor.isZipFile(path))
    for (let nestedZipPath of nestedZipPaths) {
      if (LogArchiveExtractor.normalizePath(nestedZipPath) === LogArchiveExtractor.normalizePath(zipPath)) {
        continue
      }
      let nestedDirectory = `${nestedZipPath}_extracted`
      await LogArchiveExtractor.ensureDirectory(nestedDirectory)
      await LogArchiveExtractor.extractZipRecursively(nestedZipPath, nestedDirectory, depth + 1)
    }
  }

  private static async collectFiles(rootPath: string): Promise<ImportedLogFile[]> {
    let paths = await LogArchiveExtractor.findFiles(rootPath, (_path: string) => true)
    let files: ImportedLogFile[] = []
    for (let path of paths) {
      let relativePath = LogArchiveExtractor.relativePath(rootPath, path)
      files.push({
        path,
        fileName: LogArchiveExtractor.basename(path),
        relativePath,
        normalizedPath: LogArchiveExtractor.normalizePath(relativePath)
      })
    }
    return files
  }

  private static async findFiles(rootPath: string, predicate: (path: string) => boolean): Promise<string[]> {
    let result: string[] = []
    let entries = await LogArchiveExtractor.listFile(rootPath)
    for (let entry of entries) {
      let path = LogArchiveExtractor.joinPath(rootPath, entry)
      let stat = await LogArchiveExtractor.stat(path)
      if (LogArchiveExtractor.isDirectory(stat, path)) {
        let nested = await LogArchiveExtractor.findFiles(path, predicate)
        result = result.concat(nested)
      } else if (LogArchiveExtractor.isFile(stat, path) && predicate(path)) {
        result.push(path)
      }
    }
    return result
  }

  private static async ensureDirectory(path: string): Promise<void> {
    try {
      if (await fileIo.access(path)) {
        return
      }
    } catch (_) {
    }
    await LogArchiveExtractor.mkdir(path)
  }

  private static async decompressZip(zipPath: string, targetDirectory: string): Promise<void> {
    try {
      await zlib.decompressFile(zipPath, targetDirectory)
    } catch (err) {
      throw LogArchiveExtractor.toIoError(`decompress zip ${zipPath}`, err)
    }
  }

  private static async listFile(path: string): Promise<string[]> {
    try {
      return await fileIo.listFile(path)
    } catch (err) {
      throw LogArchiveExtractor.toIoError(`list directory ${path}`, err)
    }
  }

  private static async stat(path: string): Promise<fileIo.Stat> {
    try {
      return await fileIo.stat(path)
    } catch (err) {
      throw LogArchiveExtractor.toIoError(`stat ${path}`, err)
    }
  }

  private static isDirectory(stat: fileIo.Stat, path: string): boolean {
    try {
      return stat.isDirectory()
    } catch (err) {
      throw LogArchiveExtractor.toIoError(`check directory ${path}`, err)
    }
  }

  private static isFile(stat: fileIo.Stat, path: string): boolean {
    try {
      return stat.isFile()
    } catch (err) {
      throw LogArchiveExtractor.toIoError(`check file ${path}`, err)
    }
  }

  private static async mkdir(path: string): Promise<void> {
    try {
      await fileIo.mkdir(path, true)
    } catch (err) {
      throw LogArchiveExtractor.toIoError(`mkdir ${path}`, err)
    }
  }

  private static toPath(uriOrPath: string): string {
    if (uriOrPath.startsWith('file://')) {
      return new fileUri.FileUri(uriOrPath).path
    }
    return uriOrPath
  }

  private static isZipFile(path: string): boolean {
    return path.toLowerCase().endsWith('.zip')
  }

  private static joinPath(parent: string, child: string): string {
    let cleanParent = parent.replace(/\\/g, '/').replace(/\/+$/g, '')
    let cleanChild = child.replace(/\\/g, '/').replace(/^\/+/g, '')
    return `${cleanParent}/${cleanChild}`
  }

  private static basename(path: string): string {
    let normalized = LogArchiveExtractor.normalizePath(path)
    let index = normalized.lastIndexOf('/')
    return index >= 0 ? normalized.substring(index + 1) : normalized
  }

  private static relativePath(rootPath: string, path: string): string {
    let root = LogArchiveExtractor.normalizePath(rootPath).replace(/\/+$/g, '')
    let normalized = LogArchiveExtractor.normalizePath(path)
    if (normalized.startsWith(`${root}/`)) {
      return normalized.substring(root.length + 1)
    }
    return normalized
  }

  private static normalizePath(path: string): string {
    return path.replace(/\\/g, '/').replace(/\/+/g, '/')
  }

  private static toIoError(action: string, err: Object): Error {
    return new Error(`${action} failed: ${JSON.stringify(err)}`)
  }

  private static buildFailedResult(
    code: 'invalid_archive' | 'extract_failed',
    rootPath: string
  ): ExtractedLogFilesResult {
    return {
      success: false,
      code,
      rootPath,
      files: [],
      extractedFileCount: 0,
      scannedFileCount: 0,
      rejectedEntryCount: 0
    }
  }
}
