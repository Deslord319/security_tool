import {
  resolveLogEventResultLabel,
  LogManageFilterStrings,
  resolveLogEventTypeLabel
} from '../../../constants/modules/LogManageStrings'
import {
  ALL_LOG_EVENT_RESULTS,
  ALL_LOG_EVENT_TYPES,
  LogEventResult,
  LogEventType
} from '../../../models/LogModels'
import { LOG_TIME_RANGE_DEFINITIONS } from '../../../models/LogManageModels'
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

export interface LogTimeRangeOption {
  label: string
  durationMs?: number
}

export const LOG_EVENT_RESULT_OPTIONS: LogEventResultOption[] = ALL_LOG_EVENT_RESULTS.map((value: LogEventResult): LogEventResultOption => ({
  label: resolveLogEventResultLabel(value),
  value: value
}))

const LOG_TIME_RANGE_LABELS: string[] = [
  LogManageFilterStrings.ALL_TIME,
  LogManageFilterStrings.LAST_1_HOUR,
  LogManageFilterStrings.LAST_12_HOURS,
  LogManageFilterStrings.LAST_24_HOURS,
  LogManageFilterStrings.LAST_3_DAYS
]

export const LOG_TIME_RANGE_OPTIONS: LogTimeRangeOption[] =
  LOG_TIME_RANGE_DEFINITIONS.map((definition, index): LogTimeRangeOption => ({
    label: LOG_TIME_RANGE_LABELS[index] ?? LogManageFilterStrings.ALL_TIME,
    durationMs: definition.durationMs
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
