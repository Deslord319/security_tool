import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { securityManager } from '@kit.MDMKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { AdminText, MessageText } from '../../main/ets/constants/StringCatalog'
import { IdentityActionStrings, IdentityMessageStrings } from '../../main/ets/constants/modules/IdentityStrings'
import {
  AdminActivationState,
  OperationResult
} from '../../main/ets/models/CommonModels'
import { PasswordComplexityConfig } from '../../main/ets/models/IdentityModels'
import { EnterpriseAdminService } from '../../main/ets/services/admin/activation/EnterpriseAdminService'
import { IdentityService } from '../../main/ets/services/identity/settings/IdentityService'
import {
  CUSTOM_VALIDITY_OPTION_INDEX,
  HALF_YEAR_VALIDITY_OPTION_INDEX,
  IdentitySettingsActionRequest,
  IdentitySettingsViewModel,
  PERMANENT_VALIDITY_OPTION_INDEX,
  ONE_YEAR_VALIDITY_OPTION_INDEX
} from '../../main/ets/viewmodels/identity/settings/IdentitySettingsViewModel'
import { DialogService } from '../../main/ets/utils/DialogService'

const DAY_IN_MS: number = 24 * 60 * 60 * 1000

class MockAdminState implements AdminActivationState {
  activated: boolean = false
  errorCode?: number
  errorMessage?: string
  enableCommand: string = 'edm enable-admin'
  adminType: 'super' | 'byod' = 'byod'
}

class MockPasswordPolicyResult implements OperationResult<securityManager.PasswordPolicy | null> {
  success: boolean = true
  data?: securityManager.PasswordPolicy | null = null
  errorCode?: number
  errorMessage?: string
  userMessage?: string
  isAdminMissing?: boolean
  stage?: string
  suggestion?: string
}

class MockSaveResult implements OperationResult<void> {
  success: boolean = false
  data?: void
  errorCode?: number
  errorMessage?: string
  userMessage?: string
  isAdminMissing?: boolean
  stage?: string
  suggestion?: string
}

function createActivatedAdminState(): AdminActivationState {
  let state = new MockAdminState()
  state.activated = true
  return state
}

function createInactiveAdminState(message: string = AdminText.NOT_ACTIVATED): AdminActivationState {
  let state = new MockAdminState()
  state.activated = false
  state.errorMessage = message
  return state
}

function createPolicy(regex: string, validityPeriod?: number): securityManager.PasswordPolicy {
  let policy: securityManager.PasswordPolicy = {
    complexityRegex: regex
  }
  if (typeof validityPeriod === 'number') {
    policy.validityPeriod = validityPeriod
  }
  return policy
}

function createPolicyResult(policy: securityManager.PasswordPolicy | null): OperationResult<securityManager.PasswordPolicy | null> {
  let result = new MockPasswordPolicyResult()
  result.success = true
  result.data = policy
  return result
}

function createFailedPolicyResult(errorMessage: string = 'get failed'): OperationResult<securityManager.PasswordPolicy | null> {
  let result = new MockPasswordPolicyResult()
  result.success = false
  result.errorMessage = errorMessage
  return result
}

function createSaveResult(success: boolean, isAdminMissing?: boolean, errorMessage?: string): OperationResult<void> {
  let result = new MockSaveResult()
  result.success = success
  result.isAdminMissing = isAdminMissing
  result.errorMessage = errorMessage
  return result
}

