import { securityManager } from '@kit.MDMKit'
import { CommonStrings } from '../constants/CommonStrings'
import { IdentityStrings } from '../constants/modules/IdentityStrings'
import {
  PASSWORD_LENGTH_OPTIONS,
  PASSWORD_VALIDITY_OPTIONS,
  PasswordComplexityConfig
} from '../models/DataModels'
import { IdentityService } from '../services/IdentityService'
import { ResultDialogHelper } from '../utils/ResultDialogHelper'

export const CUSTOM_VALIDITY_OPTION_INDEX: number = PASSWORD_VALIDITY_OPTIONS.length

export interface IdentitySettingsState {
  minLengthIndex: number
  requireUppercase: boolean
  requireLowercase: boolean
  requireDigit: boolean
  requireSpecialChar: boolean
  validityPeriodIndex: number
  customValidityPeriodText: string
  hasChanges: boolean
}

export interface IdentitySettingsSaveResult {
  success: boolean
  message: string
}

export class IdentitySettingsViewModel {
  state: IdentitySettingsState = IdentitySettingsViewModel.buildDefaultState()
  private initialState: IdentitySettingsState = IdentitySettingsViewModel.buildDefaultState()

  initialize(policy?: securityManager.PasswordPolicy | null): void {
    let nextState = IdentitySettingsViewModel.buildDefaultState()
    if (policy?.complexityRegex) {
      nextState = this.applyRegex(nextState, policy.complexityRegex)
    }
    nextState = this.applyValidityPeriod(nextState, policy?.validityPeriod)
    this.initialState = IdentitySettingsViewModel.snapshot(nextState)
    this.state = IdentitySettingsViewModel.withHasChanges(nextState, false)
  }

  reset(): void {
    this.initialize(null)
  }

  get isCustomValiditySelected(): boolean {
    return this.state.validityPeriodIndex === CUSTOM_VALIDITY_OPTION_INDEX
  }

  setMinLengthIndex(index: number): void {
    let nextState = IdentitySettingsViewModel.snapshot(this.state)
    if (index >= 0 && index < PASSWORD_LENGTH_OPTIONS.length) {
      nextState.minLengthIndex = index
    }
    this.updateState(nextState)
  }

  setRequireUppercase(value: boolean): void {
    let nextState = IdentitySettingsViewModel.snapshot(this.state)
    nextState.requireUppercase = value
    this.updateState(nextState)
  }

  setRequireLowercase(value: boolean): void {
    let nextState = IdentitySettingsViewModel.snapshot(this.state)
    nextState.requireLowercase = value
    this.updateState(nextState)
  }

  setRequireDigit(value: boolean): void {
    let nextState = IdentitySettingsViewModel.snapshot(this.state)
    nextState.requireDigit = value
    this.updateState(nextState)
  }

  setRequireSpecialChar(value: boolean): void {
    let nextState = IdentitySettingsViewModel.snapshot(this.state)
    nextState.requireSpecialChar = value
    this.updateState(nextState)
  }

  setValidityPeriodIndex(index: number): void {
    let nextState = IdentitySettingsViewModel.snapshot(this.state)
    if (index >= 0 && index <= CUSTOM_VALIDITY_OPTION_INDEX) {
      nextState.validityPeriodIndex = index
    }
    if (nextState.validityPeriodIndex !== CUSTOM_VALIDITY_OPTION_INDEX) {
      nextState.customValidityPeriodText = ''
    }
    this.updateState(nextState)
  }

  setCustomValidityPeriodText(value: string): void {
    let nextState = IdentitySettingsViewModel.snapshot(this.state)
    nextState.customValidityPeriodText = value.replace(/[^0-9]/g, '')
    this.updateState(nextState)
  }

  save(): IdentitySettingsSaveResult {
    let config = this.buildConfig()
    if (!config) {
      return { success: false, message: IdentityStrings.invalidValidityDays }
    }

    let currentPolicy = IdentityService.getPasswordPolicyWithResult().data
    let currentRegex: string = currentPolicy?.complexityRegex ?? ''
    let nextRegex: string = IdentityService.buildComplexityRegex(config)
    let currentValidity: number = currentPolicy?.validityPeriod ?? 0
    if (currentRegex === nextRegex && currentValidity === config.validityPeriod) {
      return { success: false, message: CommonStrings.messageNoChanges }
    }

    let result = IdentityService.setPasswordPolicyWithResult(config)
    if (!result.success) {
      let message = result.isAdminMissing
        ? ResultDialogHelper.displayReason(result.errorMessage, IdentityStrings.adminRequired)
        : ResultDialogHelper.displayReason(result.errorMessage, `${IdentityStrings.passwordPolicyAction}${IdentityStrings.actionRetrySuffix}`)
      return { success: false, message }
    }

    this.initialState = IdentitySettingsViewModel.snapshot(this.state)
    this.state = IdentitySettingsViewModel.withHasChanges(this.state, false)
    return { success: true, message: IdentityStrings.saveSuccess }
  }

