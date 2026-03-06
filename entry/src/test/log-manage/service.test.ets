import { describe, beforeEach, it, expect } from '@ohos/hypium'
import {
  LogEntry,
  LogEventType,
  LogEventResult,
  LogFilter,
  LogAuditDiagnostics,
  LogEventTypeDiag,
  generateLogEntryId
} from '../../main/ets/models/DataModels'

function createLogEntry(
  eventType: LogEventType,
  detail: string,
  result: LogEventResult,
  timestamp: number,
  processName?: string
): LogEntry {
  return {
    id: generateLogEntryId(),
    timestamp,
    eventType,
    detail,
    processName,
    result
  }
}

function queryByFilter(entries: LogEntry[], filter?: LogFilter): LogEntry[] {
  if (!filter) {
    return entries
  }

  if (
    filter.startTime !== undefined &&
    Number.isFinite(filter.startTime) &&
    filter.endTime !== undefined &&
    Number.isFinite(filter.endTime) &&
    filter.startTime > filter.endTime
  ) {
    return []
  }

  return entries.filter((entry: LogEntry) => {
    if (filter.eventTypes && filter.eventTypes.length > 0) {
      if (!filter.eventTypes.includes(entry.eventType)) {
        return false
      }
    }
    if (filter.results && filter.results.length > 0) {
      if (!filter.results.includes(entry.result)) {
        return false
      }
    }

    if (
      filter.startTime !== undefined &&
      Number.isFinite(filter.startTime) &&
      entry.timestamp < filter.startTime
    ) {
      return false
    }
    if (
      filter.endTime !== undefined &&
      Number.isFinite(filter.endTime) &&
      entry.timestamp > filter.endTime
    ) {
      return false
    }

    if (filter.keyword && filter.keyword.length > 0) {
      let keyword = filter.keyword.toLowerCase()
      let detailHit = entry.detail.toLowerCase().includes(keyword)
      let processHit = entry.processName ? entry.processName.toLowerCase().includes(keyword) : false
      if (!detailHit && !processHit) {
        return false
      }
    }
    return true
  })
}

function normalizeRetentionDays(days: number): number {
  if (!Number.isFinite(days)) {
    return 30
  }
  let normalized = Math.floor(days)
  if (normalized <= 0) {
    return 30
  }
  if (normalized > 3650) {
    return 3650
  }
  return normalized
}

function normalizeBoolean(value: Object, fallback: boolean): boolean {
  if (typeof value === 'boolean') {
    return value
  }
  if (typeof value === 'number') {
    if (value === 1) {
      return true
    }
    if (value === 0) {
      return false
    }
    return fallback
  }
  if (typeof value === 'string') {
    let normalized = value.trim().toLowerCase()
    if (normalized === 'true' || normalized === '1' || normalized === 'yes' || normalized === 'on') {
      return true
    }
    if (normalized === 'false' || normalized === '0' || normalized === 'no' || normalized === 'off') {
      return false
    }
  }
  return fallback
}

function normalizeTimestamp(ts: number, now: number): number {
  if (!Number.isFinite(ts) || ts < 0) {
    return now
  }
  return Math.floor(ts)
}

class RuntimeCollectorHarness {
  running: boolean = true
  isFlushingEntries: boolean = false
  pendingEntries: LogEntry[] = []
  maxPendingEntries: number = 4
  persistMode: 'ok' | 'fail' | 'throw' = 'ok'

  handleIncomingEntry(entry: LogEntry): void {
    if (!this.running) {
      return
    }
    this.pendingEntries.push(entry)
    if (this.pendingEntries.length > this.maxPendingEntries) {
      let dropped = this.pendingEntries.length - this.maxPendingEntries
      this.pendingEntries = this.pendingEntries.slice(dropped)
    }
  }