function expectResultFailure(result: IdentitySettingsActionRequest, expectedMessage: string): void {
  expect(result.kind).assertEqual('result')
  expect(result.status).assertEqual('failure')
  expect(result.message).assertEqual(expectedMessage)
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

    it('should initialize from current system policy when admin is active', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      let policy = createPolicy('^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d).{10,}$', 365 * DAY_IN_MS)
      when(adminMock)().afterReturn(createActivatedAdminState())
      when(getPolicyMock)().afterReturn(createPolicyResult(policy))

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.initialize()

      expect(viewModel.state.initialized).assertTrue()
      expect(viewModel.state.loading).assertFalse()
      expect(viewModel.state.adminActivated).assertTrue()
      expect(viewModel.state.minLengthIndex).assertEqual(2)
      expect(viewModel.state.requireLowercase).assertTrue()
      expect(viewModel.state.requireUppercase).assertTrue()
      expect(viewModel.state.requireDigit).assertTrue()
      expect(viewModel.state.requireSpecialChar).assertFalse()
      expect(viewModel.state.validityPeriodIndex).assertEqual(ONE_YEAR_VALIDITY_OPTION_INDEX)
      expect(viewModel.state.hasChanges).assertFalse()
      expect(viewModel.state.canSave).assertFalse()
    })

    it('should reset to defaults and expose admin message when admin is inactive', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      when(adminMock)().afterReturn(createInactiveAdminState('please activate admin'))

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.initialize()

      expect(viewModel.state.initialized).assertTrue()
      expect(viewModel.state.adminActivated).assertFalse()
      expect(viewModel.state.adminMessage).assertEqual('please activate admin')
      expect(viewModel.state.minLengthIndex).assertEqual(0)
      expect(viewModel.state.validityPeriodIndex).assertEqual(PERMANENT_VALIDITY_OPTION_INDEX)
      expect(viewModel.state.hasChanges).assertFalse()
      expect(viewModel.state.canSave).assertFalse()
    })

    it('should reset to defaults when getPasswordPolicy fails', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      when(adminMock)().afterReturn(createActivatedAdminState())
      when(getPolicyMock)().afterReturn(createFailedPolicyResult('policy read error'))

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.initialize()

      expect(viewModel.state.initialized).assertTrue()
      expect(viewModel.state.loading).assertFalse()
      expect(viewModel.state.adminActivated).assertTrue()
      expect(viewModel.state.minLengthIndex).assertEqual(0)
      expect(viewModel.state.validityPeriodIndex).assertEqual(PERMANENT_VALIDITY_OPTION_INDEX)
      expect(viewModel.state.hasChanges).assertFalse()
      expect(viewModel.state.canSave).assertFalse()
    })

    it('should reload policy when admin becomes active on route activation', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      when(adminMock)().afterReturn(createInactiveAdminState())

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.activate()
      viewModel.setValidityPeriodIndex(CUSTOM_VALIDITY_OPTION_INDEX)
      viewModel.setCustomValidityPeriodText('30')

      mockKit.clearAll()
      mockKit = new MockKit()
      adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      let policy = createPolicy('^(?=.*\\d).{10,}$', 90 * DAY_IN_MS)
      when(adminMock)().afterReturn(createActivatedAdminState())
      when(getPolicyMock)().afterReturn(createPolicyResult(policy))

      await viewModel.activate()

      expect(viewModel.state.adminActivated).assertTrue()
      expect(viewModel.state.minLengthIndex).assertEqual(2)
      expect(viewModel.state.requireDigit).assertTrue()
      expect(viewModel.state.validityPeriodIndex).assertEqual(CUSTOM_VALIDITY_OPTION_INDEX)
      expect(viewModel.state.customValidityPeriodText).assertEqual('90')
      expect(viewModel.state.hasChanges).assertFalse()
      expect(viewModel.state.canSave).assertFalse()
    })

    it('should preserve unsaved edits when admin state remains active on route activation', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      when(adminMock)().afterReturn(createActivatedAdminState())
      when(getPolicyMock)().afterReturn(createPolicyResult(null))

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.activate()
      viewModel.setValidityPeriodIndex(CUSTOM_VALIDITY_OPTION_INDEX)
      viewModel.setCustomValidityPeriodText('120')

      await viewModel.activate()

      expect(viewModel.state.adminActivated).assertTrue()
      expect(viewModel.state.validityPeriodIndex).assertEqual(CUSTOM_VALIDITY_OPTION_INDEX)
      expect(viewModel.state.customValidityPeriodText).assertEqual('120')
      expect(viewModel.state.hasChanges).assertTrue()
      expect(viewModel.state.canSave).assertTrue()
    })

    it('should reset inactive edits when policy reload fails after admin activation', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      when(adminMock)().afterReturn(createInactiveAdminState())

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.activate()
      viewModel.setRequirement('requireDigit', true)

      mockKit.clearAll()
      mockKit = new MockKit()
      adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      when(adminMock)().afterReturn(createActivatedAdminState())
      when(getPolicyMock)().afterReturn(createFailedPolicyResult('policy read error'))

      await viewModel.activate()

      expect(viewModel.state.adminActivated).assertTrue()
      expect(viewModel.state.requireDigit).assertFalse()
      expect(viewModel.state.hasChanges).assertFalse()
      expect(viewModel.state.canSave).assertFalse()
    })

    it('should preserve edits and disable save when admin becomes inactive on route activation', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      when(adminMock)().afterReturn(createActivatedAdminState())
      when(getPolicyMock)().afterReturn(createPolicyResult(null))

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.activate()
      viewModel.setRequirement('requireDigit', true)

      mockKit.clearAll()
      mockKit = new MockKit()
      adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      when(adminMock)().afterReturn(createInactiveAdminState())

      await viewModel.activate()

      expect(viewModel.state.adminActivated).assertFalse()
      expect(viewModel.state.requireDigit).assertTrue()
      expect(viewModel.state.hasChanges).assertTrue()
      expect(viewModel.state.canSave).assertFalse()
    })

    it('should sanitize custom validity input and update derived state', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      when(adminMock)().afterReturn(createActivatedAdminState())
      when(getPolicyMock)().afterReturn(createPolicyResult(null))

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.initialize()
      viewModel.setValidityPeriodIndex(CUSTOM_VALIDITY_OPTION_INDEX)
      viewModel.setCustomValidityPeriodText('120days')

      expect(viewModel.isCustomValiditySelected).assertTrue()
      expect(viewModel.state.customValidityPeriodText).assertEqual('120')
      expect(viewModel.state.hasChanges).assertTrue()
      expect(viewModel.state.canSave).assertTrue()
    })

    it('should reject save when custom validity is invalid', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      when(adminMock)().afterReturn(createActivatedAdminState())

      let viewModel = new IdentitySettingsViewModel()
      viewModel.reset()
      viewModel.setValidityPeriodIndex(CUSTOM_VALIDITY_OPTION_INDEX)

      let result = viewModel.requestSave()

      expectResultFailure(result, IdentityMessageStrings.INVALID_VALIDITY_DAYS)
      expect(viewModel.state.canSave).assertTrue()
    })

    it('should return confirm request when custom validity is zero days', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      when(adminMock)().afterReturn(createActivatedAdminState())

      let viewModel = new IdentitySettingsViewModel()
      viewModel.reset()
      viewModel.setValidityPeriodIndex(CUSTOM_VALIDITY_OPTION_INDEX)
      viewModel.setCustomValidityPeriodText('0')

      let result = viewModel.requestSave()

      expect(result.kind).assertEqual('confirm')
      expect(result.title).assertEqual(IdentityMessageStrings.IMMEDIATE_EXPIRY_RISK_TITLE)
      expect(result.message).assertEqual(IdentityMessageStrings.IMMEDIATE_EXPIRY_RISK_MESSAGE)
    })

    it('should reject save when nothing changed from current policy', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      let currentPolicy = createPolicy('^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[!@#$%^&*])[a-zA-Z\\d!@#$%^&*]{8,}$', 30 * DAY_IN_MS)
      when(adminMock)().afterReturn(createActivatedAdminState())
      when(getPolicyMock)().afterReturn(createPolicyResult(currentPolicy))

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.initialize()

      let result = viewModel.requestSave()

      expectResultFailure(result, MessageText.NO_CHANGES)
    })

    it('should save changed config and clear dirty state', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      let setPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.setPasswordPolicyWithResult)
      let currentPolicy = createPolicy('^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[!@#$%^&*])[a-zA-Z\\d!@#$%^&*]{8,}$', 30 * DAY_IN_MS)
      when(adminMock)().afterReturn(createActivatedAdminState())
      when(getPolicyMock)().afterReturn(createPolicyResult(currentPolicy))
      when(setPolicyMock)(ArgumentMatchers.anyObj as PasswordComplexityConfig).afterReturn(createSaveResult(true))

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.initialize()
      viewModel.setRequirement('requireSpecialChar', false)

      let result = viewModel.requestSave()

      expect(result.kind).assertEqual('result')
      expect(result.status).assertEqual('success')
      expect(result.message).assertEqual(IdentityMessageStrings.SAVE_SUCCESS)
      expect(viewModel.state.hasChanges).assertFalse()
      expect(viewModel.state.canSave).assertFalse()
    })

    it('should surface admin-missing save failures from service layer', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      let setPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.setPasswordPolicyWithResult)
      let currentPolicy = createPolicy('^(?=.*[a-z]).{6,}$', 30 * DAY_IN_MS)
      when(adminMock)().afterReturn(createActivatedAdminState())
      when(getPolicyMock)().afterReturn(createPolicyResult(currentPolicy))
      when(setPolicyMock)(ArgumentMatchers.anyObj as PasswordComplexityConfig).afterReturn(createSaveResult(false, true, 'edm missing'))

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.initialize()
      viewModel.setRequirement('requireSpecialChar', true)

      let result = viewModel.requestSave()

      expectResultFailure(result, DialogService.displayReason('edm missing', AdminText.NOT_ACTIVATED))
    })

    it('should surface retry message for non-admin save failures', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      let setPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.setPasswordPolicyWithResult)
      let currentPolicy = createPolicy('^(?=.*\\d).{10,}$', 30 * DAY_IN_MS)
      when(adminMock)().afterReturn(createActivatedAdminState())
      when(getPolicyMock)().afterReturn(createPolicyResult(currentPolicy))
      when(setPolicyMock)(ArgumentMatchers.anyObj as PasswordComplexityConfig).afterReturn(createSaveResult(false, false, 'io failed'))

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.initialize()
      viewModel.setRequirement('requireSpecialChar', true)

      let result = viewModel.requestSave()

      expectResultFailure(
        result,
        DialogService.displayReason('io failed', `${IdentityActionStrings.PASSWORD_POLICY}${IdentityMessageStrings.ACTION_RETRY_SUFFIX}`)
      )
    })

    it('should return failure immediately when admin is inactive during save', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      when(adminMock)().afterReturn(createInactiveAdminState('admin inactive'))

      let viewModel = new IdentitySettingsViewModel()
      viewModel.reset()
      viewModel.setRequirement('requireDigit', true)

      let result = viewModel.requestSave()

      expectResultFailure(result, 'admin inactive')
    })

    it('should use default admin required message when admin has no error message', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let inactiveState = createInactiveAdminState('')
      when(adminMock)().afterReturn(inactiveState)

      let viewModel = new IdentitySettingsViewModel()
      viewModel.reset()
      viewModel.setRequirement('requireDigit', true)

      let result = viewModel.requestSave()

      expectResultFailure(result, `${IdentityActionStrings.SAVE}${IdentityMessageStrings.ADMIN_REQUIRED_WITH_ACTION_SUFFIX}`)
    })

    it('should map half-year validity period to half-year option', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      let policy = createPolicy('^.{6,}$', 183 * DAY_IN_MS)
      when(adminMock)().afterReturn(createActivatedAdminState())
      when(getPolicyMock)().afterReturn(createPolicyResult(policy))

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.initialize()

      expect(viewModel.state.validityPeriodIndex).assertEqual(HALF_YEAR_VALIDITY_OPTION_INDEX)
      expect(viewModel.state.customValidityPeriodText).assertEqual('')
    })

    it('should map one-year validity period to one-year option', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      let policy = createPolicy('^.{6,}$', 366 * DAY_IN_MS)
      when(adminMock)().afterReturn(createActivatedAdminState())
      when(getPolicyMock)().afterReturn(createPolicyResult(policy))

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.initialize()

      expect(viewModel.state.validityPeriodIndex).assertEqual(ONE_YEAR_VALIDITY_OPTION_INDEX)
      expect(viewModel.state.customValidityPeriodText).assertEqual('')
    })

    it('should map custom validity period to custom option', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      let policy = createPolicy('^.{6,}$', 90 * DAY_IN_MS)
      when(adminMock)().afterReturn(createActivatedAdminState())
      when(getPolicyMock)().afterReturn(createPolicyResult(policy))

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.initialize()

      expect(viewModel.state.validityPeriodIndex).assertEqual(CUSTOM_VALIDITY_OPTION_INDEX)
      expect(viewModel.state.customValidityPeriodText).assertEqual('90')
    })

    it('should keep zero validity as custom immediate expiry value', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      let policy = createPolicy('^.{6,}$', 0)
      when(adminMock)().afterReturn(createActivatedAdminState())
      when(getPolicyMock)().afterReturn(createPolicyResult(policy))

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.initialize()

      expect(viewModel.state.validityPeriodIndex).assertEqual(CUSTOM_VALIDITY_OPTION_INDEX)
      expect(viewModel.state.customValidityPeriodText).assertEqual('0')
    })

    it('should map empty zero-validity system policy to default permanent option', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      let policy = createPolicy('', 0)
      when(adminMock)().afterReturn(createActivatedAdminState())
      when(getPolicyMock)().afterReturn(createPolicyResult(policy))

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.initialize()

      expect(viewModel.state.validityPeriodIndex).assertEqual(PERMANENT_VALIDITY_OPTION_INDEX)
      expect(viewModel.state.customValidityPeriodText).assertEqual('')
    })

    it('should map legacy hundred-year validity period to permanent option', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      let policy = createPolicy('^.{6,}$', 36525 * DAY_IN_MS)
      when(adminMock)().afterReturn(createActivatedAdminState())
      when(getPolicyMock)().afterReturn(createPolicyResult(policy))

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.initialize()

      expect(viewModel.state.validityPeriodIndex).assertEqual(PERMANENT_VALIDITY_OPTION_INDEX)
      expect(viewModel.state.customValidityPeriodText).assertEqual('')
    })

    it('should default validity option when policy has no validity period', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      let policy = createPolicy('^.{6,}$')
      when(adminMock)().afterReturn(createActivatedAdminState())
      when(getPolicyMock)().afterReturn(createPolicyResult(policy))

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.initialize()

      expect(viewModel.state.validityPeriodIndex).assertEqual(PERMANENT_VALIDITY_OPTION_INDEX)
      expect(viewModel.state.customValidityPeriodText).assertEqual('')
    })

    it('should clear custom text when switching away from custom validity', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      when(adminMock)().afterReturn(createActivatedAdminState())
      when(getPolicyMock)().afterReturn(createPolicyResult(null))

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.initialize()
      viewModel.setValidityPeriodIndex(CUSTOM_VALIDITY_OPTION_INDEX)
      viewModel.setCustomValidityPeriodText('90')
      viewModel.setValidityPeriodIndex(HALF_YEAR_VALIDITY_OPTION_INDEX)

      expect(viewModel.state.validityPeriodIndex).assertEqual(HALF_YEAR_VALIDITY_OPTION_INDEX)
      expect(viewModel.state.customValidityPeriodText).assertEqual('')
    })

    it('should skip confirm when skipImmediateExpiryConfirm is true and validity is zero', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      let setPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.setPasswordPolicyWithResult)
      when(adminMock)().afterReturn(createActivatedAdminState())
      when(getPolicyMock)().afterReturn(createPolicyResult(null))
      when(setPolicyMock)(ArgumentMatchers.anyObj as PasswordComplexityConfig).afterReturn(createSaveResult(true))

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.initialize()
      viewModel.setValidityPeriodIndex(CUSTOM_VALIDITY_OPTION_INDEX)
      viewModel.setCustomValidityPeriodText('0')

      let result = viewModel.requestSave(true)

      expect(result.kind).assertEqual('result')
    })

    it('should reject save when current policy is null and config differs', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      let setPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.setPasswordPolicyWithResult)
      when(adminMock)().afterReturn(createActivatedAdminState())
      when(getPolicyMock)().afterReturn(createPolicyResult(null))
      when(setPolicyMock)(ArgumentMatchers.anyObj as PasswordComplexityConfig).afterReturn(createSaveResult(true))

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.initialize()
      viewModel.setRequirement('requireDigit', true)

      let result = viewModel.requestSave()

      expect(result.kind).assertEqual('result')
      expect(result.status).assertEqual('success')
    })

    it('should keep canSave true when custom validity is empty', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      when(adminMock)().afterReturn(createActivatedAdminState())
      when(getPolicyMock)().afterReturn(createPolicyResult(null))

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.initialize()
      viewModel.setValidityPeriodIndex(CUSTOM_VALIDITY_OPTION_INDEX)

      expect(viewModel.state.hasChanges).assertTrue()
      expect(viewModel.state.canSave).assertTrue()
    })

    it('should set minLengthIndex to default when policy minLength not in options', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      let policy = createPolicy('^.{99,}$', 365 * DAY_IN_MS)
      when(adminMock)().afterReturn(createActivatedAdminState())
      when(getPolicyMock)().afterReturn(createPolicyResult(policy))

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.initialize()

      expect(viewModel.state.minLengthIndex).assertEqual(0)
    })

    it('should map policy minLength 20 to the new option index', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      let policy = createPolicy('^.{20,}$', 365 * DAY_IN_MS)
      when(adminMock)().afterReturn(createActivatedAdminState())
      when(getPolicyMock)().afterReturn(createPolicyResult(policy))

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.initialize()

      expect(viewModel.state.minLengthIndex).assertEqual(5)
    })

    it('should update minLengthIndex when setMinLengthIndex is called', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      when(adminMock)().afterReturn(createActivatedAdminState())
      when(getPolicyMock)().afterReturn(createPolicyResult(null))

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.initialize()
      viewModel.setMinLengthIndex(3)

      expect(viewModel.state.minLengthIndex).assertEqual(3)
      expect(viewModel.state.hasChanges).assertTrue()
    })

    it('should ignore invalid minLengthIndex', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      when(adminMock)().afterReturn(createActivatedAdminState())
      when(getPolicyMock)().afterReturn(createPolicyResult(null))

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.initialize()
      viewModel.setMinLengthIndex(-1)

      expect(viewModel.state.minLengthIndex).assertEqual(0)
      expect(viewModel.state.hasChanges).assertFalse()
    })

    it('should set requireUppercase via setRequirement', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      when(adminMock)().afterReturn(createActivatedAdminState())
      when(getPolicyMock)().afterReturn(createPolicyResult(null))

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.initialize()
      viewModel.setRequirement('requireUppercase', true)

      expect(viewModel.state.requireUppercase).assertTrue()
      expect(viewModel.state.hasChanges).assertTrue()
    })

    it('should set requireLowercase via setRequirement', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      when(adminMock)().afterReturn(createActivatedAdminState())
      when(getPolicyMock)().afterReturn(createPolicyResult(null))

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.initialize()
      viewModel.setRequirement('requireLowercase', true)

      expect(viewModel.state.requireLowercase).assertTrue()
      expect(viewModel.state.hasChanges).assertTrue()
    })

    it('should resolve one-year validity period correctly', 0, async () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let getPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.getPasswordPolicyWithResult)
      let setPolicyMock = mockKit.mockFunc(IdentityService, IdentityService.setPasswordPolicyWithResult)
      when(adminMock)().afterReturn(createActivatedAdminState())
      when(getPolicyMock)().afterReturn(createPolicyResult(null))
      when(setPolicyMock)(ArgumentMatchers.anyObj as PasswordComplexityConfig).afterReturn(createSaveResult(true))

      let viewModel = new IdentitySettingsViewModel()
      await viewModel.initialize()
      viewModel.setValidityPeriodIndex(ONE_YEAR_VALIDITY_OPTION_INDEX)

      let result = viewModel.requestSave()

      expect(result.kind).assertEqual('result')
      expect(result.status).assertEqual('success')
    })
  })
}
