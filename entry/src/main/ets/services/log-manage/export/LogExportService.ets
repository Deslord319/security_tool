import { common } from '@kit.AbilityKit'
import { LogUtils } from '../../../utils/LogUtils'
import {
  LogEntry
} from '../../../models/LogModels'
import {
  LogManageCsvStrings,
  resolveLogEventTypeLabel
} from '../../../constants/modules/LogManageStrings'
import { formatStandardDateTime } from '../../../utils/DateTimeFormatUtils'
import { ExportLogsResult, LogQuery } from '../common/LogManagePorts'
import { LogEntryRepository } from '../repository/LogEntryRepository'
import { CsvFileExportService, CsvFileWritePort } from '../../common/export/CsvFileExportService'

const TAG = 'LogExportService'
const EXPORT_PAGE_SIZE = 500

export class LogExportService {
  static async export(
    context: common.UIAbilityContext | null,
    query?: LogQuery,
    fileNamePrefix: string = 'security_log'
  ): Promise<ExportLogsResult> {
    if (!context) {
      return { success: false, code: 'context_missing' }
    }
    let totalCount = await LogEntryRepository.countByQuery(query)
    if (totalCount <= 0) {
      return { success: false, code: 'empty' }
    }
    try {
      return CsvFileExportService.saveByWriter(
        context,
        fileNamePrefix,
        async (writer: CsvFileWritePort): Promise<void> => {
          writer.append(`${CsvFileExportService.UTF8_BOM}${CsvFileExportService.buildCsvLine(LogManageCsvStrings.HEADERS)}\r\n`)
          let offset = 0
          while (offset < totalCount) {
            let entries = await LogEntryRepository.listByQuery(query, EXPORT_PAGE_SIZE, offset)
            if (entries.length === 0) {
              break
            }
            let chunk = LogExportService.buildCsvBody(entries)
            writer.append(chunk)
            offset += entries.length
          }
        },
        'csv'
      )
    } catch (err) {
      LogUtils.error(TAG, `export failed: ${JSON.stringify(err)}`)
      return { success: false, code: 'io_failed' }
    }
  }

  private static buildCsvBody(entries: LogEntry[]): string {
    let lines: string[] = []
    for (let entry of entries) {
      let time = formatStandardDateTime(entry.timestamp)
      let type = resolveLogEventTypeLabel(entry.eventType)
      let detail = entry.detail
      let process = entry.processName || ''
      let pid = entry.pid !== undefined ? entry.pid.toString() : ''
      lines.push(CsvFileExportService.buildCsvLine([time, type, detail, process, pid]))
    }
    return lines.length > 0 ? `${lines.join('\r\n')}\r\n` : ''
  }
}
