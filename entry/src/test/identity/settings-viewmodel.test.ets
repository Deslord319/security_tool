import { describe, it, expect } from '@ohos/hypium'
import { PASSWORD_VALIDITY_OPTIONS } from '../../main/ets/models/DataModels'
import {
  CUSTOM_VALIDITY_OPTION_INDEX,
  IdentitySettingsViewModel
} from '../../main/ets/viewmodels/IdentitySettingsViewModel'

export default function identitySettingsViewModelTest() {
  describe('IdentitySettingsViewModel', () => {
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
      viewModel.setCustomValidityPeriodText('120天')

      expect(viewModel.isCustomValiditySelected).assertTrue()
      expect(viewModel.state.customValidityPeriodText).assertEqual('120')
      expect(viewModel.state.hasChanges).assertTrue()
    })
  })
}
