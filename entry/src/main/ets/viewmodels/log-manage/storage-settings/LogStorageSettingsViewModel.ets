import { LogUtils } from '../../../utils/LogUtils'
import { LOG_MAX_ENTRIES_OPTIONS, LOG_RETENTION_OPTIONS, LogStorageConfig } from '../../../models/DataModels'
import { LogStorageSettingsState } from '../../../models/LogManageModels'
import {
  LogStorageMaintenancePort,
  SaveSettingsResult,
  ServiceResult
} from '../../../services/log-manage/common/LogManagePorts'
import { LogStorageMaintenanceService } from '../../../services/log-manage/maintenance/LogStorageMaintenanceService'
import { LogSettingsRepository } from '../../../services/log-manage/repository/LogSettingsRepository'

const TAG = 'LogStorageSettingsVM'

interface LogStorageConfigPersistencePort {
  loadStorageConfig(): Promise<LogStorageConfig>
  saveStorageConfig(config: LogStorageConfig): Promise<ServiceResult>
}

class DefaultLogStorageConfigRepository implements LogStorageConfigPersistencePort {
  loadStorageConfig(): Promise<LogStorageConfig> {
    return LogSettingsRepository.loadStorageConfig()
  }

  saveStorageConfig(config: LogStorageConfig): Promise<ServiceResult> {
    return LogSettingsRepository.saveStorageConfig(config)
  }
}

class DefaultLogStorageMaintenanceRepository implements LogStorageMaintenancePort {
  reconcileStorageConfig() {
    return LogStorageMaintenanceService.reconcileStorageConfig()
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

@ObservedV2
export class LogStorageSettingsViewModel {
  @Trace state: LogStorageSettingsState = new LogStorageSettingsState()
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
      this.state.maxLocalEntries = config.maxLocalEntries
      this.state.retentionDays = config.retentionDays
      this.state.dirty = false
      this.state.saving = false
      return { success: true, code: 'ok' }
    } catch (err) {
      LogUtils.error(TAG, `load failed: ${JSON.stringify(err)}`)
      return { success: false, code: 'config_init_failed' }
    }
  }

  setMaxLocalEntries(value: number): void {
    this.state.maxLocalEntries = value
    this.state.dirty = this.isDirty(value, this.state.retentionDays)
  }

  setRetentionDays(value: number): void {
    this.state.retentionDays = value
    this.state.dirty = this.isDirty(this.state.maxLocalEntries, value)
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
    this.state.saving = true
    try {
      let previousConfig = this.cloneConfig(this.initialConfig.maxLocalEntries, this.initialConfig.retentionDays)
      let nextConfig = this.cloneConfig(this.state.maxLocalEntries, this.state.retentionDays)
      let saveResult = await this.dependencies.configRepository.saveStorageConfig(nextConfig)
      if (!saveResult.success) {
        this.finishSavingWithFailure()
        return this.buildSaveResult(false, 'save_failed')
      }
      let reconcileResult = await this.dependencies.storageMaintenance.reconcileStorageConfig()
      if (!reconcileResult.success) {
        await this.rollbackConfig(previousConfig)
        this.finishSavingWithFailure()
        return this.buildSaveResult(false, 'save_failed')
      }
      this.initialConfig = this.cloneConfig(this.state.maxLocalEntries, this.state.retentionDays)
      this.state.dirty = false
      this.state.saving = false
      return this.buildSaveResult(true, 'ok')
    } catch (err) {
      LogUtils.error(TAG, `save failed: ${JSON.stringify(err)}`)
      this.finishSavingWithFailure()
      return this.buildSaveResult(false, 'save_failed')
    }
  }

  reset(): void {
    this.state.maxLocalEntries = this.initialConfig.maxLocalEntries
    this.state.retentionDays = this.initialConfig.retentionDays
    this.state.dirty = false
    this.state.saving = false
  }

  private finishSavingWithFailure(): void {
    this.state.saving = false
  }

  private async rollbackConfig(previousConfig: LogStorageConfig): Promise<void> {
    try {
      let rollbackResult = await this.dependencies.configRepository.saveStorageConfig(previousConfig)
      if (!rollbackResult.success) {
        await this.load()
        return
      }
      let reconciled = await this.dependencies.storageMaintenance.reconcileStorageConfig()
      if (!reconciled.success) {
        await this.load()
        return
      }
      this.state.maxLocalEntries = previousConfig.maxLocalEntries
      this.state.retentionDays = previousConfig.retentionDays
      this.state.dirty = false
      this.state.saving = false
    } catch (err) {
      LogUtils.error(TAG, `rollback failed: ${JSON.stringify(err)}`)
      await this.load()
    }
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
