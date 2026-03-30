import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { CommonStrings } from '../../main/ets/constants/CommonStrings'
import { ToolSettingsStrings } from '../../main/ets/constants/modules/ToolSettingsStrings'
import { AuthMethod, ToolSettingsConfig } from '../../main/ets/models/DataModels'
import { AuthAvailabilityResult, AuthService } from '../../main/ets/services/AuthService'
import { SystemSettingsService } from '../../main/ets/services/SystemSettingsService'
import { ToolSettingsRepository } from '../../main/ets/services/ToolSettingsRepository'
import { ToolSettingsViewModel } from '../../main/ets/viewmodels/ToolSettingsViewModel'

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

export default function toolSettingsViewModelTest() {
  describe('ToolSettingsViewModel', () => {
    let repository: FakeToolSettingsRepository
    let viewModel: ToolSettingsViewModel
    let context: common.UIAbilityContext
    let originalCheckAuthMethodAvailability: (authMethod: AuthMethod) => AuthAvailabilityResult
    let originalOpenPasswordSettings: (context: common.UIAbilityContext) => Promise<boolean>

    beforeEach(() => {
      repository = new FakeToolSettingsRepository()
      viewModel = new ToolSettingsViewModel(repository)
      context = {} as common.UIAbilityContext
      originalCheckAuthMethodAvailability = AuthService.checkAuthMethodAvailability
      originalOpenPasswordSettings = SystemSettingsService.openPasswordSettings
    })

    afterEach(() => {
      AuthService.checkAuthMethodAvailability = originalCheckAuthMethodAvailability
      SystemSettingsService.openPasswordSettings = originalOpenPasswordSettings
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
      AuthService.checkAuthMethodAvailability = (_authMethod: AuthMethod): AuthAvailabilityResult => {
        return {
          available: false,
          message: 'fingerprint unavailable',
          errorCode: 401
        }
      }

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
      AuthService.checkAuthMethodAvailability = (_authMethod: AuthMethod): AuthAvailabilityResult => {
        return {
          available: true,
          message: 'available'
        }
      }

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
      SystemSettingsService.openPasswordSettings = async (_context: common.UIAbilityContext): Promise<boolean> => false

      let result = await viewModel.openPasswordSettings(context)

      expect(result.kind).assertEqual('result')
      expect(result.status).assertEqual('failure')
      expect(result.message).assertEqual(ToolSettingsStrings.openPasswordSettingsFailed)
      done()
    })
  })
}
