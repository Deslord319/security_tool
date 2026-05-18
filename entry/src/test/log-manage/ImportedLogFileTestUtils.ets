import { ImportedLogFile } from '../../main/ets/services/log-manage/import/LogImportRule'

export function createImportedLogFile(
  testContents: Map<string, string>,
  prefix: string,
  relativePath: string,
  content?: string
): ImportedLogFile {
  let path = `${prefix}_${relativePath.replace(/\//g, '_')}_${Date.now()}_${Math.floor(Math.random() * 100000)}`
  if (content !== undefined) {
    testContents.set(path, content)
  }
  return {
    path,
    fileName: relativePath.substring(relativePath.lastIndexOf('/') + 1),
    relativePath,
    normalizedPath: relativePath
  }
}

export async function readImportedLogFileLinesForTest(
  testContents: Map<string, string>,
  file: ImportedLogFile,
  onLine: (line: string, lineNumber: number) => Promise<void>
): Promise<void> {
  let content = testContents.get(file.path) ?? ''
  let lines = content.split(/\r?\n/)
  for (let index = 0; index < lines.length; index++) {
    await onLine(lines[index], index + 1)
  }
}
