import { LogEntryNormalizer } from '../mapper/LogEntryNormalizer'
import { LogSettingsRepository } from '../repository/LogSettingsRepository'
import { LogEntryRepository } from '../repository/LogEntryRepository'
import { MutationResult } from '../common/LogManagePorts'

export class LogStorageMaintenanceService {
  static async reconcileStorageConfig(): Promise<MutationResult> {
    let config = await LogSettingsRepository.loadStorageConfig()
    let retentionDays = LogEntryNormalizer.normalizeRetentionDays(config.retentionDays)
    let maxEntries = LogEntryNormalizer.normalizeMaxEntries(config.maxLocalEntries)
    let cutoff = Date.now() - retentionDays * 24 * 60 * 60 * 1000
    let cleaned = await LogEntryRepository.deleteExpired(cutoff)
    if (!cleaned) {
      return { success: false, code: 'save_failed' }
    }
    let trimmed = await LogEntryRepository.trimToMaxEntries(maxEntries)
    if (!trimmed) {
      return { success: false, code: 'save_failed' }
    }
    return { success: true, code: 'ok' }
  }
}
