import { common } from '@kit.AbilityKit'
import {
  PeripheralTraceQuery,
  PeripheralTraceRecord,
  PeripheralTraceStats
} from '../../../models/DataModels'
import { PeripheralTraceEntryRepository } from './PeripheralTraceEntryRepository'
import { PeripheralTraceMaintenanceService } from './PeripheralTraceMaintenanceService'

interface TraceChangeEvent {
  totalCount: number
  addedCount: number
  timestamp: number
}

type TraceChangeListener = (event: TraceChangeEvent) => void

interface TraceRetentionConfig {
  retentionDays: number
  maxEntries: number
}

interface TraceListenerBinding {
  listener: TraceChangeListener
  repositoryListenerId: number
  previousTotalCount: number
}

export class PeripheralTraceRepository {
  private static nextListenerId: number = 1
  private static listenerBindings: Map<number, TraceListenerBinding> = new Map()

  static async init(context: common.UIAbilityContext): Promise<boolean> {
    return PeripheralTraceMaintenanceService.initialize(context)
  }

  static async configure(retentionDays?: number, maxEntries?: number): Promise<boolean> {
    return PeripheralTraceMaintenanceService.configure(retentionDays, maxEntries)
  }

  static getRetentionConfig(): TraceRetentionConfig {
    return PeripheralTraceMaintenanceService.getRetentionConfig()
  }

  static addChangeListener(listener: TraceChangeListener): number {
    let listenerId = PeripheralTraceRepository.nextListenerId++
    let repositoryListenerId = PeripheralTraceEntryRepository.addChangeListener(() => {
      void PeripheralTraceRepository.dispatchChange(listenerId)
    })
    PeripheralTraceRepository.listenerBindings.set(listenerId, {
      listener,
      repositoryListenerId,
      previousTotalCount: -1
    })
    return listenerId
  }

  static removeChangeListener(listenerId: number): void {
    let binding = PeripheralTraceRepository.listenerBindings.get(listenerId)
    if (!binding) {
      return
    }
    PeripheralTraceEntryRepository.removeChangeListener(binding.repositoryListenerId)
    PeripheralTraceRepository.listenerBindings.delete(listenerId)
  }

  static async append(record: PeripheralTraceRecord): Promise<boolean> {
    return PeripheralTraceMaintenanceService.appendEntries([record])
  }

  static async appendBatch(records: PeripheralTraceRecord[]): Promise<boolean> {
    return PeripheralTraceMaintenanceService.appendEntries(records)
  }

  static async query(query?: PeripheralTraceQuery): Promise<PeripheralTraceRecord[]> {
    let pageOffset = query?.pageOffset && query.pageOffset > 0 ? Math.floor(query.pageOffset) : 0
    let pageSize = query?.pageSize && query.pageSize > 0 ? Math.floor(query.pageSize) : undefined
    return PeripheralTraceEntryRepository.listByQuery(query, pageSize, pageOffset)
  }

  static async getStats(query?: PeripheralTraceQuery): Promise<PeripheralTraceStats> {
    let records = await PeripheralTraceRepository.query(query)
    let stats: PeripheralTraceStats = {
      total: records.length,
      connects: 0,
      disconnects: 0,
      intercepts: 0,
      allows: 0,
      denies: 0,
      unknowns: 0,
      runtimeCount: 0,
      auditCount: 0,
      snapshotCount: 0
    }
    for (let record of records) {
      if (record.action === 'connect') {
        stats.connects++
      } else if (record.action === 'disconnect') {
        stats.disconnects++
      } else if (record.action === 'intercept') {
        stats.intercepts++
      }

      if (record.decision === 'allow') {
        stats.allows++
      } else if (record.decision === 'deny') {
        stats.denies++
      } else {
        stats.unknowns++
      }

      if (record.source === 'runtime_event') {
        stats.runtimeCount++
      } else if (record.source === 'audit_event') {
        stats.auditCount++
      } else {
        stats.snapshotCount++
      }
    }
    return stats
  }

  static async forceCleanup(retentionDays?: number, maxEntries?: number): Promise<number> {
    if (retentionDays !== undefined || maxEntries !== undefined) {
      let configured = await PeripheralTraceMaintenanceService.configure(retentionDays, maxEntries)
      if (!configured) {
        return 0
      }
    }
    let before = await PeripheralTraceEntryRepository.countByQuery()
    let reconciled = await PeripheralTraceMaintenanceService.reconcileStorageConfig()
    if (!reconciled) {
      return 0
    }
    let after = await PeripheralTraceEntryRepository.countByQuery()
    return Math.max(0, before - after)
  }

  static async clearAll(): Promise<boolean> {
    return PeripheralTraceMaintenanceService.clearAll()
  }

  private static async dispatchChange(listenerId: number): Promise<void> {
    let binding = PeripheralTraceRepository.listenerBindings.get(listenerId)
    if (!binding) {
      return
    }
    let totalCount = await PeripheralTraceEntryRepository.countByQuery()
    let addedCount = binding.previousTotalCount < 0 ? totalCount : Math.max(0, totalCount - binding.previousTotalCount)
    binding.previousTotalCount = totalCount
    let event: TraceChangeEvent = {
      totalCount,
      addedCount,
      timestamp: Date.now()
    }
    binding.listener(event)
  }
}
