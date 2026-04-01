import { LogUtils } from './utils/LogUtils'

import {
  PeripheralConnectionFilter,
  PeripheralConnectionRecord,
  PeripheralTraceQuery,
  PeripheralTraceRecord
} from '../models/DataModels'
import { PeripheralTraceRepository } from './PeripheralTraceRepository'

const TAG = 'PeripheralConnectionRecordService'
const DOMAIN = 0x0008

export class PeripheralConnectionRecordService {
  static queryRecords(filter?: PeripheralConnectionFilter): PeripheralConnectionRecord[] {
    try {
      let query: PeripheralTraceQuery = {
        startTime: filter?.startTime,
        endTime: filter?.endTime,
        deviceTypes: filter?.deviceTypes,
        results: filter?.results,
        sources: ['runtime_event'],
        keyword: filter?.keyword
      }
      let records = PeripheralTraceRepository.query(query)
      return records
        .map((record: PeripheralTraceRecord) => PeripheralConnectionRecordService.mapRuntimeRecord(record))
        .sort((a: PeripheralConnectionRecord, b: PeripheralConnectionRecord) => b.timestamp - a.timestamp)
    } catch (err) {
      LogUtils.error(TAG, `queryRecords failed: ${JSON.stringify(err)}`)
      return []
    }
  }

  private static mapRuntimeRecord(record: PeripheralTraceRecord): PeripheralConnectionRecord {
    return {
      id: `peripheral_runtime_${record.recordId}`,
      timestamp: record.occurAt,
      collectAt: record.collectAt,
      deviceName: record.deviceName,
      deviceType: record.deviceType,
      deviceId: record.deviceId,
      action: record.action,
      result: record.result,
      policyHit: record.decision,
      source: 'runtime_event',
      summary: record.summary,
      correlationId: record.correlationId,
      policyVersion: record.policyVersion,
      rawEventId: record.rawEventId,
      rawEventName: record.rawEventName,
      rawOutcome: record.rawOutcome,
      rawAction: record.rawAction,
      rawPayload: record.rawPayload,
      detail: record.detail,
      processName: record.processName,
      usbPolicy: record.usbPolicy,
      effectivePolicyLabel: record.effectivePolicyLabel,
      matchedPolicyKind: record.matchedPolicyKind
    }
  }
}
