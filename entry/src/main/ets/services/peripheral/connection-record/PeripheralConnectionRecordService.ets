import { LogUtils } from '../../../utils/LogUtils'

import {
  PeripheralConnectionFilter,
  PeripheralConnectionRecord,
  PeripheralTraceQuery,
  PeripheralTraceRecord
} from '../../../models/DataModels'
import { PeripheralTraceEntryRepository } from './PeripheralTraceEntryRepository'

const TAG = 'PeripheralConnectionRecordService'

export class PeripheralConnectionRecordService {
  static async queryRecords(
    filter?: PeripheralConnectionFilter
  ): Promise<PeripheralConnectionRecord[]> {
    try {
      let query: PeripheralTraceQuery = {
        startTime: filter?.startTime,
        endTime: filter?.endTime,
        deviceTypes: filter?.deviceTypes,
        results: filter?.results,
        sources: ['runtime_event', 'audit_event'],
        keyword: filter?.keyword
      }
      let records = await PeripheralTraceEntryRepository.listByQuery(query)
      return records
        .map((record: PeripheralTraceRecord) => PeripheralConnectionRecordService.mapTraceRecord(record))
    } catch (err) {
      LogUtils.error(TAG, `queryRecords failed: ${JSON.stringify(err)}`)
      return []
    }
  }

  static async countRecords(filter?: PeripheralConnectionFilter): Promise<number> {
    try {
      let query: PeripheralTraceQuery = {
        startTime: filter?.startTime,
        endTime: filter?.endTime,
        deviceTypes: filter?.deviceTypes,
        results: filter?.results,
        sources: ['runtime_event', 'audit_event'],
        keyword: filter?.keyword
      }
      return await PeripheralTraceEntryRepository.countByQuery(query)
    } catch (err) {
      LogUtils.error(TAG, `countRecords failed: ${JSON.stringify(err)}`)
      return 0
    }
  }

  private static mapTraceRecord(record: PeripheralTraceRecord): PeripheralConnectionRecord {
    return {
      id: `peripheral_${record.source}_${record.recordId}`,
      timestamp: record.occurAt,
      collectAt: record.collectAt,
      deviceName: record.deviceName,
      deviceType: record.deviceType,
      deviceId: record.deviceId,
      action: record.action,
      result: record.result,
      policyHit: record.decision,
      source: record.source,
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
