import { describe, it, expect } from '@ohos/hypium'
import {
  DEFAULT_LOG_STORAGE_CONFIG,
  LOG_MAX_ENTRIES_OPTIONS,
  LOG_RETENTION_OPTIONS
} from '../../main/ets/models/DataModels'
import { LogStorageService } from '../../main/ets/services/LogStorageService'
import { LogStorageSettingsViewModel } from '../../main/ets/viewmodels/LogStorageSettingsViewModel'

export default function logStorageSettingsViewModelTest() {
  describe('LogStorageSettingsViewModel', () => {
    it('should initialize to matching option indexes', 0, () => {
      let viewModel = new LogStorageSettingsViewModel()
      viewModel.initialize({
        maxLocalEntries: 1000,
        retentionDays: 14
      })

      expect(viewModel.state.maxEntriesIndex).assertEqual(LOG_MAX_ENTRIES_OPTIONS.indexOf(1000))
      expect(viewModel.state.retentionIndex).assertEqual(LOG_RETENTION_OPTIONS.indexOf(14))
      expect(viewModel.state.hasChanges).assertFalse()
    })

    it('should normalize unsupported values to defaults', 0, () => {
      let viewModel = new LogStorageSettingsViewModel()
      viewModel.initialize({
        maxLocalEntries: 123,
        retentionDays: 999
      })

      expect(viewModel.state.maxEntriesIndex).assertEqual(LOG_MAX_ENTRIES_OPTIONS.indexOf(DEFAULT_LOG_STORAGE_CONFIG.maxLocalEntries))
      expect(viewModel.state.retentionIndex).assertEqual(LOG_RETENTION_OPTIONS.indexOf(DEFAULT_LOG_STORAGE_CONFIG.retentionDays))
    })

    it('should mark changes when indexes change and rebuild config', 0, () => {
      let viewModel = new LogStorageSettingsViewModel()
      viewModel.initialize(DEFAULT_LOG_STORAGE_CONFIG)
      viewModel.setMaxEntriesIndex(0)

      expect(viewModel.state.hasChanges).assertTrue()
      expect(viewModel.getConfig().maxLocalEntries).assertEqual(LOG_MAX_ENTRIES_OPTIONS[0])
      expect(viewModel.getConfig().retentionDays).assertEqual(DEFAULT_LOG_STORAGE_CONFIG.retentionDays)
    })

    it('should save with real storage service and reset dirty state', 0, async (done: Function) => {
      let originalConfig = LogStorageService.getConfig()
      let viewModel = new LogStorageSettingsViewModel()
      viewModel.initialize(originalConfig)

      let nextIndex = originalConfig.maxLocalEntries === LOG_MAX_ENTRIES_OPTIONS[0] ? 1 : 0
      viewModel.setMaxEntriesIndex(nextIndex)
      let expectedMaxEntries = LOG_MAX_ENTRIES_OPTIONS[nextIndex]

      let result = await viewModel.save()
      expect(result.success).assertTrue()
      expect(viewModel.state.hasChanges).assertFalse()
      expect(LogStorageService.getConfig().maxLocalEntries).assertEqual(expectedMaxEntries)

      await LogStorageService.updateConfig(originalConfig)
      done()
    })
  })
}
