import { beforeEach, describe, expect, it } from '@ohos/hypium'
import { LogStorageConfig } from '../../main/ets/models/DataModels'
import {
  LogConfigRepositoryPort,
  LogStorageMaintenancePort,
  MutationResult,
  ServiceResult
} from '../../main/ets/services/log-manage/common/LogManagePorts'
import {
  LogStorageSettingsDependencies,
  LogStorageSettingsViewModel
} from '../../main/ets/viewmodels/log-manage/storage-settings/LogStorageSettingsViewModel'

class FakeLogStorageConfigRepository implements Pick<LogConfigRepositoryPort, 'loadStorageConfig' | 'saveStorageConfig'> {
  config: LogStorageConfig = {
    maxLocalEntries: 5000,
    retentionDays: 30
  }
  saveResult: ServiceResult = { success: true, code: 'ok' }

  async loadStorageConfig(): Promise<LogStorageConfig> {
    return {
      maxLocalEntries: this.config.maxLocalEntries,
      retentionDays: this.config.retentionDays
    }
  }

  async saveStorageConfig(config: LogStorageConfig): Promise<ServiceResult> {
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

  async reconcileStorageConfig(): Promise<MutationResult> {
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

    it('should load real config values instead of select indices', 0, async (done: Function) => {
      let result: ServiceResult = await viewModel.load()

      expect(result.success).assertTrue()
      expect(viewModel.state.maxLocalEntries).assertEqual(5000)
      expect(viewModel.state.retentionDays).assertEqual(30)
      expect(viewModel.state.dirty).assertFalse()
      done()
    })

    it('should mark form dirty after changing values', 0, async (done: Function) => {
      await viewModel.load()
      viewModel.setMaxLocalEntries(1000)
      viewModel.setRetentionDays(14)

      expect(viewModel.state.dirty).assertTrue()
      expect(viewModel.state.maxLocalEntries).assertEqual(1000)
      expect(viewModel.state.retentionDays).assertEqual(14)
      done()
    })

    it('should save numeric config values and clear dirty state', 0, async (done: Function) => {
      await viewModel.load()
      viewModel.setMaxLocalEntries(2000)

      let result: ServiceResult = await viewModel.save()

      expect(result.success).assertTrue()
      expect(configRepository.config.maxLocalEntries).assertEqual(2000)
      expect(viewModel.state.dirty).assertFalse()
      done()
    })

    it('should reject save when no changes exist', 0, async (done: Function) => {
      await viewModel.load()

      let result: ServiceResult = await viewModel.save()

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('no_changes')
      done()
    })
  })
}
