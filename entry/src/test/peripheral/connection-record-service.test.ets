import { describe, expect, it } from '@ohos/hypium'
import { LogEventResult, PeripheralType } from '../../main/ets/models/DataModels'
import { PeripheralConnectionRecordService } from '../../main/ets/services/PeripheralConnectionRecordService'
import { PeripheralTraceRepository } from '../../main/ets/services/PeripheralTraceRepository'

describe('PeripheralConnectionRecordService', () => {
  it('should query runtime records ordered by newest first', 0, () => {
    PeripheralTraceRepository.resetForTest()
    PeripheralTraceRepository.setRecordsForTest([
      {
        recordId: 'runtime_older',
        occurAt: 100,
        collectAt: 101,
        deviceName: 'Older Device',
        deviceType: PeripheralType.USB_STORAGE,
        deviceId: 'VID:1111 PID:0001',
        action: 'connect',
        decision: 'allow',
        result: LogEventResult.SUCCESS,
        source: 'runtime_event',
        summary: 'older'
      },
      {
        recordId: 'runtime_newer',
        occurAt: 200,
        collectAt: 201,
        deviceName: 'Newer Device',
        deviceType: PeripheralType.USB_STORAGE,
        deviceId: 'VID:2222 PID:0002',
        action: 'disconnect',
        decision: 'unknown',
        result: LogEventResult.SUCCESS,
        source: 'runtime_event',
        summary: 'newer'
      }
    ])

    const records = PeripheralConnectionRecordService.queryRecords()
    expect(records.length).assertEqual(2)
    expect(records[0].deviceName).assertEqual('Newer Device')
    expect(records[1].deviceName).assertEqual('Older Device')
  })
})
