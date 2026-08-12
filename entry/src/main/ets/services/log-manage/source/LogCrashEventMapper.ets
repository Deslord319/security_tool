import hiAppEvent from '@ohos.hiviewdfx.hiAppEvent'
import {
  generateLogEntryId,
  LogEntry,
  LogEventType,
  LogField
} from '../../../models/LogModels'
import { LooseRecord } from '../../../types/LooseValueTypes'
import {
  pickNumberFromRecords as pickNumber,
  pickStringFromRecords as pickString
} from '../../../utils/ValuePicker'
import { resolveCrashSourceTimestamp } from './LogTimestampResolver'

export function mapCrashInfoToLogEntry(
  info: hiAppEvent.AppEventInfo,
  nowProvider: () => number = () => Date.now()
): LogEntry {
  const params = info.params as LooseRecord
  const processName = pickString(params, [
    'bundleName', 'bundle_name', 'processName', 'process_name', 'moduleName', 'module_name', 'abilityName'
  ])
  const reason = pickString(params, [
    'exception', 'reason', 'message', 'summary', 'errorMessage', 'error_message'
  ])
  const stack = pickString(params, ['stackTrace', 'stack_trace', 'stack', 'logPath', 'log_path'])
  const rawAction = pickString(params, ['state', 'lifecycle', 'stage'])
  const detailParts: string[] = []
  if (reason) {
    detailParts.push(reason)
  }
  if (stack) {
    detailParts.push(stack)
  }
  if (detailParts.length === 0) {
    detailParts.push(info.name)
  }
  const fields: LogField[] = []
  if (reason) fields.push({ key: 'event.reason', value: reason })
  if (stack) fields.push({ key: 'event.top_stack', value: stack })
  if (rawAction) fields.push({ key: 'event.action', value: rawAction })

  return {
    id: generateLogEntryId(),
    timestamp: resolveCrashTimestamp(params, nowProvider),
    eventType: LogEventType.CRASH,
    eventKey: 'crash.runtime',
    detail: detailParts.join(' | '),
    processName: processName,
    pid: pickNumber(params, ['pid', 'processId', 'process_id']),
    uid: pickNumber(params, ['uid', 'userId', 'user_id']),
    sourceEventId: undefined,
    rawEventName: info.name,
    fields
  }
}

function resolveCrashTimestamp(params: LooseRecord, nowProvider: () => number): number {
  return resolveCrashSourceTimestamp([
    params['time'],
    params['timestamp'],
    params['eventTime'],
    params['event_time'],
    params['occurTime'],
    params['occur_time'],
    params['happenTime'],
    params['happen_time']
  ], nowProvider)
}
