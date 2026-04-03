import { beforeEach, describe, expect, it } from '@ohos/hypium'
import {
  LogEventResult,
  PeripheralTraceRecord,
  PeripheralType
} from '../../main/ets/models/DataModels'
import { PeripheralTraceRepository } from '../../main/ets/services/PeripheralTraceRepository'

function createTraceRecord(
  recordId: string,
  occurAt: number,
  extra?: Partial<PeripheralTraceRecord>
): PeripheralTraceRecord {
  return {
    recordId,
    occurAt,
    collectAt: occurAt + 1,
    deviceName: `Device-${recordId}`,
    deviceType: PeripheralType.USB_STORAGE,
    deviceId: `VID:${recordId} PID:${recordId}`,
    action: 'connect',
    decision: 'allow',
    result: LogEventResult.SUCCESS,
    source: 'runtime_event',
    summary: `summary-${recordId}`,
    ...extra
  }
}

describe('PeripheralTraceRepository', () => {
  beforeEach(() => {
    PeripheralTraceRepository.resetForTest()
  })

  it('should append and query normalized records', 0, async (done: Function) => {
    let ok = await PeripheralTraceRepository.append(createTraceRecord('0001', 100, {
      deviceId: ' vid:0001   pid:0001 ',
      matchedPolicyKind: 'default_allow'
    }))
    let records = PeripheralTraceRepository.query()

    expect(ok).assertTrue()
    expect(records.length).assertEqual(1)
    expect(records[0].recordId).assertEqual('0001')
    expect(records[0].deviceId).assertEqual('VID:0001 PID:0001')
    expect(records[0].matchedPolicyKind).assertEqual('default_allow')
    done()
  })

  it('should accept empty appendBatch and keep newest records first', 0, async (done: Function) => {
    let emptyOk = await PeripheralTraceRepository.appendBatch([])
    let appendOk = await PeripheralTraceRepository.appendBatch([
      createTraceRecord('older', 100),
      createTraceRecord('newer', 300)
    ])
    let records = PeripheralTraceRepository.query()

    expect(emptyOk).assertTrue()
    expect(appendOk).assertTrue()
    expect(records.length).assertEqual(2)
    expect(records[0].recordId).assertEqual('newer')
    expect(records[1].recordId).assertEqual('older')
    done()
  })

  it('should filter records by query dimensions and pagination', 0, (done: Function) => {
    PeripheralTraceRepository.setRecordsForTest([
      createTraceRecord('runtime-usb', 500, {
        deviceName: 'Alpha USB',
        deviceId: 'VID:0001 PID:0001',
        deviceType: PeripheralType.USB_STORAGE,
        action: 'connect',
        decision: 'allow',
        result: LogEventResult.SUCCESS,
        source: 'runtime_event',
        detail: 'mounted alpha volume',
        processName: 'usb-service'
      }),
      createTraceRecord('audit-bt', 400, {
        deviceName: 'Beta Headset',
        deviceId: 'MAC: AA:BB:CC:DD:EE:FF',
        deviceType: PeripheralType.BLUETOOTH,
        action: 'disconnect',
        decision: 'deny',
        result: LogEventResult.BLOCKED,
        source: 'audit_event',
        summary: 'beta blocked',
        detail: 'audit detail'
      }),
      createTraceRecord('snapshot-usb', 300, {
        deviceName: 'Gamma Camera',
        deviceId: 'VID:0002 PID:0002',
        deviceType: PeripheralType.USB_CAMERA,
        action: 'intercept',
        decision: 'unknown',
        result: LogEventResult.FAILED,
        source: 'policy_snapshot',
        summary: 'gamma snapshot'
      })
    ])

    expect(PeripheralTraceRepository.query({ deviceId: ' vid:0001   pid:0001 ' }).length).assertEqual(1)
    expect(PeripheralTraceRepository.query({ deviceTypes: [PeripheralType.BLUETOOTH] }).length).assertEqual(1)
    expect(PeripheralTraceRepository.query({ actions: ['disconnect'] }).length).assertEqual(1)
    expect(PeripheralTraceRepository.query({ decisions: ['deny'] }).length).assertEqual(1)
    expect(PeripheralTraceRepository.query({ results: [LogEventResult.FAILED] }).length).assertEqual(1)
    expect(PeripheralTraceRepository.query({ sources: ['policy_snapshot'] }).length).assertEqual(1)
    expect(PeripheralTraceRepository.query({ keyword: 'alpha volume' }).length).assertEqual(1)
    expect(PeripheralTraceRepository.query({ startTime: 350, endTime: 500 }).length).assertEqual(2)

    let paged = PeripheralTraceRepository.query({ pageOffset: 1, pageSize: 1 })
    expect(paged.length).assertEqual(1)
    expect(paged[0].recordId).assertEqual('audit-bt')
    done()
  })

  it('should report aggregated stats for filtered records', 0, (done: Function) => {
    PeripheralTraceRepository.setRecordsForTest([
      createTraceRecord('connect-allow', 500, {
        action: 'connect',
        decision: 'allow',
        source: 'runtime_event'
      }),
      createTraceRecord('disconnect-deny', 400, {
        action: 'disconnect',
        decision: 'deny',
        source: 'audit_event'
      }),
      createTraceRecord('intercept-unknown', 300, {
        action: 'intercept',
        decision: 'unknown',
        source: 'policy_snapshot'
      })
    ])

    let stats = PeripheralTraceRepository.getStats()
    let runtimeStats = PeripheralTraceRepository.getStats({ sources: ['runtime_event'] })

    expect(stats.total).assertEqual(3)
    expect(stats.connects).assertEqual(1)
    expect(stats.disconnects).assertEqual(1)
    expect(stats.intercepts).assertEqual(1)
    expect(stats.allows).assertEqual(1)
    expect(stats.denies).assertEqual(1)
    expect(stats.unknowns).assertEqual(1)
    expect(stats.runtimeCount).assertEqual(1)
    expect(stats.auditCount).assertEqual(1)
    expect(stats.snapshotCount).assertEqual(1)
    expect(runtimeStats.total).assertEqual(1)
    done()
  })

  it('should notify listeners on append and clear and stop after removal', 0, async (done: Function) => {
    let addedCounts: number[] = []
    let totalCounts: number[] = []
    let listenerId = PeripheralTraceRepository.addChangeListener((event) => {
      addedCounts.push(event.addedCount)
      totalCounts.push(event.totalCount)
    })

    await PeripheralTraceRepository.append(createTraceRecord('listener-1', 100))
    let cleared = await PeripheralTraceRepository.clearAll()
    PeripheralTraceRepository.removeChangeListener(listenerId)
    await PeripheralTraceRepository.append(createTraceRecord('listener-2', 200))

    expect(cleared).assertTrue()
    expect(addedCounts.length).assertEqual(2)
    expect(addedCounts[0]).assertEqual(1)
    expect(addedCounts[1]).assertEqual(0)
    expect(totalCounts[0]).assertEqual(1)
    expect(totalCounts[1]).assertEqual(0)
    done()
  })

  it('should update retention config and cleanup expired or overflow records', 0, async (done: Function) => {
    let originalDateNow = Date.now
    try {
      Date.now = (): number => 10 * 24 * 60 * 60 * 1000
      PeripheralTraceRepository.resetForTest()
      PeripheralTraceRepository.setRecordsForTest([
        createTraceRecord('expired', 1 * 24 * 60 * 60 * 1000),
        createTraceRecord('recent-a', 9 * 24 * 60 * 60 * 1000),
        createTraceRecord('recent-b', 8 * 24 * 60 * 60 * 1000)
      ])

      await PeripheralTraceRepository.configure(2, 5)
      let config = PeripheralTraceRepository.getRetentionConfig()
      let retainedRecords = PeripheralTraceRepository.query()
      let removed = await PeripheralTraceRepository.forceCleanup(undefined, 1)
      let records = PeripheralTraceRepository.query()

      expect(config.retentionDays).assertEqual(2)
      expect(config.maxEntries).assertEqual(5)
      expect(retainedRecords.length).assertEqual(2)
      expect(removed).assertEqual(1)
      expect(records.length).assertEqual(1)
      expect(records[0].recordId).assertEqual('recent-a')
      done()
    } finally {
      Date.now = originalDateNow
    }
  })
})
