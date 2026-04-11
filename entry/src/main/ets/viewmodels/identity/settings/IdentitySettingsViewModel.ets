import { securityManager } from '@kit.MDMKit'
import { AdminText, MessageText } from '../../../constants/StringCatalog'
import { IdentityActionStrings } from '../../../constants/modules/IdentityStrings'
import { IdentityMessageStrings } from '../../../constants/modules/IdentityStrings'
import {
  PASSWORD_LENGTH_OPTIONS,
  PASSWORD_VALIDITY_OPTIONS,
  PasswordComplexityConfig
} from '../../../models/DataModels'
import { IdentityService } from '../../../services/identity/settings/IdentityService'
import { DialogService } from '../../../utils/DialogService'

export const PERMANENT_VALIDITY_OPTION_INDEX: number = PASSWORD_VALIDITY_OPTIONS.length
export const CUSTOM_VALIDITY_OPTION_INDEX: number = PASSWORD_VALIDITY_OPTIONS.length + 1
type PasswordRequirementKey = 'requireUppercase' | 'requireLowercase' | 'requireDigit' | 'requireSpecialChar'

export interface IdentitySettingsSaveResult {
  success: boolean
  message: string
}

@ObservedV2
export class IdentitySettingsState {
  @Trace minLengthIndex: number = 1
  @Trace requireUppercase: boolean = true
  @Trace requireLowercase: boolean = true
  @Trace requireDigit: boolean = true
  @Trace requireSpecialChar: boolean = true
  @Trace validityPeriodIndex: number = 0
  @Trace customValidityPeriodText: string = ''
  @Trace hasChanges: boolean = false
}

@ObservedV2
export class IdentitySettingsViewModel {
  @Trace state: IdentitySettingsState = IdentitySettingsViewModel.buildDefaultState()
  private initialState: IdentitySettingsState = IdentitySettingsViewModel.buildDefaultState()

  initialize(policy?: securityManager.PasswordPolicy | null): void {
    let nextState = IdentitySettingsViewModel.buildDefaultState()
    if (policy?.complexityRegex) {
      nextState = this.applyRegex(nextState, policy.complexityRegex)
    }
    nextState = this.applyValidityPeriod(nextState, policy?.validityPeriod)
    nextState.hasChanges = false
    this.initialState = IdentitySettingsViewModel.snapshot(nextState)
    this.copyState(this.state, nextState)
  }

  reset(): void {
    this.initialize(null)
  }

  get isCustomValiditySelected(): boolean {
    return this.state.validityPeriodIndex === CUSTOM_VALIDITY_OPTION_INDEX
  }

  setMinLengthIndex(index: number): void {
    this.updateState((nextState: IdentitySettingsState) => {
      if (index >= 0 && index < PASSWORD_LENGTH_OPTIONS.length) {
        nextState.minLengthIndex = index
      }
    })
  }

  setRequirement(key: PasswordRequirementKey, value: boolean): void {
    this.updateState((nextState: IdentitySettingsState) => {
      switch (key) {
        case 'requireUppercase':
          nextState.requireUppercase = value
          break
        case 'requireLowercase':
          nextState.requireLowercase = value
          break
        case 'requireDigit':
          nextState.requireDigit = value
          break
        case 'requireSpecialChar':
          nextState.requireSpecialChar = value
          break
      }
    })
  }

  setValidityPeriodIndex(index: number): void {
    this.updateState((nextState: IdentitySettingsState) => {
      if (index >= 0 && index <= CUSTOM_VALIDITY_OPTION_INDEX) {
        nextState.validityPeriodIndex = index
      }
      if (nextState.validityPeriodIndex !== CUSTOM_VALIDITY_OPTION_INDEX) {
        nextState.customValidityPeriodText = ''
      }
    })
  }

  setCustomValidityPeriodText(value: string): void {
    this.updateState((nextState: IdentitySettingsState) => {
      nextState.customValidityPeriodText = value.replace(/[^0-9]/g, '')
    })
  }

  shouldWarnImmediateExpiry(): boolean {
    return this.resolveValidityPeriod() === 0
  }

