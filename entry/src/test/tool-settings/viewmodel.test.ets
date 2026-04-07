import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { MockKit, when } from '@ohos/hamock'
import { CommonStrings } from '../../main/ets/constants/CommonStrings'
import { ToolSettingsStrings } from '../../main/ets/constants/modules/ToolSettingsStrings'
import { AuthMethod, ToolSettingsConfig } from '../../main/ets/models/DataModels'
import { AuthAvailabilityResult, AuthService } from '../../main/ets/services/identity/auth/AuthService'
import { SystemSettingsService } from '../../main/ets/services/tool-settings/system-settings/SystemSettingsService'
import { ToolSettingsRepository } from '../../main/ets/services/tool-settings/system-settings/ToolSettingsRepository'
import { ToolSettingsViewModel } from '../../main/ets/viewmodels/tool-settings/system-settings/ToolSettingsViewModel'

class FakeToolSettingsRepository implements ToolSettingsRepository {
  config: ToolSettingsConfig = {
    startupAuthEnabled: false,
    authMethod: AuthMethod.PIN
  }
  saveResult: boolean = true

  async loadConfig(_context: common.UIAbilityContext): Promise<ToolSettingsConfig> {
    return {
      startupAuthEnabled: this.config.startupAuthEnabled,
      authMethod: this.config.authMethod
    }
  }

  async saveConfig(_context: common.UIAbilityContext, config: ToolSettingsConfig): Promise<boolean> {
    if (this.saveResult) {
      this.config = {
        startupAuthEnabled: config.startupAuthEnabled,
        authMethod: config.authMethod
      }
    }
    return this.saveResult
  }
}

class FakeAuthAvailabilityResult implements AuthAvailabilityResult {
  available: boolean = false
  message: string = ''
  errorCode?: number
}

export default function toolSettingsViewModelTest() {
  describe('ToolSettingsViewModel', () => {
    let repository: FakeToolSettingsRepository
    let viewModel: ToolSettingsViewModel
    let context: common.UIAbilityContext
    let mockKit: MockKit

    beforeEach(() => {
      repository = new FakeToolSettingsRepository()
      viewModel = new ToolSettingsViewModel(repository)
      mockKit = new MockKit()
      context = {} as common.UIAbilityContext
    })

    afterEach(() => {
      mockKit.clearAll()
    })

    it('should initialize from repository config', 0, async (done: Function) => {
      repository.config = {
        startupAuthEnabled: true,
        authMethod: AuthMethod.FINGERPRINT
      }

      await viewModel.initialize(context)

      expect(viewModel.state.config.startupAuthEnabled).assertTrue()
      expect(viewModel.state.config.authMethod).assertEqual(AuthMethod.FINGERPRINT)
      expect(viewModel.selectedAuthMethodIndex).assertEqual(1)
      expect(viewModel.state.hasChanges).assertFalse()
      done()
    })

    it('should reject save when nothing changed', 0, async (done: Function) => {
      await viewModel.initialize(context)

      let result = await viewModel.requestSave(context)

      expect(result.kind).assertEqual('result')
      expect(result.status).assertEqual('failure')
      expect(result.message).assertEqual(CommonStrings.messageNoChanges)
      done()
    })

    it('should request confirmation when auth method is unavailable', 0, async (done: Function) => {
      await viewModel.initialize(context)
      viewModel.setStartupAuthEnabled(true)
      viewModel.setAuthMethod(AuthMethod.FINGERPRINT)
      let availabilityMock = mockKit.mockFunc(AuthService, AuthService.checkAuthMethodAvailability)
      let resultValue = new FakeAuthAvailabilityResult()
      resultValue.available = false
      resultValue.message = 'fingerprint unavailable'
      resultValue.errorCode = 401
      when(availabilityMock)(AuthMethod.FINGERPRINT).afterReturn(resultValue)

      let result = await viewModel.requestSave(context)

      expect(result.kind).assertEqual('confirm')
      expect(result.title).assertEqual(ToolSettingsStrings.authMethodUnavailableTitle)
      expect((result.message ?? '').indexOf('fingerprint unavailable') >= 0).assertTrue()
      done()
    })

    it('should save current config and clear dirty state', 0, async (done: Function) => {
      await viewModel.initialize(context)
      viewModel.setStartupAuthEnabled(true)
      viewModel.setAuthMethod(AuthMethod.FINGERPRINT)
      let availabilityMock = mockKit.mockFunc(AuthService, AuthService.checkAuthMethodAvailability)
      let resultValue = new FakeAuthAvailabilityResult()
      resultValue.available = true
      resultValue.message = 'available'
      when(availabilityMock)(AuthMethod.FINGERPRINT).afterReturn(resultValue)

      let result = await viewModel.requestSave(context)

      expect(result.kind).assertEqual('result')
      expect(result.status).assertEqual('success')
      expect(result.message).assertEqual(ToolSettingsStrings.saveSuccess)
      expect(viewModel.state.hasChanges).assertFalse()
      expect(repository.config.startupAuthEnabled).assertTrue()
      expect(repository.config.authMethod).assertEqual(AuthMethod.FINGERPRINT)
      done()
    })

    it('should return failure when opening password settings fails', 0, async (done: Function) => {
      let openSettingsMock = mockKit.mockFunc(SystemSettingsService, SystemSettingsService.openPasswordSettings)
      when(openSettingsMock)(context).afterReturn(false)

      let result = await viewModel.openPasswordSettings(context)

      expect(result.kind).assertEqual('result')
      expect(result.status).assertEqual('failure')
      expect(result.message).assertEqual(ToolSettingsStrings.openPasswordSettingsFailed)
      done()
    })
  })
}
