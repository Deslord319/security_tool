import { CommonStrings } from '../constants/CommonStrings'
import { LogManageStrings } from '../constants/modules/LogManageStrings'
import {
  DEFAULT_LOG_STORAGE_CONFIG,
  LOG_MAX_ENTRIES_OPTIONS,
  LOG_RETENTION_OPTIONS,
  LogStorageConfig
} from '../models/DataModels'
import { LogStorageService } from '../services/LogStorageService'

interface LogStorageSettingsState {
  maxEntriesIndex: number
  retentionIndex: number
  initialMaxEntriesIndex: number
  initialRetentionIndex: number
  hasChanges: boolean
}

export interface LogStorageSettingsSaveResult {
  success: boolean
  message: string
}

export class LogStorageSettingsViewModel {
  private static readonly DEFAULT_MAX_ENTRIES_INDEX: number = LogStorageSettingsViewModel.findOptionIndex(
    LOG_MAX_ENTRIES_OPTIONS,
    DEFAULT_LOG_STORAGE_CONFIG.maxLocalEntries,
    0
  )
  private static readonly DEFAULT_RETENTION_INDEX: number = LogStorageSettingsViewModel.findOptionIndex(
    LOG_RETENTION_OPTIONS,
    DEFAULT_LOG_STORAGE_CONFIG.retentionDays,
    0
  )

  state: LogStorageSettingsState = {
    maxEntriesIndex: LogStorageSettingsViewModel.DEFAULT_MAX_ENTRIES_INDEX,
    retentionIndex: LogStorageSettingsViewModel.DEFAULT_RETENTION_INDEX,
    initialMaxEntriesIndex: LogStorageSettingsViewModel.DEFAULT_MAX_ENTRIES_INDEX,
    initialRetentionIndex: LogStorageSettingsViewModel.DEFAULT_RETENTION_INDEX,
    hasChanges: false
  }

  initialize(config: LogStorageConfig): void {
    let maxEntriesIndex = LogStorageSettingsViewModel.findOptionIndex(
      LOG_MAX_ENTRIES_OPTIONS,
      config.maxLocalEntries,
      LogStorageSettingsViewModel.DEFAULT_MAX_ENTRIES_INDEX
    )
    let retentionIndex = LogStorageSettingsViewModel.findOptionIndex(
      LOG_RETENTION_OPTIONS,
      config.retentionDays,
      LogStorageSettingsViewModel.DEFAULT_RETENTION_INDEX
    )
    this.state = {
      maxEntriesIndex,
      retentionIndex,
      initialMaxEntriesIndex: maxEntriesIndex,
      initialRetentionIndex: retentionIndex,
      hasChanges: false
    }
  }

  setMaxEntriesIndex(index: number): void {
    let normalizedIndex = LogStorageSettingsViewModel.normalizeIndex(
      index,
      LOG_MAX_ENTRIES_OPTIONS.length,
      LogStorageSettingsViewModel.DEFAULT_MAX_ENTRIES_INDEX
    )
    this.state = {
      maxEntriesIndex: normalizedIndex,
      retentionIndex: this.state.retentionIndex,
      initialMaxEntriesIndex: this.state.initialMaxEntriesIndex,
      initialRetentionIndex: this.state.initialRetentionIndex,
      hasChanges: this.hasIndexChanges(normalizedIndex, this.state.retentionIndex)
    }
  }

  setRetentionIndex(index: number): void {
    let normalizedIndex = LogStorageSettingsViewModel.normalizeIndex(
      index,
      LOG_RETENTION_OPTIONS.length,
      LogStorageSettingsViewModel.DEFAULT_RETENTION_INDEX
    )
    this.state = {
      maxEntriesIndex: this.state.maxEntriesIndex,
      retentionIndex: normalizedIndex,
      initialMaxEntriesIndex: this.state.initialMaxEntriesIndex,
      initialRetentionIndex: this.state.initialRetentionIndex,
      hasChanges: this.hasIndexChanges(this.state.maxEntriesIndex, normalizedIndex)
    }
  }

  async save(): Promise<LogStorageSettingsSaveResult> {
    if (!this.state.hasChanges) {
      return { success: false, message: CommonStrings.messageNoChanges }
    }

    let success = await LogStorageService.updateConfig(this.getConfig())
    if (!success) {
      return { success: false, message: LogManageStrings.saveSettingsFailed }
    }

    this.initialize(LogStorageService.getConfig())
    return { success: true, message: LogManageStrings.saveSettingsSuccess }
  }

  getConfig(): LogStorageConfig {
    return {
      maxLocalEntries: LOG_MAX_ENTRIES_OPTIONS[this.state.maxEntriesIndex],
      retentionDays: LOG_RETENTION_OPTIONS[this.state.retentionIndex]
    }
  }

  private hasIndexChanges(maxEntriesIndex: number, retentionIndex: number): boolean {
    return this.state.initialMaxEntriesIndex !== maxEntriesIndex ||
      this.state.initialRetentionIndex !== retentionIndex
  }

  private static findOptionIndex(options: number[], value: number, fallbackIndex: number): number {
    let index = options.indexOf(value)
    return LogStorageSettingsViewModel.normalizeIndex(index, options.length, fallbackIndex)
  }

  private static normalizeIndex(index: number, optionCount: number, fallbackIndex: number): number {
    if (index >= 0 && index < optionCount) {
      return index
    }
    return fallbackIndex
  }
}
