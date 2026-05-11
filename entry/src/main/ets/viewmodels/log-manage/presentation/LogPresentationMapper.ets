import {
  LogEventPresentationStrings,
  LogResultPresentationStrings,
  resolveLogEventResultLabel,
  resolveLogEventTypeLabel
} from '../../../constants/modules/LogManageStrings'
import { ResultText } from '../../../constants/StringCatalog'
import { LogEventResult, LogEventType } from '../../../models/LogModels'
import { formatStandardDateTime } from '../../../utils/DateTimeFormatUtils'

export interface LogEventTypeOption {
  label: string
  value: LogEventType
  icon?: Resource
}

export interface LogEventResultOption {
  label: string
  value: LogEventResult
}

export const LOG_EVENT_TYPE_OPTIONS: LogEventTypeOption[] = [
  { label: LogEventPresentationStrings.CRASH, value: LogEventType.CRASH },
  { label: LogEventPresentationStrings.FILE, value: LogEventType.FILE },
  { label: LogEventPresentationStrings.ACCOUNT, value: LogEventType.ACCOUNT },
  { label: LogEventPresentationStrings.PERMISSION, value: LogEventType.PERMISSION },
  { label: LogEventPresentationStrings.POWER, value: LogEventType.POWER }
]

export const LOG_EVENT_RESULT_OPTIONS: LogEventResultOption[] = [
  { label: ResultText.SUCCESS, value: LogEventResult.SUCCESS },
  { label: LogResultPresentationStrings.BLOCKED, value: LogEventResult.BLOCKED },
  { label: ResultText.FAILED, value: LogEventResult.FAILED }
]

export function getLogEventTypeLabel(type: LogEventType): string {
  return resolveLogEventTypeLabel(type)
}

export function getLogEventResultLabel(result: LogEventResult): string {
  return resolveLogEventResultLabel(result)
}

export function getLogEventResultColor(result: LogEventResult): string {
  switch (result) {
    case LogEventResult.SUCCESS:
      return '#4CAF50'
    case LogEventResult.BLOCKED:
      return '#FF9800'
    case LogEventResult.FAILED:
      return '#F44336'
    default:
      return '#9E9E9E'
  }
}

export function formatLogTimestamp(timestamp: number): string {
  return formatStandardDateTime(timestamp)
}
