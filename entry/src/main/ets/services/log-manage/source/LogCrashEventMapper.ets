import hiAppEvent from '@ohos.hiviewdfx.hiAppEvent'
import {
  generateLogEntryId,
  LogEntry,
  LogEventResult,
  LogEventType
} from '../../../models/DataModels'
import { pickNumber, pickString } from '../common/LogValuePicker'
import { resolveCrashSourceTimestamp } from './LogTimestampResolver'

type CrashParamValue = string | number | boolean | Object | undefined
type CrashParamMap = Record<string, CrashParamValue>

export function mapCrashInfoToLogEntry(
  info: hiAppEvent.AppEventInfo,
  nowProvider: () => number = () => Date.now()
): LogEntry {
  const params = info.params as CrashParamMap
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

  return {
    id: generateLogEntryId(),
    timestamp: resolveCrashTimestamp(params, nowProvider),
    eventType: LogEventType.CRASH,
    detail: detailParts.join(' | '),
    processName: processName,
    pid: pickNumber(params, ['pid', 'processId', 'process_id']),
    uid: pickNumber(params, ['uid', 'userId', 'user_id']),
    sourceEventId: undefined,
    rawEventName: info.name,
    rawOutcome: info.name === hiAppEvent.event.APP_FREEZE ? 'freeze' : 'crash',
    rawAction: rawAction,
    result: LogEventResult.FAILED
  }
}

function resolveCrashTimestamp(params: CrashParamMap, nowProvider: () => number): number {
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

