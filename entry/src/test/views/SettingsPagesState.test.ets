import { describe, expect, it } from '@ohos/hypium'
import { AuthMethod } from '../../main/ets/models/DataModels'
import { ApplicationRuntimeManager } from '../../main/ets/runtime/ApplicationRuntimeManager'
import { IdentitySettingsViewModel } from '../../main/ets/viewmodels/identity/settings/IdentitySettingsViewModel'
import { ToolSettingsViewModel } from '../../main/ets/viewmodels/tool-settings/system-settings/ToolSettingsViewModel'

interface IdentityPageBoundaryHost {
  viewModel: IdentitySettingsViewModel
}

interface ToolSettingsPageBoundaryHost {
  viewModel: ToolSettingsViewModel
}

export default function settingsPagesStateTest() {
  describe('Settings pages state boundary', () => {
    it('should keep identity edits when page remounts with shared viewModel', 0, () => {
      const sharedViewModel = new IdentitySettingsViewModel()
      sharedViewModel.state.initialized = true
      sharedViewModel.state.adminActivated = true
      sharedViewModel.setMinLengthIndex(2)

      const firstPage: IdentityPageBoundaryHost = {
        viewModel: sharedViewModel
      }
      const remountedPage: IdentityPageBoundaryHost = {
        viewModel: sharedViewModel
      }

      expect(firstPage.viewModel === remountedPage.viewModel).assertTrue()
      expect(remountedPage.viewModel.state.minLengthIndex).assertEqual(2)
      expect(remountedPage.viewModel.state.hasChanges).assertTrue()
    })

    it('should keep tool setting edits when page remounts with shared viewModel', 0, () => {
      const sharedViewModel = new ToolSettingsViewModel()
      sharedViewModel.state.initialized = true
      sharedViewModel.setStartupAuthEnabled(true)
      sharedViewModel.setAuthMethod(AuthMethod.FINGERPRINT)

      const firstPage: ToolSettingsPageBoundaryHost = {
        viewModel: sharedViewModel
      }
      const remountedPage: ToolSettingsPageBoundaryHost = {
        viewModel: sharedViewModel
      }

      expect(firstPage.viewModel === remountedPage.viewModel).assertTrue()
      expect(remountedPage.viewModel.state.config.startupAuthEnabled).assertTrue()
      expect(remountedPage.viewModel.state.config.authMethod).assertEqual(AuthMethod.FINGERPRINT)
      expect(remountedPage.viewModel.state.hasChanges).assertTrue()
    })

    it('should expose shared identity and tool settings viewModels from runtime manager', 0, () => {
      const manager = ApplicationRuntimeManager.getInstance()

      expect(manager.getIdentitySettingsViewModel() === manager.getIdentitySettingsViewModel()).assertTrue()
      expect(manager.getToolSettingsViewModel() === manager.getToolSettingsViewModel()).assertTrue()
    })
  })
}
