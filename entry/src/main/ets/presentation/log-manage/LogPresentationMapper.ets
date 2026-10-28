import {
  LogManageFilterStrings,
  resolveLogEventTypeLabel
} from '../../constants/modules/LogManageStrings'
import {
  ALL_LOG_EVENT_TYPES,
  LogEventType
} from '../../models/LogModels'
import { LOG_TIME_RANGE_DEFINITIONS } from '../../models/LogManageModels'
import { formatStandardDateTime } from '../../utils/DateTimeFormatUtils'

export interface LogEventTypeOption {
  label: string
  value: LogEventType
  icon?: Resource
}

export interface LogTimeRangeOption {
  label: string
  durationMs?: number
}

/**
 * 事件类型与时间范围下拉选项以惰性函数提供：选项标签经文案门面按当前
 * locale 解析，不得在模块顶层常量中读取文案门面。
 */
export function getLogEventTypeOptions(): LogEventTypeOption[] {
  return ALL_LOG_EVENT_TYPES.map((value: LogEventType): LogEventTypeOption => ({
    label: resolveLogEventTypeLabel(value),
    value: value
  }))
}

export function getLogTimeRangeOptions(): LogTimeRangeOption[] {
  const timeRangeLabels: string[] = [
    LogManageFilterStrings.ALL_TIME,
    LogManageFilterStrings.LAST_1_HOUR,
    LogManageFilterStrings.LAST_12_HOURS,
    LogManageFilterStrings.LAST_24_HOURS,
    LogManageFilterStrings.LAST_3_DAYS
  ]
  return LOG_TIME_RANGE_DEFINITIONS.map((definition, index): LogTimeRangeOption => ({
    label: timeRangeLabels[index] ?? LogManageFilterStrings.ALL_TIME,
    durationMs: definition.durationMs
  }))
}

export function getLogEventTypeLabel(type: LogEventType): string {
  return resolveLogEventTypeLabel(type)
}

export function formatLogTimestamp(timestamp: number): string {
  return formatStandardDateTime(timestamp)
}