  save(): IdentitySettingsSaveResult {
    let config = this.buildConfig()
    if (!config) {
      return { success: false, message: IdentityMessageStrings.INVALID_VALIDITY_DAYS }
    }

    let currentPolicy = IdentityService.getPasswordPolicyWithResult().data
    let currentRegex: string = currentPolicy?.complexityRegex ?? ''
    let nextRegex: string = IdentityService.buildComplexityRegex(config)
    let currentValidity: number | undefined = currentPolicy?.validityPeriod
    if (currentRegex === nextRegex && currentValidity === config.validityPeriod) {
      return { success: false, message: MessageText.NO_CHANGES }
    }

    let result = IdentityService.setPasswordPolicyWithResult(config)
    if (!result.success) {
      let message = result.isAdminMissing
        ? DialogService.displayReason(result.errorMessage, AdminText.NOT_ACTIVATED)
        : DialogService.displayReason(result.errorMessage, `${IdentityActionStrings.PASSWORD_POLICY}${IdentityMessageStrings.ACTION_RETRY_SUFFIX}`)
      return { success: false, message }
    }

    this.initialState = IdentitySettingsViewModel.snapshot(this.state)
    this.state.hasChanges = false
    return { success: true, message: IdentityMessageStrings.SAVE_SUCCESS }
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

  private resolveValidityPeriod(): number | undefined | null {
    if (this.state.validityPeriodIndex < PASSWORD_VALIDITY_OPTIONS.length) {
      return PASSWORD_VALIDITY_OPTIONS[this.state.validityPeriodIndex]
    }
    if (this.state.validityPeriodIndex === PERMANENT_VALIDITY_OPTION_INDEX) {
      return undefined
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
    if (typeof validityPeriod !== 'number') {
      nextState.validityPeriodIndex = PERMANENT_VALIDITY_OPTION_INDEX
      return nextState
    }

    let index = PASSWORD_VALIDITY_OPTIONS.indexOf(validityPeriod)
    if (index >= 0) {
      nextState.validityPeriodIndex = index
      return nextState
    }

    if (validityPeriod === 0) {
      nextState.validityPeriodIndex = CUSTOM_VALIDITY_OPTION_INDEX
      nextState.customValidityPeriodText = '0'
      return nextState
    }

    nextState.validityPeriodIndex = CUSTOM_VALIDITY_OPTION_INDEX
    nextState.customValidityPeriodText = `${validityPeriod}`
    return nextState
  }

  private updateState(editor: (nextState: IdentitySettingsState) => void): void {
    let nextState = IdentitySettingsViewModel.snapshot(this.state)
    editor(nextState)
    nextState.hasChanges = !IdentitySettingsViewModel.areStatesEqual(this.initialState, nextState)
    this.copyState(this.state, nextState)
  }

  private static buildDefaultState(): IdentitySettingsState {
    let state = new IdentitySettingsState()
    state.minLengthIndex = 1
    state.requireUppercase = true
    state.requireLowercase = true
    state.requireDigit = true
    state.requireSpecialChar = true
    state.validityPeriodIndex = 0
    state.customValidityPeriodText = ''
    state.hasChanges = false
    return state
  }

  private static snapshot(state: IdentitySettingsState): IdentitySettingsState {
    let snapshot = new IdentitySettingsState()
    snapshot.minLengthIndex = state.minLengthIndex
    snapshot.requireUppercase = state.requireUppercase
    snapshot.requireLowercase = state.requireLowercase
    snapshot.requireDigit = state.requireDigit
    snapshot.requireSpecialChar = state.requireSpecialChar
    snapshot.validityPeriodIndex = state.validityPeriodIndex
    snapshot.customValidityPeriodText = state.customValidityPeriodText
    snapshot.hasChanges = state.hasChanges
    return snapshot
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

  private copyState(target: IdentitySettingsState, source: IdentitySettingsState): void {
    target.minLengthIndex = source.minLengthIndex
    target.requireUppercase = source.requireUppercase
    target.requireLowercase = source.requireLowercase
    target.requireDigit = source.requireDigit
    target.requireSpecialChar = source.requireSpecialChar
    target.validityPeriodIndex = source.validityPeriodIndex
    target.customValidityPeriodText = source.customValidityPeriodText
    target.hasChanges = source.hasChanges
  }
}