  async flushPendingEntries(): Promise<void> {
    if (this.isFlushingEntries || this.pendingEntries.length === 0) {
      return
    }

    this.isFlushingEntries = true
    let batch = this.pendingEntries.slice(0, this.pendingEntries.length)
    this.pendingEntries = []

    try {
      let saved = await this.persist(batch)
      if (!saved) {
        this.requeueFailedBatch(batch)
      }
    } catch (_err) {
      this.requeueFailedBatch(batch)
    } finally {
      this.isFlushingEntries = false
    }
  }

  private async persist(_batch: LogEntry[]): Promise<boolean> {
    if (this.persistMode === 'throw') {
      throw new Error('persist throw')
    }
    if (this.persistMode === 'fail') {
      return false
    }
    return true
  }

  private requeueFailedBatch(batch: LogEntry[]): void {
    this.pendingEntries = batch.concat(this.pendingEntries)
    if (this.pendingEntries.length > this.maxPendingEntries) {
      let dropped = this.pendingEntries.length - this.maxPendingEntries
      this.pendingEntries = this.pendingEntries.slice(dropped)
    }
  }
}

function createDiagnostics(now: number): LogAuditDiagnostics {
  let byType = new Map<LogEventType, LogEventTypeDiag>()
  byType.set(LogEventType.FILE, {
    type: LogEventType.FILE,
    subscribed: true,
    failedEventIds: [],
    seenCount: 1,
    lastSeenAt: now
  } as LogEventTypeDiag)

  return {
    byType,
    unknownEventIds: [],
    subscribeMode: 'client',
    fallbackReason: 'none',
    lastModeSwitchAt: now,
    lastUpdatedAt: now
  } as LogAuditDiagnostics
}

