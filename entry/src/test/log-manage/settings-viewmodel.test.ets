import { beforeEach, describe, expect, it } from '@ohos/hypium'
import { LogStorageConfig } from '../../main/ets/models/DataModels'
import {
  LogStorageMaintenancePort,
  MutationResult,
  ServiceResult
} from '../../main/ets/services/log-manage/common/LogManagePorts'
import {
  LogStorageSettingsDependencies,
  LogStorageSettingsViewModel
} from '../../main/ets/viewmodels/log-manage/storage-settings/LogStorageSettingsViewModel'

interface LogStorageConfigRepositoryPort {
  loadStorageConfig(): Promise<LogStorageConfig>
  saveStorageConfig(config: LogStorageConfig): Promise<ServiceResult>
}

class FakeLogStorageConfigRepository implements LogStorageConfigRepositoryPort {
  config: LogStorageConfig = {
    maxLocalEntries: 5000,
    retentionDays: 30
  }
  saveResult: ServiceResult = { success: true, code: 'ok' }
  saveCallCount: number = 0
  loadCallCount: number = 0
  failOnSaveCallNumbers: number[] = []

  async loadStorageConfig(): Promise<LogStorageConfig> {
    this.loadCallCount++
    return {
      maxLocalEntries: this.config.maxLocalEntries,
      retentionDays: this.config.retentionDays
    }
  }

  async saveStorageConfig(config: LogStorageConfig): Promise<ServiceResult> {
    this.saveCallCount++
    if (this.failOnSaveCallNumbers.includes(this.saveCallCount)) {
      return { success: false, code: 'save_failed' }
    }
    if (this.saveResult.success) {
      this.config = {
        maxLocalEntries: config.maxLocalEntries,
        retentionDays: config.retentionDays
      }
    }
    return this.saveResult
  }
}

class FakeLogStorageMaintenanceRepository implements LogStorageMaintenancePort {
  reconcileResult: MutationResult = { success: true, code: 'ok' }
  reconcileCallCount: number = 0
  queuedResults: MutationResult[] = []

  async reconcileStorageConfig(): Promise<MutationResult> {
    this.reconcileCallCount++
    if (this.queuedResults.length > 0) {
      return this.queuedResults.shift() as MutationResult
    }
    return this.reconcileResult
  }
}

class FakeLogStorageSettingsDependencies implements LogStorageSettingsDependencies {
  configRepository: FakeLogStorageConfigRepository
  storageMaintenance: FakeLogStorageMaintenanceRepository

  constructor(
    configRepository: FakeLogStorageConfigRepository,
    storageMaintenance: FakeLogStorageMaintenanceRepository
  ) {
    this.configRepository = configRepository
    this.storageMaintenance = storageMaintenance
  }
}

export default function logStorageSettingsViewModelTest() {
  describe('LogStorageSettingsViewModel', () => {
    let configRepository: FakeLogStorageConfigRepository
    let storageMaintenance: FakeLogStorageMaintenanceRepository
    let viewModel: LogStorageSettingsViewModel

    beforeEach(() => {
      configRepository = new FakeLogStorageConfigRepository()
      storageMaintenance = new FakeLogStorageMaintenanceRepository()
      let dependencies: LogStorageSettingsDependencies = new FakeLogStorageSettingsDependencies(configRepository, storageMaintenance)
      viewModel = new LogStorageSettingsViewModel(dependencies)
    })

    it('should load real config values instead of select indices', 0, async () => {
      let result: ServiceResult = await viewModel.load()

      expect(result.success).assertTrue()
      expect(viewModel.state.maxLocalEntries).assertEqual(5000)
      expect(viewModel.state.retentionDays).assertEqual(30)
      expect(viewModel.state.dirty).assertFalse()
    })

    it('should mark form dirty after changing values', 0, async () => {
      await viewModel.load()
      viewModel.setMaxLocalEntries(10000)
      viewModel.setRetentionDays(14)

      expect(viewModel.state.dirty).assertTrue()
      expect(viewModel.state.maxLocalEntries).assertEqual(10000)
      expect(viewModel.state.retentionDays).assertEqual(14)
    })

    it('should save numeric config values and clear dirty state', 0, async () => {
      await viewModel.load()
      viewModel.setMaxLocalEntries(10000)

      let result: ServiceResult = await viewModel.save()

      expect(result.success).assertTrue()
      expect(configRepository.config.maxLocalEntries).assertEqual(10000)
      expect(viewModel.state.dirty).assertFalse()
    })

    it('should reject save when no changes exist', 0, async () => {
      await viewModel.load()

      let result: ServiceResult = await viewModel.save()

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('no_changes')
    })

    it('should rollback persisted config when reconcile fails after save', 0, async () => {
      await viewModel.load()
      viewModel.setMaxLocalEntries(10000)
      storageMaintenance.reconcileResult = { success: false, code: 'save_failed' }

      let result: ServiceResult = await viewModel.save()

      expect(result.success).assertFalse()
      expect(configRepository.config.maxLocalEntries).assertEqual(5000)
      expect(viewModel.state.maxLocalEntries).assertEqual(5000)
      expect(viewModel.state.dirty).assertFalse()
      expect(storageMaintenance.reconcileCallCount).assertEqual(2)
    })

    it('should reload current persisted config when rollback save fails', 0, async () => {
      await viewModel.load()
      viewModel.setMaxLocalEntries(10000)
      storageMaintenance.reconcileResult = { success: false, code: 'save_failed' }
      configRepository.failOnSaveCallNumbers = [2]

      let result: ServiceResult = await viewModel.save()

      expect(result.success).assertFalse()
      expect(configRepository.config.maxLocalEntries).assertEqual(10000)
      expect(viewModel.state.maxLocalEntries).assertEqual(10000)
      expect(viewModel.state.dirty).assertFalse()
      expect(configRepository.loadCallCount >= 2).assertTrue()
      expect(storageMaintenance.reconcileCallCount).assertEqual(1)
    })

    it('should reload rolled-back config when rollback reconcile also fails', 0, async () => {
      await viewModel.load()
      viewModel.setMaxLocalEntries(10000)
      storageMaintenance.queuedResults = [
        { success: false, code: 'save_failed' },
        { success: false, code: 'save_failed' }
      ]

      let result: ServiceResult = await viewModel.save()

      expect(result.success).assertFalse()
      expect(configRepository.config.maxLocalEntries).assertEqual(5000)
      expect(viewModel.state.maxLocalEntries).assertEqual(5000)
      expect(viewModel.state.dirty).assertFalse()
      expect(storageMaintenance.reconcileCallCount).assertEqual(2)
    })
  })
}
