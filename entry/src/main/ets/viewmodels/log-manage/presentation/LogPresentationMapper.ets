import {
  resolveLogEventResultLabel,
  resolveLogEventTypeLabel
} from '../../../constants/modules/LogManageStrings'
import {
  ALL_LOG_EVENT_RESULTS,
  ALL_LOG_EVENT_TYPES,
  LogEventResult,
  LogEventType
} from '../../../models/LogModels'
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

export const LOG_EVENT_TYPE_OPTIONS: LogEventTypeOption[] = ALL_LOG_EVENT_TYPES.map((value: LogEventType): LogEventTypeOption => ({
  label: resolveLogEventTypeLabel(value),
  value: value
}))

export const LOG_EVENT_RESULT_OPTIONS: LogEventResultOption[] = ALL_LOG_EVENT_RESULTS.map((value: LogEventResult): LogEventResultOption => ({
  label: resolveLogEventResultLabel(value),
  value: value
}))

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
