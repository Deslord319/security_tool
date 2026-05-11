import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { MockKit, when } from '@ohos/hamock'
import { MessageText } from '../../main/ets/constants/StringCatalog'
import { ToolSettingsConfirmationStrings, ToolSettingsPageStrings } from '../../main/ets/constants/modules/ToolSettingsStrings'
import { AuthMethod } from '../../main/ets/models/AuthModels'
import { ToolSettingsConfig } from '../../main/ets/models/ToolSettingsModels'
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
  saveDelay: number = 0

  async loadConfig(_context: common.UIAbilityContext): Promise<ToolSettingsConfig> {
    return {
      startupAuthEnabled: this.config.startupAuthEnabled,
      authMethod: this.config.authMethod
    }
  }

  async saveConfig(_context: common.UIAbilityContext, config: ToolSettingsConfig): Promise<boolean> {
    if (this.saveDelay > 0) {
      await new Promise<void>((resolve) => setTimeout(resolve, this.saveDelay))
    }
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
      expect(result.message).assertEqual(MessageText.NO_CHANGES)
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
      expect(result.title).assertEqual(ToolSettingsConfirmationStrings.AUTH_METHOD_UNAVAILABLE_TITLE)
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
      expect(result.message).assertEqual(ToolSettingsPageStrings.SAVE_SUCCESS)
      expect(viewModel.state.hasChanges).assertFalse()
      expect(repository.config.startupAuthEnabled).assertTrue()
      expect(repository.config.authMethod).assertEqual(AuthMethod.FINGERPRINT)
      done()
    })

    it('should allow explicit save after unsupported auth confirmation', 0, async (done: Function) => {
      await viewModel.initialize(context)
      viewModel.setStartupAuthEnabled(true)
      viewModel.setAuthMethod(AuthMethod.FINGERPRINT)

      let result = await viewModel.requestSave(context, true)

      expect(result.kind).assertEqual('result')
      expect(result.status).assertEqual('success')
      expect(repository.config.startupAuthEnabled).assertTrue()
      expect(repository.config.authMethod).assertEqual(AuthMethod.FINGERPRINT)
      done()
    })

    it('should return failure when repository save fails', 0, async (done: Function) => {
      await viewModel.initialize(context)
      repository.saveResult = false
      viewModel.setStartupAuthEnabled(true)

      let result = await viewModel.requestSave(context, true)

      expect(result.kind).assertEqual('result')
      expect(result.status).assertEqual('failure')
      expect(result.message).assertEqual(MessageText.SAVE_FAILED)
      done()
    })

    it('should return failure when opening password settings fails', 0, async (done: Function) => {
      let openSettingsMock = mockKit.mockFunc(SystemSettingsService, SystemSettingsService.openPasswordSettings)
      when(openSettingsMock)(context).afterReturn(false)

      let result = await viewModel.openPasswordSettings(context)

      expect(result.kind).assertEqual('result')
      expect(result.status).assertEqual('failure')
      expect(result.message).assertEqual(ToolSettingsPageStrings.OPEN_PASSWORD_SETTINGS_FAILED)
      done()
    })

    it('should return none when opening password settings succeeds', 0, async (done: Function) => {
      let openSettingsMock = mockKit.mockFunc(SystemSettingsService, SystemSettingsService.openPasswordSettings)
      when(openSettingsMock)(context).afterReturn(true)

      let result = await viewModel.openPasswordSettings(context)

      expect(result.kind).assertEqual('none')
      done()
    })

    it('should skip save when already saving', 0, async (done: Function) => {
      await viewModel.initialize(context)
      viewModel.setStartupAuthEnabled(true)
      repository.saveDelay = 100

      let firstSave = viewModel.requestSave(context, true)
      let secondResult = await viewModel.requestSave(context, true)

      expect(secondResult.kind).assertEqual('none')

      await firstSave
      done()
    })

    it('should not update config when setting same startupAuthEnabled value', 0, async (done: Function) => {
      await viewModel.initialize(context)

      viewModel.setStartupAuthEnabled(false)

      expect(viewModel.state.hasChanges).assertFalse()
      done()
    })

    it('should not update config when setting same authMethod value', 0, async (done: Function) => {
      await viewModel.initialize(context)

      viewModel.setAuthMethod(AuthMethod.PIN)

      expect(viewModel.state.hasChanges).assertFalse()
      done()
    })

    it('should return 0 for selectedAuthMethodIndex when auth method not found in options', 0, async (done: Function) => {
      await viewModel.initialize(context)
      viewModel.state.config.authMethod = 999 as AuthMethod

      expect(viewModel.selectedAuthMethodIndex).assertEqual(0)
      done()
    })

    it('should skip auth availability check when startup auth is disabled', 0, async (done: Function) => {
      await viewModel.initialize(context)
      viewModel.setAuthMethod(AuthMethod.FINGERPRINT)

      let result = await viewModel.requestSave(context)

      expect(result.kind).assertEqual('result')
      expect(result.status).assertEqual('success')
      done()
    })

    it('should save successfully when auth method is available and startup auth enabled', 0, async (done: Function) => {
      await viewModel.initialize(context)
      viewModel.setStartupAuthEnabled(true)
      let availabilityMock = mockKit.mockFunc(AuthService, AuthService.checkAuthMethodAvailability)
      let resultValue = new FakeAuthAvailabilityResult()
      resultValue.available = true
      resultValue.message = 'available'
      when(availabilityMock)(AuthMethod.PIN).afterReturn(resultValue)

      let result = await viewModel.requestSave(context)

      expect(result.kind).assertEqual('result')
      expect(result.status).assertEqual('success')
      done()
    })
  })
}
