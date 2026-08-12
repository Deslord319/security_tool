import { LogDetailTableRow, LogEntry } from '../../models/LogModels'

export function buildLogDetailRows(entry: LogEntry): LogDetailTableRow[] {
  const detailRows = removeRepeatedStructuredRows(entry.detailRows ?? [])
  let commonRows: LogDetailTableRow[] = []
  appendCommonRow(commonRows, detailRows, 'common.detail', '摘要', entry.detail, [
    'power.description', 'audit.description'
  ])
  appendCommonRow(commonRows, detailRows, 'common.processName', '进程名称', entry.processName, [
    'file.processName', 'crash.processName'
  ])
  appendCommonNumberRow(commonRows, detailRows, 'common.pid', 'PID', entry.pid, [
    'file.pid', 'crash.pid', 'permission.pid'
  ])
  appendCommonNumberRow(commonRows, detailRows, 'common.uid', 'UID', entry.uid, [
    'file.uid', 'crash.uid', 'permission.uid', 'account.userId'
  ])
  appendCommonRow(commonRows, detailRows, 'common.filePath', '文件路径', entry.filePath, ['file.filePath'])
  appendCommonRow(commonRows, detailRows, 'common.remoteAddr', '远端地址', entry.remoteAddr, [])
  appendCommonNumberRow(commonRows, detailRows, 'common.sourceEventId', '源事件 ID', entry.sourceEventId, [
    'file.eventId', 'crash.eventId', 'permission.eventId', 'account.eventId', 'power.eventId'
  ])
  appendCommonRow(commonRows, detailRows, 'common.rawEventName', '原始事件名', entry.rawEventName, [
    'power.eventName', 'crash.eventName'
  ])
  appendCommonRow(commonRows, detailRows, 'common.rawOutcome', '原始结果', entry.rawOutcome, [
    'account.authResultRaw'
  ])
  appendCommonRow(commonRows, detailRows, 'common.rawAction', '原始动作', entry.rawAction, ['file.operation'])
  return [...commonRows, ...detailRows]
}

function removeRepeatedStructuredRows(rows: LogDetailTableRow[]): LogDetailTableRow[] {
  let result: LogDetailTableRow[] = []
  for (const row of rows) {
    const fieldName = getFieldName(row.key)
    const isStructuredPayloadRow = row.key.startsWith('audit.content.') || row.key.startsWith('audit.metadata.')
    const alreadyDisplayed = isStructuredPayloadRow && result.some((existing: LogDetailTableRow): boolean =>
      !existing.key.startsWith('audit.content.') &&
        !existing.key.startsWith('audit.metadata.') &&
        getFieldName(existing.key) === fieldName &&
        existing.value.trim() === row.value.trim()
    )
    if (!alreadyDisplayed) {
      result.push(row)
    }
  }
  return result
}

function getFieldName(key: string): string {
  const separatorIndex = key.lastIndexOf('.')
  return (separatorIndex >= 0 ? key.slice(separatorIndex + 1) : key).toLowerCase()
}

function appendCommonNumberRow(
  rows: LogDetailTableRow[],
  detailRows: LogDetailTableRow[],
  key: string,
  label: string,
  value: number | undefined,
  equivalentKeys: string[]
): void {
  if (value !== undefined) {
    appendCommonRow(rows, detailRows, key, label, `${value}`, equivalentKeys)
  }
}

function appendCommonRow(
  rows: LogDetailTableRow[],
  detailRows: LogDetailTableRow[],
  key: string,
  label: string,
  value: string | undefined,
  equivalentKeys: string[]
): void {
  const normalized = (value || '').trim()
  if (normalized.length === 0 || hasEquivalentRow(detailRows, equivalentKeys, normalized)) {
    return
  }
  rows.push({ key, label, value: normalized } as LogDetailTableRow)
}

function hasEquivalentRow(rows: LogDetailTableRow[], keys: string[], value: string): boolean {
  return rows.some((row: LogDetailTableRow): boolean =>
    keys.includes(row.key) && row.value.trim() === value
  )
}
