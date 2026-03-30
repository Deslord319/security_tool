import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { securityManager } from '@kit.MDMKit'
import { CommonStrings } from '../../main/ets/constants/CommonStrings'
import { IdentityStrings } from '../../main/ets/constants/modules/IdentityStrings'
import { PASSWORD_VALIDITY_OPTIONS, PasswordComplexityConfig } from '../../main/ets/models/DataModels'
import { IdentityService } from '../../main/ets/services/IdentityService'
import {
  CUSTOM_VALIDITY_OPTION_INDEX,
  IdentitySettingsViewModel
} from '../../main/ets/viewmodels/IdentitySettingsViewModel'
import { DialogService } from '../../main/ets/utils/DialogService'

export default function identitySettingsViewModelTest() {
  describe('IdentitySettingsViewModel', () => {
    let originalGetPasswordPolicyWithResult: () => Object
    let originalBuildComplexityRegex: (config: PasswordComplexityConfig) => string
    let originalSetPasswordPolicyWithResult: (config: PasswordComplexityConfig) => Object
    let originalDisplayReason: (primaryMessage?: string, fallbackMessage?: string) => string

    beforeEach(() => {
      originalGetPasswordPolicyWithResult = IdentityService.getPasswordPolicyWithResult
      originalBuildComplexityRegex = IdentityService.buildComplexityRegex
      originalSetPasswordPolicyWithResult = IdentityService.setPasswordPolicyWithResult
      originalDisplayReason = DialogService.displayReason
    })

    afterEach(() => {
      IdentityService.getPasswordPolicyWithResult = originalGetPasswordPolicyWithResult
      IdentityService.buildComplexityRegex = originalBuildComplexityRegex
      IdentityService.setPasswordPolicyWithResult = originalSetPasswordPolicyWithResult
      DialogService.displayReason = originalDisplayReason
    })

    it('should initialize from password policy', 0, () => {
      let viewModel = new IdentitySettingsViewModel()
      viewModel.initialize({
        complexityRegex: '^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)[a-zA-Z\\d]{10,}$',
        validityPeriod: 60
      } as securityManager.PasswordPolicy)

      expect(viewModel.state.minLengthIndex).assertEqual(2)
      expect(viewModel.state.requireLowercase).assertTrue()
      expect(viewModel.state.requireUppercase).assertTrue()
      expect(viewModel.state.requireDigit).assertTrue()
      expect(viewModel.state.requireSpecialChar).assertFalse()
      expect(viewModel.state.validityPeriodIndex).assertEqual(PASSWORD_VALIDITY_OPTIONS.indexOf(60))
      expect(viewModel.state.hasChanges).assertFalse()
    })

    it('should switch to custom validity state', 0, () => {
      let viewModel = new IdentitySettingsViewModel()
      viewModel.reset()
      viewModel.setValidityPeriodIndex(CUSTOM_VALIDITY_OPTION_INDEX)
      viewModel.setCustomValidityPeriodText('120days')

      expect(viewModel.isCustomValiditySelected).assertTrue()
      expect(viewModel.state.customValidityPeriodText).assertEqual('120')
      expect(viewModel.state.hasChanges).assertTrue()
    })

    it('should reject save when custom validity is invalid', 0, () => {
      let viewModel = new IdentitySettingsViewModel()
      viewModel.reset()
      viewModel.setValidityPeriodIndex(CUSTOM_VALIDITY_OPTION_INDEX)

      let result = viewModel.save()

      expect(result.success).assertFalse()
      expect(result.message).assertEqual(IdentityStrings.invalidValidityDays)
    })

    it('should reject save when nothing changed from current policy', 0, () => {
      let viewModel = new IdentitySettingsViewModel()
      viewModel.initialize({
        complexityRegex: 'mock-regex',
        validityPeriod: 30
      } as securityManager.PasswordPolicy)
      IdentityService.getPasswordPolicyWithResult = (): Object => {
        return {
          success: true,
          data: {
            complexityRegex: 'mock-regex',
            validityPeriod: 30
          }
        }
      }
      IdentityService.buildComplexityRegex = (_config: PasswordComplexityConfig): string => 'mock-regex'

      let result = viewModel.save()

      expect(result.success).assertFalse()
      expect(result.message).assertEqual(CommonStrings.messageNoChanges)
    })

    it('should clear dirty state after successful save', 0, () => {
      let viewModel = new IdentitySettingsViewModel()
      viewModel.reset()
      viewModel.setRequirement('requireSpecialChar', false)

      IdentityService.getPasswordPolicyWithResult = (): Object => {
        return {
          success: true,
          data: {
            complexityRegex: 'old-regex',
            validityPeriod: 0
          }
        }
      }
      IdentityService.buildComplexityRegex = (_config: PasswordComplexityConfig): string => 'new-regex'
      IdentityService.setPasswordPolicyWithResult = (_config: PasswordComplexityConfig): Object => {
        return { success: true }
      }

      let result = viewModel.save()

      expect(result.success).assertTrue()
      expect(result.message).assertEqual(IdentityStrings.saveSuccess)
      expect(viewModel.state.hasChanges).assertFalse()
    })

    it('should use admin-required message when save fails without admin', 0, () => {
      let viewModel = new IdentitySettingsViewModel()
      viewModel.reset()
      viewModel.setRequirement('requireSpecialChar', false)

      IdentityService.getPasswordPolicyWithResult = (): Object => {
        return {
          success: true,
          data: {
            complexityRegex: 'old-regex',
            validityPeriod: 0
          }
        }
      }
      IdentityService.buildComplexityRegex = (_config: PasswordComplexityConfig): string => 'new-regex'
      IdentityService.setPasswordPolicyWithResult = (_config: PasswordComplexityConfig): Object => {
        return {
          success: false,
          isAdminMissing: true,
          errorMessage: 'edm missing'
        }
      }
      DialogService.displayReason = (primaryMessage?: string, fallbackMessage?: string): string => {
        return `${primaryMessage}|${fallbackMessage}`
      }

      let result = viewModel.save()

      expect(result.success).assertFalse()
      expect(result.message).assertEqual(`edm missing|${IdentityStrings.adminRequired}`)
    })
  })
}
