/**
 * 日志管理模块 - 服务层测试
 * L2 层：使用 Mock 数据测试 LogAuditService 和 LogStorageService 业务逻辑
 */
import { describe, beforeEach, it, expect } from '@ohos/hypium'
import {
  MockAuditEvent,
  resetMock,
  setFailMode,
  getSubscriptionStatus,
  emitAuditEvent,
  onSecurityAudit,
  offSecurityAudit,
  createMockAuditEvent
} from './__mocks__/MockSecurityAudit'
import {
  LogEntry,
  LogEventType,
  LogEventResult,
  LogAuditDiagnostics,
  LogEventTypeDiag,
  LogFilter,
  LogExportFormat,
  generateLogEntryId,
  getLogEventTypeLabel,
  getLogEventResultLabel,
  formatLogTimestamp
} from '../../main/ets/models/DataModels'

// ==================== 辅助函数 ====================

function createLogEntry(
  eventType: LogEventType,
  detail: string,
  result: LogEventResult,
  timestamp?: number,
  processName?: string
): LogEntry {
  return {
    id: generateLogEntryId(),
    timestamp: timestamp !== undefined ? timestamp : Date.now(),
    eventType: eventType,
    detail: detail,
    processName: processName,
    result: result
  }
}

// 内存日志存储（模拟 LogStorageService 核心逻辑）
let memoryStore: LogEntry[] = []
let maxEntries: number = 100

function resetStore(): void {
  memoryStore = []
  maxEntries = 100
}

function addEntryToStore(entry: LogEntry): void {
  memoryStore.unshift(entry)
  if (memoryStore.length > maxEntries) {
    memoryStore = memoryStore.slice(0, maxEntries)
  }
}

function queryFromStore(filter?: LogFilter): LogEntry[] {
  if (!filter) {
    return memoryStore
  }

  return memoryStore.filter((entry: LogEntry) => {
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
    if (filter.startTime && entry.timestamp < filter.startTime) {
      return false
    }
    if (filter.endTime && entry.timestamp > filter.endTime) {
      return false
    }
    if (filter.keyword && filter.keyword.length > 0) {
      let keyword = filter.keyword.toLowerCase()
      let matchDetail = entry.detail.toLowerCase().includes(keyword)
      let matchProcess = entry.processName ?
        entry.processName.toLowerCase().includes(keyword) : false
      if (!matchDetail && !matchProcess) {
        return false
      }
    }
    return true
  })
}

function exportToCsv(entries: LogEntry[]): string {
  let header = '时间,事件类型,详情,进程名,PID,结果'
  let lines: string[] = [header]
  for (let entry of entries) {
    let time = formatLogTimestamp(entry.timestamp)
    let type = getLogEventTypeLabel(entry.eventType)
    let detail = `"${entry.detail.replace(/"/g, '""')}"`
    let process = entry.processName || ''
    let pid = entry.pid !== undefined ? entry.pid.toString() : ''
    let result = getLogEventResultLabel(entry.result)
    lines.push(`${time},${type},${detail},${process},${pid},${result}`)
  }
  return lines.join('\n')
}

