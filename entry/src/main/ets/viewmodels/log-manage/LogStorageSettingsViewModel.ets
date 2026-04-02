import { LogUtils } from '../../utils/LogUtils'
import { LOG_MAX_ENTRIES_OPTIONS, LOG_RETENTION_OPTIONS, LogStorageConfig } from '../../models/DataModels'
import { LogStorageSettingsState } from '../../models/LogManageModels'
import {
  LogConfigRepositoryPort,
  LogStorageMaintenancePort,
  SaveSettingsResult,
  ServiceResult
} from '../../services/log-manage/common/LogManagePorts'
import { LogConfigRepository } from '../../services/log-manage/repository/LogConfigRepository'
import { LogRepository } from '../../services/log-manage/repository/LogRepository'

const TAG = 'LogStorageSettingsVM'

interface LogStorageConfigPersistencePort {
  loadStorageConfig(): Promise<LogStorageConfig>
  saveStorageConfig(config: LogStorageConfig): Promise<ServiceResult>
}

class DefaultLogStorageConfigRepository implements LogStorageConfigPersistencePort {
  loadStorageConfig(): Promise<LogStorageConfig> {
    return LogConfigRepository.loadStorageConfig()
  }

  saveStorageConfig(config: LogStorageConfig): Promise<ServiceResult> {
    return LogConfigRepository.saveStorageConfig(config)
  }
}

class DefaultLogStorageMaintenanceRepository implements LogStorageMaintenancePort {
  reconcileStorageConfig() {
    return LogRepository.reconcileStorageConfig()
  }
}

export interface LogStorageSettingsDependencies {
  configRepository: LogStorageConfigPersistencePort
  storageMaintenance: LogStorageMaintenancePort
}

function buildDefaultDependencies(): LogStorageSettingsDependencies {
  return {
    configRepository: new DefaultLogStorageConfigRepository(),
    storageMaintenance: new DefaultLogStorageMaintenanceRepository()
  }
}

@Observed
export class LogStorageSettingsViewModel {
  state: LogStorageSettingsState = new LogStorageSettingsState()
  private initialConfig: LogStorageConfig = {
    maxLocalEntries: 0,
    retentionDays: 0
  }
  private dependencies: LogStorageSettingsDependencies

  constructor(dependencies: LogStorageSettingsDependencies = buildDefaultDependencies()) {
    this.dependencies = dependencies
  }

  async load(): Promise<ServiceResult> {
    try {
      let config = await this.dependencies.configRepository.loadStorageConfig()
      this.initialConfig = this.cloneConfig(config.maxLocalEntries, config.retentionDays)
      let nextState = new LogStorageSettingsState()
      nextState.maxLocalEntries = config.maxLocalEntries
      nextState.retentionDays = config.retentionDays
      nextState.dirty = false
      nextState.saving = false
      this.setState(nextState)
      return { success: true, code: 'ok' }
    } catch (err) {
      LogUtils.error(TAG, `load failed: ${JSON.stringify(err)}`)
      return { success: false, code: 'config_init_failed' }
    }
  }

  setMaxLocalEntries(value: number): void {
    let nextState = this.cloneState()
    nextState.maxLocalEntries = value
    nextState.dirty = this.isDirty(value, nextState.retentionDays)
    this.setState(nextState)
  }

  setRetentionDays(value: number): void {
    let nextState = this.cloneState()
    nextState.retentionDays = value
    nextState.dirty = this.isDirty(nextState.maxLocalEntries, value)
    this.setState(nextState)
  }

  async save(): Promise<SaveSettingsResult> {
    if (!this.state.dirty) {
      return this.buildSaveResult(false, 'no_changes')
    }
    if (!LOG_MAX_ENTRIES_OPTIONS.includes(this.state.maxLocalEntries)) {
      return this.buildSaveResult(false, 'invalid_max_entries')
    }
    if (!LOG_RETENTION_OPTIONS.includes(this.state.retentionDays)) {
      return this.buildSaveResult(false, 'invalid_retention')
    }
    let savingState = this.cloneState()
    savingState.saving = true
    this.setState(savingState)
    try {
      let saveResult = await this.dependencies.configRepository.saveStorageConfig(
        this.cloneConfig(this.state.maxLocalEntries, this.state.retentionDays)
      )
      if (!saveResult.success) {
        this.finishSavingWithFailure()
        return this.buildSaveResult(false, 'save_failed')
      }
      let reconcileResult = await this.dependencies.storageMaintenance.reconcileStorageConfig()
      if (!reconcileResult.success) {
        this.finishSavingWithFailure()
        return this.buildSaveResult(false, 'save_failed')
      }
      this.initialConfig = this.cloneConfig(this.state.maxLocalEntries, this.state.retentionDays)
      let nextState = this.cloneState()
      nextState.dirty = false
      nextState.saving = false
      this.setState(nextState)
      return this.buildSaveResult(true, 'ok')
    } catch (err) {
      LogUtils.error(TAG, `save failed: ${JSON.stringify(err)}`)
      this.finishSavingWithFailure()
      return this.buildSaveResult(false, 'save_failed')
    }
  }

  reset(): void {
    let nextState = this.cloneState()
    nextState.maxLocalEntries = this.initialConfig.maxLocalEntries
    nextState.retentionDays = this.initialConfig.retentionDays
    nextState.dirty = false
    this.setState(nextState)
  }

  private finishSavingWithFailure(): void {
    let failedState = this.cloneState()
    failedState.saving = false
    this.setState(failedState)
  }

  private isDirty(maxLocalEntries: number, retentionDays: number): boolean {
    return maxLocalEntries !== this.initialConfig.maxLocalEntries ||
      retentionDays !== this.initialConfig.retentionDays
  }

  private cloneConfig(maxLocalEntries: number, retentionDays: number): LogStorageConfig {
    return {
      maxLocalEntries: maxLocalEntries,
      retentionDays: retentionDays
    }
  }

  private cloneState(): LogStorageSettingsState {
    let nextState = new LogStorageSettingsState()
    nextState.maxLocalEntries = this.state.maxLocalEntries
    nextState.retentionDays = this.state.retentionDays
    nextState.dirty = this.state.dirty
    nextState.saving = this.state.saving
    return nextState
  }

  private setState(nextState: LogStorageSettingsState): void {
    this.state = nextState
  }

  private buildSaveResult(
    success: boolean,
    code: 'ok' | 'no_changes' | 'invalid_retention' | 'invalid_max_entries' | 'save_failed'
  ): SaveSettingsResult {
    return {
      success: success,
      code: code
    }
  }
}