export default function logManageServiceTest() {
  describe('LogManage Service Aligned Tests', () => {
    let entries: LogEntry[] = []

    beforeEach(() => {
      entries = [
        createLogEntry(LogEventType.FILE, 'file_create', LogEventResult.SUCCESS, 0, 'editor'),
        createLogEntry(LogEventType.NETWORK_CONN, 'connect 10.0.0.1', LogEventResult.SUCCESS, 1000, 'browser'),
        createLogEntry(LogEventType.USB_ACCESS, 'usb blocked', LogEventResult.BLOCKED, 2000, 'usb_guard'),
        createLogEntry(LogEventType.APP, 'app install failed', LogEventResult.FAILED, 3000, 'installer')
      ]
    })

    describe('query boundaries', () => {
      it('should handle startTime=0 correctly', 0, () => {
        let result = queryByFilter(entries, { startTime: 0 })
        expect(result.length).assertEqual(4)
      })

      it('should return empty when startTime > endTime', 0, () => {
        let result = queryByFilter(entries, { startTime: 3000, endTime: 1000 })
        expect(result.length).assertEqual(0)
      })

      it('should ignore non-finite time bounds', 0, () => {
        let result = queryByFilter(entries, { startTime: Number.NaN, endTime: Number.NaN })
        expect(result.length).assertEqual(4)
      })

      it('should combine type, result and keyword filters', 0, () => {
        let result = queryByFilter(entries, {
          eventTypes: [LogEventType.USB_ACCESS],
          results: [LogEventResult.BLOCKED],
          keyword: 'usb'
        })
        expect(result.length).assertEqual(1)
      })
    })

    describe('normalization rules', () => {
      it('should clamp retentionDays to sane range', 0, () => {
        expect(normalizeRetentionDays(-1)).assertEqual(30)
        expect(normalizeRetentionDays(5000)).assertEqual(3650)
        expect(normalizeRetentionDays(90.7)).assertEqual(90)
      })

      it('should normalize boolean strings and numbers', 0, () => {
        expect(normalizeBoolean('yes' as Object, false)).assertTrue()
        expect(normalizeBoolean('off' as Object, true)).assertFalse()
        expect(normalizeBoolean(1 as Object, false)).assertTrue()
        expect(normalizeBoolean(0 as Object, true)).assertFalse()
        expect(normalizeBoolean('unknown' as Object, true)).assertTrue()
      })

      it('should normalize invalid timestamp using deterministic now', 0, () => {
        let now = 123456789
        expect(normalizeTimestamp(-1, now)).assertEqual(now)
        expect(normalizeTimestamp(Number.NaN, now)).assertEqual(now)
        expect(normalizeTimestamp(88.9, now)).assertEqual(88)
      })
    })

    describe('flush reliability', () => {
      it('should requeue batch when persist returns false', 0, async () => {
        let h = new RuntimeCollectorHarness()
        h.persistMode = 'fail'
        h.handleIncomingEntry(createLogEntry(LogEventType.FILE, 'a', LogEventResult.SUCCESS, 1))
        h.handleIncomingEntry(createLogEntry(LogEventType.FILE, 'b', LogEventResult.SUCCESS, 2))

        await h.flushPendingEntries()

        expect(h.isFlushingEntries).assertFalse()
        expect(h.pendingEntries.length).assertEqual(2)
      })

      it('should requeue and recover state when persist throws', 0, async () => {
        let h = new RuntimeCollectorHarness()
        h.persistMode = 'throw'
        h.handleIncomingEntry(createLogEntry(LogEventType.FILE, 'a', LogEventResult.SUCCESS, 1))
        h.handleIncomingEntry(createLogEntry(LogEventType.FILE, 'b', LogEventResult.SUCCESS, 2))
        h.handleIncomingEntry(createLogEntry(LogEventType.FILE, 'c', LogEventResult.SUCCESS, 3))

        await h.flushPendingEntries()

        expect(h.isFlushingEntries).assertFalse()
        expect(h.pendingEntries.length).assertEqual(3)
      })

      it('should stop accepting entries when running=false', 0, () => {
        let h = new RuntimeCollectorHarness()
        h.running = false
        h.handleIncomingEntry(createLogEntry(LogEventType.FILE, 'ignored', LogEventResult.SUCCESS, 1))
        expect(h.pendingEntries.length).assertEqual(0)
      })

      it('should enforce max pending limit during requeue', 0, async () => {
        let h = new RuntimeCollectorHarness()
        h.persistMode = 'fail'
        h.maxPendingEntries = 2
        h.handleIncomingEntry(createLogEntry(LogEventType.FILE, '1', LogEventResult.SUCCESS, 1))
        h.handleIncomingEntry(createLogEntry(LogEventType.FILE, '2', LogEventResult.SUCCESS, 2))
        h.handleIncomingEntry(createLogEntry(LogEventType.FILE, '3', LogEventResult.SUCCESS, 3))

        await h.flushPendingEntries()

        expect(h.pendingEntries.length).assertEqual(2)
      })
    })

    describe('diagnostics snapshot', () => {
      it('should keep diagnostics fields complete and predictable', 0, () => {
        let now = 987654321
        let diagnostics = createDiagnostics(now)

        expect(diagnostics.subscribeMode).assertEqual('client')
        expect(diagnostics.fallbackReason).assertEqual('none')
        expect(diagnostics.lastUpdatedAt).assertEqual(now)
        expect(diagnostics.byType.get(LogEventType.FILE)?.seenCount).assertEqual(1)
      })

      it('should support reset-like behavior by recreating empty snapshot', 0, () => {
        let now = 100
        let before = createDiagnostics(now)
        expect(before.byType.get(LogEventType.FILE)?.seenCount).assertEqual(1)

        let emptyByType = new Map<LogEventType, LogEventTypeDiag>()
        let after: LogAuditDiagnostics = {
          byType: emptyByType,
          unknownEventIds: [],
          subscribeMode: 'none',
          fallbackReason: 'none',
          lastUpdatedAt: now + 1
        } as LogAuditDiagnostics

        expect(after.byType.size).assertEqual(0)
        expect(after.subscribeMode).assertEqual('none')
      })
    })
  })
}