export default function logManageServiceTest() {
  describe('LogManage Service', () => {

    // ==================== 审计事件订阅测试 ====================

    describe('AuditService subscription', () => {
      beforeEach(() => {
        resetMock()
      })

      it('should subscribe to audit events', 0, () => {
        let received: MockAuditEvent[] = []
        onSecurityAudit('securityAudit', (event: MockAuditEvent) => {
          received.push(event)
        })

        expect(getSubscriptionStatus()).assertTrue()
      })

      it('should receive events after subscription', 0, () => {
        let received: MockAuditEvent[] = []
        onSecurityAudit('securityAudit', (event: MockAuditEvent) => {
          received.push(event)
        })

        emitAuditEvent(createMockAuditEvent(1000, '{"description":"test file op"}'))
        expect(received.length).assertEqual(1)
        expect(received[0].eventId).assertEqual(1000)
      })

      it('should receive multiple events', 0, () => {
        let received: MockAuditEvent[] = []
        onSecurityAudit('securityAudit', (event: MockAuditEvent) => {
          received.push(event)
        })

        emitAuditEvent(createMockAuditEvent(1000, 'file event'))
        emitAuditEvent(createMockAuditEvent(2000, 'network event'))
        emitAuditEvent(createMockAuditEvent(4000, 'app event'))

        expect(received.length).assertEqual(3)
      })

      it('should unsubscribe correctly', 0, () => {
        let received: MockAuditEvent[] = []
        onSecurityAudit('securityAudit', (event: MockAuditEvent) => {
          received.push(event)
        })

        offSecurityAudit('securityAudit')
        expect(getSubscriptionStatus()).assertFalse()

        emitAuditEvent(createMockAuditEvent(1000, 'should not receive'))
        expect(received.length).assertEqual(0)
      })

      it('should handle subscribe failure', 0, () => {
        setFailMode(true, 'Permission denied')

        let error: Error | null = null
        try {
          onSecurityAudit('securityAudit', (_event: MockAuditEvent) => {})
        } catch (e) {
          error = e as Error
        }

        expect(error !== null).assertTrue()
        expect(error!.message).assertEqual('Permission denied')
      })

      it('should reject invalid event type', 0, () => {
        let error: Error | null = null
        try {
          onSecurityAudit('invalidType', (_event: MockAuditEvent) => {})
        } catch (e) {
          error = e as Error
        }

        expect(error !== null).assertTrue()
      })
    })

    // ==================== 日志存储测试 ====================

    describe('LogStorage core logic', () => {
      beforeEach(() => {
        resetStore()
      })

      it('should add entry to store', 0, () => {
        let entry = createLogEntry(LogEventType.FILE, '创建文件', LogEventResult.SUCCESS)
        addEntryToStore(entry)
        expect(memoryStore.length).assertEqual(1)
      })

      it('should add entries in reverse order (newest first)', 0, () => {
        let entry1 = createLogEntry(LogEventType.FILE, '第一条', LogEventResult.SUCCESS, 1000)
        let entry2 = createLogEntry(LogEventType.APP, '第二条', LogEventResult.SUCCESS, 2000)
        addEntryToStore(entry1)
        addEntryToStore(entry2)

        expect(memoryStore[0].detail).assertEqual('第二条')
        expect(memoryStore[1].detail).assertEqual('第一条')
      })

      it('should enforce max entries limit', 0, () => {
        maxEntries = 3
        for (let i = 0; i < 5; i++) {
          addEntryToStore(createLogEntry(LogEventType.FILE, `entry_${i}`, LogEventResult.SUCCESS))
        }
        expect(memoryStore.length).assertEqual(3)
      })

      it('should keep newest entries when exceeding max', 0, () => {
        maxEntries = 2
        addEntryToStore(createLogEntry(LogEventType.FILE, 'old', LogEventResult.SUCCESS, 1000))
        addEntryToStore(createLogEntry(LogEventType.FILE, 'mid', LogEventResult.SUCCESS, 2000))
        addEntryToStore(createLogEntry(LogEventType.FILE, 'new', LogEventResult.SUCCESS, 3000))

        expect(memoryStore.length).assertEqual(2)
        expect(memoryStore[0].detail).assertEqual('new')
        expect(memoryStore[1].detail).assertEqual('mid')
      })
    })

    // ==================== 日志查询/过滤测试 ====================

    describe('LogStorage query and filter', () => {
      beforeEach(() => {
        resetStore()
        // 预填充测试数据
        addEntryToStore(createLogEntry(LogEventType.FILE, '文件被创建', LogEventResult.SUCCESS, 1000, 'editor'))
        addEntryToStore(createLogEntry(LogEventType.NETWORK_CONN, '连接到 192.168.1.1', LogEventResult.SUCCESS, 2000, 'browser'))
        addEntryToStore(createLogEntry(LogEventType.USB_ACCESS, 'USB 设备被阻止', LogEventResult.BLOCKED, 3000, 'usb_monitor'))
        addEntryToStore(createLogEntry(LogEventType.APP, '安装应用 com.test', LogEventResult.FAILED, 4000, 'installer'))
        addEntryToStore(createLogEntry(LogEventType.FILE, '文件被删除', LogEventResult.SUCCESS, 5000, 'filemanager'))
      })

      it('should return all entries without filter', 0, () => {
        let result = queryFromStore()
        expect(result.length).assertEqual(5)
      })

      it('should filter by event type', 0, () => {
        let filter: LogFilter = { eventTypes: [LogEventType.FILE] }
        let result = queryFromStore(filter)
        expect(result.length).assertEqual(2)
      })

      it('should filter by multiple event types', 0, () => {
        let filter: LogFilter = { eventTypes: [LogEventType.FILE, LogEventType.APP] }
        let result = queryFromStore(filter)
        expect(result.length).assertEqual(3)
      })

      it('should filter by result', 0, () => {
        let filter: LogFilter = { results: [LogEventResult.BLOCKED] }
        let result = queryFromStore(filter)
        expect(result.length).assertEqual(1)
        expect(result[0].detail).assertEqual('USB 设备被阻止')
      })

      it('should filter by time range', 0, () => {
        let filter: LogFilter = { startTime: 2000, endTime: 4000 }
        let result = queryFromStore(filter)
        expect(result.length).assertEqual(3)
      })

      it('should filter by keyword in detail', 0, () => {
        let filter: LogFilter = { keyword: '文件' }
        let result = queryFromStore(filter)
        expect(result.length).assertEqual(2)
      })

      it('should filter by keyword in processName', 0, () => {
        let filter: LogFilter = { keyword: 'browser' }
        let result = queryFromStore(filter)
        expect(result.length).assertEqual(1)
      })

      it('should handle keyword case-insensitive', 0, () => {
        let filter: LogFilter = { keyword: 'USB' }
        let result = queryFromStore(filter)
        expect(result.length).assertEqual(1)
      })

      it('should combine multiple filters', 0, () => {
        let filter: LogFilter = {
          eventTypes: [LogEventType.FILE],
          results: [LogEventResult.SUCCESS],
          keyword: '删除'
        }
        let result = queryFromStore(filter)
        expect(result.length).assertEqual(1)
        expect(result[0].detail).assertEqual('文件被删除')
      })

      it('should return empty for no match', 0, () => {
        let filter: LogFilter = { keyword: 'nonexistent_keyword' }
        let result = queryFromStore(filter)
        expect(result.length).assertEqual(0)
      })

      it('should handle empty eventTypes as no filter', 0, () => {
        let filter: LogFilter = { eventTypes: [] }
        let result = queryFromStore(filter)
        expect(result.length).assertEqual(5)
      })
    })

    // ==================== 统计功能测试 ====================

    describe('LogStorage statistics', () => {
      beforeEach(() => {
        resetStore()
      })

      it('should count total entries', 0, () => {
        addEntryToStore(createLogEntry(LogEventType.FILE, 'a', LogEventResult.SUCCESS))
        addEntryToStore(createLogEntry(LogEventType.APP, 'b', LogEventResult.SUCCESS))
        addEntryToStore(createLogEntry(LogEventType.DNS, 'c', LogEventResult.BLOCKED))
        expect(memoryStore.length).assertEqual(3)
      })

      it('should count by type', 0, () => {
        addEntryToStore(createLogEntry(LogEventType.FILE, 'a', LogEventResult.SUCCESS))
        addEntryToStore(createLogEntry(LogEventType.FILE, 'b', LogEventResult.SUCCESS))
        addEntryToStore(createLogEntry(LogEventType.APP, 'c', LogEventResult.SUCCESS))

        let byType = new Map<LogEventType, number>()
        for (let entry of memoryStore) {
          let count = byType.get(entry.eventType) || 0
          byType.set(entry.eventType, count + 1)
        }

        expect(byType.get(LogEventType.FILE)).assertEqual(2)
        expect(byType.get(LogEventType.APP)).assertEqual(1)
      })

      it('should count blocked events', 0, () => {
        addEntryToStore(createLogEntry(LogEventType.FILE, 'a', LogEventResult.SUCCESS))
        addEntryToStore(createLogEntry(LogEventType.USB_ACCESS, 'b', LogEventResult.BLOCKED))
        addEntryToStore(createLogEntry(LogEventType.NETWORK_CONN, 'c', LogEventResult.BLOCKED))

        let blockedCount = 0
        for (let entry of memoryStore) {
          if (entry.result === LogEventResult.BLOCKED) {
            blockedCount++
          }
        }
        expect(blockedCount).assertEqual(2)
      })
    })

    describe('Audit diagnostics model', () => {
      it('should include subscribe mode and fallback reason fields', 0, () => {
        let byType = new Map<LogEventType, LogEventTypeDiag>()
        byType.set(LogEventType.FILE, {
          type: LogEventType.FILE,
          subscribed: false,
          failedEventIds: [],
          seenCount: 0
        } as LogEventTypeDiag)

        let diagnostics: LogAuditDiagnostics = {
          byType: byType,
          unknownEventIds: [],
          subscribeMode: 'client',
          fallbackReason: 'none',
          lastModeSwitchAt: Date.now(),
          lastUpdatedAt: Date.now()
        } as LogAuditDiagnostics

        expect(diagnostics.subscribeMode).assertEqual('client')
        expect(diagnostics.fallbackReason).assertEqual('none')
      })
    })

    // ==================== 导出功能测试 ====================

    describe('LogStorage export', () => {
      beforeEach(() => {
        resetStore()
      })

      it('should export to CSV format', 0, () => {
        addEntryToStore(createLogEntry(LogEventType.FILE, '测试文件操作', LogEventResult.SUCCESS, 1000, 'test'))

        let csv = exportToCsv(memoryStore)
        expect(csv.includes('时间')).assertTrue()
        expect(csv.includes('事件类型')).assertTrue()
        expect(csv.includes('测试文件操作')).assertTrue()
        expect(csv.includes('文件操作')).assertTrue()
        expect(csv.includes('成功')).assertTrue()
      })

      it('should handle empty entries for CSV export', 0, () => {
        let csv = exportToCsv([])
        // 只有 header
        expect(csv.includes('时间')).assertTrue()
        expect(csv.split('\n').length).assertEqual(1)
      })

      it('should escape double quotes in CSV', 0, () => {
        addEntryToStore(createLogEntry(LogEventType.FILE, '包含"引号"的内容', LogEventResult.SUCCESS))
        let csv = exportToCsv(memoryStore)
        expect(csv.includes('""引号""')).assertTrue()
      })

      it('should export to JSON format', 0, () => {
        addEntryToStore(createLogEntry(LogEventType.APP, '安装应用', LogEventResult.SUCCESS))
        let json = JSON.stringify(memoryStore, null, 2)
        expect(json.includes('安装应用')).assertTrue()
        let parsed = JSON.parse(json) as LogEntry[]
        expect(parsed.length).assertEqual(1)
      })
    })

    // ==================== 复合场景测试 ====================

    describe('Complex scenarios', () => {
      beforeEach(() => {
        resetMock()
        resetStore()
      })

      it('should handle subscribe -> receive -> store -> query flow', 0, () => {
        // 订阅
        let received: MockAuditEvent[] = []
        onSecurityAudit('securityAudit', (event: MockAuditEvent) => {
          received.push(event)
          // 模拟存储到本地
          let entry = createLogEntry(
            LogEventType.FILE,
            event.content,
            LogEventResult.SUCCESS,
            event.timestamp
          )
          addEntryToStore(entry)
        })

        // 接收事件
        emitAuditEvent(createMockAuditEvent(1000, '文件创建操作', 100))
        emitAuditEvent(createMockAuditEvent(2000, '网络连接操作', 200))

        // 验证接收
        expect(received.length).assertEqual(2)

        // 验证存储
        expect(memoryStore.length).assertEqual(2)

        // 查询验证
        let filter: LogFilter = { keyword: '文件' }
        let result = queryFromStore(filter)
        expect(result.length).assertEqual(1)
      })

      it('should handle unsubscribe then no more events stored', 0, () => {
        let count = 0
        onSecurityAudit('securityAudit', (_event: MockAuditEvent) => {
          count++
        })

        emitAuditEvent(createMockAuditEvent(1000, 'before'))
        expect(count).assertEqual(1)

        offSecurityAudit('securityAudit')
        emitAuditEvent(createMockAuditEvent(2000, 'after'))
        expect(count).assertEqual(1) // 不应增加
      })

      it('should handle high volume entries with max limit', 0, () => {
        maxEntries = 50
        for (let i = 0; i < 200; i++) {
          addEntryToStore(createLogEntry(
            LogEventType.FILE,
            `entry_${i}`,
            LogEventResult.SUCCESS,
            i * 1000
          ))
        }

        expect(memoryStore.length).assertEqual(50)
        // 最新的应该在前面
        expect(memoryStore[0].detail).assertEqual('entry_199')
      })
    })

  })
}
