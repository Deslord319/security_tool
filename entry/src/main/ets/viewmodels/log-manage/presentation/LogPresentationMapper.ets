import { LabelText, ResultText } from '../../../constants/StringCatalog'
import { LogEventPresentationStrings, LogResultPresentationStrings } from '../../../constants/modules/LogManageStrings'
import { LogEventResult, LogEventType } from '../../../models/DataModels'

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
  { label: LogEventPresentationStrings.POWER, value: LogEventType.POWER },
  { label: LogEventPresentationStrings.SYSTEM, value: LogEventType.SYSTEM },
  { label: LogEventPresentationStrings.KERNEL, value: LogEventType.KERNEL }
]

export const LOG_EVENT_RESULT_OPTIONS: LogEventResultOption[] = [
  { label: ResultText.SUCCESS, value: LogEventResult.SUCCESS },
  { label: LogResultPresentationStrings.BLOCKED, value: LogEventResult.BLOCKED },
  { label: ResultText.FAILED, value: LogEventResult.FAILED }
]

export function getLogEventTypeLabel(type: LogEventType): string {
  switch (type) {
    case LogEventType.CRASH:
      return LogEventPresentationStrings.CRASH
    case LogEventType.FILE:
      return LogEventPresentationStrings.FILE
    case LogEventType.ACCOUNT:
      return LogEventPresentationStrings.ACCOUNT
    case LogEventType.PERMISSION:
      return LogEventPresentationStrings.PERMISSION
    case LogEventType.POWER:
      return LogEventPresentationStrings.POWER
    case LogEventType.SYSTEM:
      return LogEventPresentationStrings.SYSTEM
    case LogEventType.KERNEL:
      return LogEventPresentationStrings.KERNEL
    default:
      return LabelText.UNKNOWN
  }
}

export function getLogEventResultLabel(result: LogEventResult): string {
  switch (result) {
    case LogEventResult.SUCCESS:
      return ResultText.SUCCESS
    case LogEventResult.BLOCKED:
      return LogResultPresentationStrings.BLOCKED
    case LogEventResult.FAILED:
      return ResultText.FAILED
    default:
      return LabelText.UNKNOWN
  }
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
  let date = new Date(timestamp)
  let pad = (n: number): string => n.toString().padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
}