  private buildConfig(): PasswordComplexityConfig | null {
    let validityPeriod = this.resolveValidityPeriod()
    if (validityPeriod === null) {
      return null
    }

    return {
      minLength: PASSWORD_LENGTH_OPTIONS[this.state.minLengthIndex],
      requireUppercase: this.state.requireUppercase,
      requireLowercase: this.state.requireLowercase,
      requireDigit: this.state.requireDigit,
      requireSpecialChar: this.state.requireSpecialChar,
      validityPeriod
    }
  }

  private resolveValidityPeriod(): number | null {
    if (!this.isCustomValiditySelected) {
      return PASSWORD_VALIDITY_OPTIONS[this.state.validityPeriodIndex]
    }

    let normalizedText = this.state.customValidityPeriodText.trim()
    if (normalizedText.length === 0 || !/^\d+$/.test(normalizedText)) {
      return null
    }
    return parseInt(normalizedText)
  }

  private applyRegex(state: IdentitySettingsState, regex: string): IdentitySettingsState {
    let nextState = IdentitySettingsViewModel.snapshot(state)
    nextState.requireLowercase = regex.indexOf('(?=.*[a-z])') >= 0
    nextState.requireUppercase = regex.indexOf('(?=.*[A-Z])') >= 0
    nextState.requireDigit = regex.indexOf('(?=.*\\d)') >= 0
    nextState.requireSpecialChar = regex.indexOf('(?=.*[!@#$%^&*])') >= 0

    let lenMatch = regex.match(/\{(\d+),\}\$/)
    if (!lenMatch || !lenMatch[1]) {
      return nextState
    }

    let length = parseInt(lenMatch[1])
    let index = PASSWORD_LENGTH_OPTIONS.indexOf(length)
    if (index >= 0) {
      nextState.minLengthIndex = index
    }
    return nextState
  }

  private applyValidityPeriod(state: IdentitySettingsState, validityPeriod: number | undefined): IdentitySettingsState {
    let nextState = IdentitySettingsViewModel.snapshot(state)
    let normalized = typeof validityPeriod === 'number' && validityPeriod >= 0 ? validityPeriod : 0
    let index = PASSWORD_VALIDITY_OPTIONS.indexOf(normalized)
    if (index >= 0) {
      nextState.validityPeriodIndex = index
      nextState.customValidityPeriodText = ''
      return nextState
    }

    nextState.validityPeriodIndex = CUSTOM_VALIDITY_OPTION_INDEX
    nextState.customValidityPeriodText = `${normalized}`
    return nextState
  }

  private updateState(nextState: IdentitySettingsState): void {
    this.state = IdentitySettingsViewModel.withHasChanges(
      nextState,
      !IdentitySettingsViewModel.areStatesEqual(this.initialState, nextState)
    )
  }

  private static buildDefaultState(): IdentitySettingsState {
    return {
      minLengthIndex: 1,
      requireUppercase: true,
      requireLowercase: true,
      requireDigit: true,
      requireSpecialChar: true,
      validityPeriodIndex: 0,
      customValidityPeriodText: '',
      hasChanges: false
    }
  }

  private static snapshot(state: IdentitySettingsState): IdentitySettingsState {
    return {
      minLengthIndex: state.minLengthIndex,
      requireUppercase: state.requireUppercase,
      requireLowercase: state.requireLowercase,
      requireDigit: state.requireDigit,
      requireSpecialChar: state.requireSpecialChar,
      validityPeriodIndex: state.validityPeriodIndex,
      customValidityPeriodText: state.customValidityPeriodText,
      hasChanges: state.hasChanges
    }
  }

  private static withHasChanges(state: IdentitySettingsState, hasChanges: boolean): IdentitySettingsState {
    return {
      minLengthIndex: state.minLengthIndex,
      requireUppercase: state.requireUppercase,
      requireLowercase: state.requireLowercase,
      requireDigit: state.requireDigit,
      requireSpecialChar: state.requireSpecialChar,
      validityPeriodIndex: state.validityPeriodIndex,
      customValidityPeriodText: state.customValidityPeriodText,
      hasChanges
    }
  }

  private static areStatesEqual(left: IdentitySettingsState, right: IdentitySettingsState): boolean {
    return left.minLengthIndex === right.minLengthIndex &&
      left.requireUppercase === right.requireUppercase &&
      left.requireLowercase === right.requireLowercase &&
      left.requireDigit === right.requireDigit &&
      left.requireSpecialChar === right.requireSpecialChar &&
      left.validityPeriodIndex === right.validityPeriodIndex &&
      left.customValidityPeriodText === right.customValidityPeriodText
  }
}
