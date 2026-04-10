import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { securityManager } from '@kit.MDMKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { AdminText, MessageText } from '../../main/ets/constants/StringCatalog'
import { IdentityActionStrings, IdentityMessageStrings } from '../../main/ets/constants/modules/IdentityStrings'
import { OperationResult, PASSWORD_VALIDITY_OPTIONS } from '../../main/ets/models/DataModels'
import { IdentityService } from '../../main/ets/services/identity/settings/IdentityService'
import {
  CUSTOM_VALIDITY_OPTION_INDEX,
  IdentitySettingsViewModel
} from '../../main/ets/viewmodels/identity/settings/IdentitySettingsViewModel'
import { DialogService } from '../../main/ets/utils/DialogService'

interface MockPasswordPolicyResult extends OperationResult<securityManager.PasswordPolicy | null> {
  data?: securityManager.PasswordPolicy | null
}

class PasswordPolicyResult implements MockPasswordPolicyResult {
  success: boolean = true
  data?: securityManager.PasswordPolicy | null = null
}

class SavePasswordPolicyResult implements OperationResult<void> {
  success: boolean = false
  isAdminMissing?: boolean
  errorMessage?: string
}

export default function identitySettingsViewModelTest() {
  describe('IdentitySettingsViewModel', () => {
    let mockKit: MockKit

    beforeEach(() => {
      mockKit = new MockKit()
    })

    afterEach(() => {
      mockKit.clearAll()
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

    it('should reset to default editable values when no system policy is available', 0, () => {
      let viewModel = new IdentitySettingsViewModel()
      viewModel.initialize(null)

      expect(viewModel.state.minLengthIndex).assertEqual(1)
      expect(viewModel.state.requireUppercase).assertTrue()
      expect(viewModel.state.requireLowercase).assertTrue()
      expect(viewModel.state.requireDigit).assertTrue()
      expect(viewModel.state.requireSpecialChar).assertTrue()
      expect(viewModel.state.validityPeriodIndex).assertEqual(0)
      expect(viewModel.state.customValidityPeriodText).assertEqual('')
      expect(viewModel.state.hasChanges).assertFalse()
    })

    it('should reject save when custom validity is invalid', 0, () => {
      let viewModel = new IdentitySettingsViewModel()
      viewModel.reset()
      viewModel.setValidityPeriodIndex(CUSTOM_VALIDITY_OPTION_INDEX)

      let result = viewModel.save()

      expect(result.success).assertFalse()
      expect(result.message).assertEqual(IdentityMessageStrings.INVALID_VALIDITY_DAYS)
    })

    it('should reject save when nothing changed from current policy', 0, () => {
      let viewModel = new IdentitySettingsViewModel()
      const currentRegex = '^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[!@#$%^&*])[a-zA-Z\\d!@#$%^&*]{8,}$'
      viewModel.initialize({
        complexityRegex: currentRegex,
        validityPeriod: 30
      } as securityManager.PasswordPolicy)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      let policyResult = new PasswordPolicyResult()
      policyResult.success = true
      policyResult.data = { complexityRegex: currentRegex, validityPeriod: 30 } as securityManager.PasswordPolicy
      when(getPolicyMock)().afterReturn(policyResult)

      let result = viewModel.save()

      expect(result.success).assertFalse()
      expect(result.message).assertEqual(MessageText.NO_CHANGES)
    })

    it('should clear dirty state after successful save', 0, () => {
      let viewModel = new IdentitySettingsViewModel()
      viewModel.reset()
      viewModel.setRequirement('requireSpecialChar', false)

      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      let setPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.setPasswordPolicyWithResult)
      let policyResult = new PasswordPolicyResult()
      policyResult.success = true
      policyResult.data = { complexityRegex: 'old-regex', validityPeriod: 0 } as securityManager.PasswordPolicy
      when(getPolicyMock)().afterReturn(policyResult)
      let saveResult = new SavePasswordPolicyResult()
      saveResult.success = true
      when(setPolicyMock)(ArgumentMatchers.anyObj).afterReturn(saveResult)

      let result = viewModel.save()

      expect(result.success).assertTrue()
      expect(result.message).assertEqual(IdentityMessageStrings.SAVE_SUCCESS)
      expect(viewModel.state.hasChanges).assertFalse()
    })

    it('should use admin-required message when save fails without admin', 0, () => {
      let viewModel = new IdentitySettingsViewModel()
      viewModel.reset()
      viewModel.setRequirement('requireSpecialChar', false)

      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      let setPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.setPasswordPolicyWithResult)
      let policyResult = new PasswordPolicyResult()
      policyResult.success = true
      policyResult.data = { complexityRegex: 'old-regex', validityPeriod: 0 } as securityManager.PasswordPolicy
      when(getPolicyMock)().afterReturn(policyResult)
      let saveResult = new SavePasswordPolicyResult()
      saveResult.success = false
      saveResult.isAdminMissing = true
      saveResult.errorMessage = 'edm missing'
      when(setPolicyMock)(ArgumentMatchers.anyObj).afterReturn(saveResult)

      let result = viewModel.save()

      expect(result.success).assertFalse()
      expect(result.message).assertEqual(DialogService.displayReason('edm missing', AdminText.NOT_ACTIVATED))
    })

    it('should use retry message when save fails for non-admin reasons', 0, () => {
      let viewModel = new IdentitySettingsViewModel()
      viewModel.reset()
      viewModel.setRequirement('requireSpecialChar', false)

      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      let setPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.setPasswordPolicyWithResult)
      let policyResult = new PasswordPolicyResult()
      policyResult.success = true
      policyResult.data = { complexityRegex: 'old-regex', validityPeriod: 0 } as securityManager.PasswordPolicy
      when(getPolicyMock)().afterReturn(policyResult)
      let saveResult = new SavePasswordPolicyResult()
      saveResult.success = false
      saveResult.isAdminMissing = false
      saveResult.errorMessage = 'io failed'
      when(setPolicyMock)(ArgumentMatchers.anyObj).afterReturn(saveResult)

      let result = viewModel.save()

      expect(result.success).assertFalse()
      expect(result.message).assertEqual(
        DialogService.displayReason('io failed', `${IdentityActionStrings.PASSWORD_POLICY}${IdentityMessageStrings.ACTION_RETRY_SUFFIX}`)
      )
    })
  })
}
