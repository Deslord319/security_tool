import { securityManager } from '@kit.MDMKit'
import { AdminText, MessageText } from '../../../constants/StringCatalog'
import { IdentityActionStrings } from '../../../constants/modules/IdentityStrings'
import { IdentityMessageStrings } from '../../../constants/modules/IdentityStrings'
import {
  AdminActivationState,
  PASSWORD_LENGTH_OPTIONS,
  PASSWORD_VALIDITY_PRESETS,
  PasswordComplexityConfig
} from '../../../models/DataModels'
import { EnterpriseAdminService } from '../../../services/admin/activation/EnterpriseAdminService'
import { IdentityService } from '../../../services/identity/settings/IdentityService'
import { ActionDialogStatus, DialogService } from '../../../utils/DialogService'
import { LogUtils } from '../../../utils/LogUtils'

export const HALF_YEAR_VALIDITY_OPTION_INDEX: number = 0
export const ONE_YEAR_VALIDITY_OPTION_INDEX: number = 1
export const CUSTOM_VALIDITY_OPTION_INDEX: number = PASSWORD_VALIDITY_PRESETS.length
const DEFAULT_PASSWORD_LENGTH_INDEX: number = 0
const DEFAULT_VALIDITY_OPTION_INDEX: number = HALF_YEAR_VALIDITY_OPTION_INDEX
const HALF_YEAR_VALIDITY_DAY_OPTIONS: number[] = [181, 182, 183, 184]
const ONE_YEAR_VALIDITY_DAY_OPTIONS: number[] = [365, 366]
const TAG = 'IdentitySettings.ViewModel'
type PasswordRequirementKey = 'requireUppercase' | 'requireLowercase' | 'requireDigit' | 'requireSpecialChar'

export type IdentitySettingsActionKind = 'none' | 'result' | 'confirm'

export interface IdentitySettingsActionRequest {
  kind: IdentitySettingsActionKind
  status?: ActionDialogStatus
  title?: string
  message: string
}

interface IdentitySettingsSnapshot {
  minLengthIndex: number
  requireUppercase: boolean
  requireLowercase: boolean
  requireDigit: boolean
  requireSpecialChar: boolean
  validityPeriodIndex: number
  customValidityPeriodText: string
}

@ObservedV2
export class IdentitySettingsState {
  @Trace initialized: boolean = false
  @Trace loading: boolean = false
  @Trace adminActivated: boolean = false
  @Trace adminMessage: string = ''
  @Trace minLengthIndex: number = DEFAULT_PASSWORD_LENGTH_INDEX
  @Trace requireUppercase: boolean = false
  @Trace requireLowercase: boolean = false
  @Trace requireDigit: boolean = false
  @Trace requireSpecialChar: boolean = false
  @Trace validityPeriodIndex: number = DEFAULT_VALIDITY_OPTION_INDEX
  @Trace customValidityPeriodText: string = ''
  @Trace hasChanges: boolean = false
  @Trace canSave: boolean = false
}

@ObservedV2
export class IdentitySettingsViewModel {
  @Trace state: IdentitySettingsState = IdentitySettingsViewModel.buildDefaultState()
  private initialState: IdentitySettingsSnapshot = IdentitySettingsViewModel.buildDefaultSnapshot()
  private adminState: AdminActivationState = IdentitySettingsViewModel.buildDefaultAdminState()

  initialize(): void {
    this.state.loading = true
    this.state.initialized = false
    this.refreshAdminActivationState()
    if (!this.adminState.activated) {
      LogUtils.warn(TAG, 'initialize skipped | admin not activated, reset to defaults')
      this.reset()
      this.state.loading = false
      this.state.initialized = true
      return
    }

    let result = IdentityService.getPasswordPolicyWithResult()
    if (!result.success) {
      LogUtils.warn(TAG,
        `initialize failed | reset to defaults, errorCode=${result.errorCode ?? 0}, errorMessage=${result.errorMessage ?? ''}`
      )
      this.reset()
      this.state.loading = false
      this.state.initialized = true
      return
    }

    LogUtils.info(TAG, `initialize success | hasPolicy=${result.data !== null}`)
    this.applyPolicy(result.data)
    this.state.loading = false
    this.state.initialized = true
  }

  reset(): void {
    this.applyPolicy(null)
  }

  requestSave(skipImmediateExpiryConfirm: boolean = false): IdentitySettingsActionRequest {
    this.refreshAdminActivationState()
    if (!this.adminState.activated) {
      return {
        kind: 'result',
        status: 'failure',
        message: this.adminState.errorMessage?.trim().length ?
          this.adminState.errorMessage :
          `${IdentityActionStrings.SAVE}${IdentityMessageStrings.ADMIN_REQUIRED_WITH_ACTION_SUFFIX}`
      }
    }

    let config = this.buildConfig()
    if (!config) {
      return {
        kind: 'result',
        status: 'failure',
        message: IdentityMessageStrings.INVALID_VALIDITY_DAYS
      }
    }

    if (!skipImmediateExpiryConfirm && config.validityPeriod === 0) {
      return {
        kind: 'confirm',
        title: IdentityMessageStrings.IMMEDIATE_EXPIRY_RISK_TITLE,
        message: IdentityMessageStrings.IMMEDIATE_EXPIRY_RISK_MESSAGE
      }
    }

    return this.executeSave(config)
  }

  private applyPolicy(policy?: securityManager.PasswordPolicy | null): void {
    let nextState = IdentitySettingsViewModel.buildDefaultState()
    this.applyConfig(nextState, IdentityService.toConfig(policy))
    nextState.hasChanges = false
    this.initialState = IdentitySettingsViewModel.toSnapshot(nextState)
    this.state.minLengthIndex = nextState.minLengthIndex
    this.state.requireUppercase = nextState.requireUppercase
    this.state.requireLowercase = nextState.requireLowercase
    this.state.requireDigit = nextState.requireDigit
    this.state.requireSpecialChar = nextState.requireSpecialChar
    this.state.validityPeriodIndex = nextState.validityPeriodIndex
    this.state.customValidityPeriodText = nextState.customValidityPeriodText
    this.state.hasChanges = false
    this.refreshDerivedState()
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

  private executeSave(config: PasswordComplexityConfig): IdentitySettingsActionRequest {
    let currentPolicy = IdentityService.getPasswordPolicyWithResult().data
    let currentConfig = IdentityService.toConfig(currentPolicy)
    if (this.areConfigsEqual(currentConfig, config)) {
      this.refreshDerivedState()
      return {
        kind: 'result',
        status: 'failure',
        message: MessageText.NO_CHANGES
      }
    }

    let result = IdentityService.setPasswordPolicyWithResult(config)
    if (!result.success) {
      this.refreshDerivedState()
      let message = result.isAdminMissing
        ? DialogService.displayReason(result.errorMessage, AdminText.NOT_ACTIVATED)
        : DialogService.displayReason(result.errorMessage, `${IdentityActionStrings.PASSWORD_POLICY}${IdentityMessageStrings.ACTION_RETRY_SUFFIX}`)
      return {
        kind: 'result',
        status: 'failure',
        message
      }
    }

    this.initialState = IdentitySettingsViewModel.toSnapshot(this.state)
    this.state.hasChanges = false
    this.refreshDerivedState()
    return {
      kind: 'result',
      status: 'success',
      message: IdentityMessageStrings.SAVE_SUCCESS
    }
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
    if (this.state.validityPeriodIndex === HALF_YEAR_VALIDITY_OPTION_INDEX) {
      return IdentitySettingsViewModel.buildHalfYearValidityDays()
    }
    if (this.state.validityPeriodIndex === ONE_YEAR_VALIDITY_OPTION_INDEX) {
      return IdentitySettingsViewModel.buildOneYearValidityDays()
    }

    let normalizedText = this.state.customValidityPeriodText.trim()
    if (normalizedText.length === 0 || !/^\d+$/.test(normalizedText)) {
      return null
    }
    return parseInt(normalizedText)
  }

  private applyConfig(state: IdentitySettingsState, config: PasswordComplexityConfig | null): void {
    if (!config) {
      return
    }

    state.requireLowercase = config.requireLowercase
    state.requireUppercase = config.requireUppercase
    state.requireDigit = config.requireDigit
    state.requireSpecialChar = config.requireSpecialChar
    let index = PASSWORD_LENGTH_OPTIONS.indexOf(config.minLength)
    if (index >= 0) {
      state.minLengthIndex = index
    }
    let validityPeriod = config.validityPeriod
    if (typeof validityPeriod !== 'number') {
      state.validityPeriodIndex = DEFAULT_VALIDITY_OPTION_INDEX
      state.customValidityPeriodText = ''
      return
    }

    if (HALF_YEAR_VALIDITY_DAY_OPTIONS.indexOf(validityPeriod) >= 0) {
      state.validityPeriodIndex = HALF_YEAR_VALIDITY_OPTION_INDEX
      state.customValidityPeriodText = ''
      return
    }

    if (ONE_YEAR_VALIDITY_DAY_OPTIONS.indexOf(validityPeriod) >= 0) {
      state.validityPeriodIndex = ONE_YEAR_VALIDITY_OPTION_INDEX
      state.customValidityPeriodText = ''
      return
    }

    state.validityPeriodIndex = CUSTOM_VALIDITY_OPTION_INDEX
    state.customValidityPeriodText = `${validityPeriod}`
  }

  private updateState(editor: (nextState: IdentitySettingsState) => void): void {
    editor(this.state)
    this.refreshDerivedState()
  }

  private static buildDefaultState(): IdentitySettingsState {
    let state = new IdentitySettingsState()
    state.initialized = false
    state.loading = false
    state.adminActivated = false
    state.adminMessage = ''
    state.minLengthIndex = DEFAULT_PASSWORD_LENGTH_INDEX
    state.requireUppercase = false
    state.requireLowercase = false
    state.requireDigit = false
    state.requireSpecialChar = false
    state.validityPeriodIndex = DEFAULT_VALIDITY_OPTION_INDEX
    state.customValidityPeriodText = ''
    state.hasChanges = false
    state.canSave = false
    return state
  }

  private static buildDefaultAdminState(): AdminActivationState {
    return {
      activated: false,
      enableCommand: EnterpriseAdminService.buildEnableCommand(),
      adminType: EnterpriseAdminService.DEFAULT_ADMIN_TYPE
    }
  }

  private static buildDefaultSnapshot(): IdentitySettingsSnapshot {
    return {
      minLengthIndex: DEFAULT_PASSWORD_LENGTH_INDEX,
      requireUppercase: false,
      requireLowercase: false,
      requireDigit: false,
      requireSpecialChar: false,
      validityPeriodIndex: DEFAULT_VALIDITY_OPTION_INDEX,
      customValidityPeriodText: ''
    }
  }

  private static buildHalfYearValidityDays(referenceDate: Date = new Date()): number {
    return IdentitySettingsViewModel.diffDays(referenceDate, IdentitySettingsViewModel.addMonths(referenceDate, 6))
  }

  private static buildOneYearValidityDays(referenceDate: Date = new Date()): number {
    return IdentitySettingsViewModel.diffDays(referenceDate, IdentitySettingsViewModel.addYears(referenceDate, 1))
  }

  private static addMonths(referenceDate: Date, months: number): Date {
    let year = referenceDate.getFullYear()
    let month = referenceDate.getMonth()
    let day = referenceDate.getDate()
    let totalMonths = month + months
    let targetYear = year + Math.floor(totalMonths / 12)
    let targetMonth = ((totalMonths % 12) + 12) % 12
    let lastDayOfMonth = new Date(targetYear, targetMonth + 1, 0).getDate()
    let targetDay = Math.min(day, lastDayOfMonth)
    return new Date(
      targetYear,
      targetMonth,
      targetDay,
      referenceDate.getHours(),
      referenceDate.getMinutes(),
      referenceDate.getSeconds(),
      referenceDate.getMilliseconds()
    )
  }

  private static addYears(referenceDate: Date, years: number): Date {
    let targetYear = referenceDate.getFullYear() + years
    let targetMonth = referenceDate.getMonth()
    let targetDay = Math.min(
      referenceDate.getDate(),
      new Date(targetYear, targetMonth + 1, 0).getDate()
    )
    return new Date(
      targetYear,
      targetMonth,
      targetDay,
      referenceDate.getHours(),
      referenceDate.getMinutes(),
      referenceDate.getSeconds(),
      referenceDate.getMilliseconds()
    )
  }

  private static diffDays(startDate: Date, endDate: Date): number {
    let oneDayMs = 24 * 60 * 60 * 1000
    return Math.round((endDate.getTime() - startDate.getTime()) / oneDayMs)
  }

  private static toSnapshot(state: IdentitySettingsState): IdentitySettingsSnapshot {
    return {
      minLengthIndex: state.minLengthIndex,
      requireUppercase: state.requireUppercase,
      requireLowercase: state.requireLowercase,
      requireDigit: state.requireDigit,
      requireSpecialChar: state.requireSpecialChar,
      validityPeriodIndex: state.validityPeriodIndex,
      customValidityPeriodText: state.customValidityPeriodText
    }
  }

  private static areStatesEqual(left: IdentitySettingsSnapshot, right: IdentitySettingsState): boolean {
    return left.minLengthIndex === right.minLengthIndex &&
      left.requireUppercase === right.requireUppercase &&
      left.requireLowercase === right.requireLowercase &&
      left.requireDigit === right.requireDigit &&
      left.requireSpecialChar === right.requireSpecialChar &&
      left.validityPeriodIndex === right.validityPeriodIndex &&
      left.customValidityPeriodText === right.customValidityPeriodText
  }

  private refreshHasChanges(): void {
    this.state.hasChanges = !IdentitySettingsViewModel.areStatesEqual(this.initialState, this.state)
  }

  private refreshDerivedState(): void {
    this.refreshHasChanges()
    this.state.canSave = this.state.adminActivated &&
      !this.state.loading &&
      this.state.hasChanges
  }

  private refreshAdminActivationState(): void {
    this.adminState = EnterpriseAdminService.probeActivation()
    this.state.adminActivated = this.adminState.activated
    this.state.adminMessage = this.adminState.errorMessage ?? ''
    LogUtils.info(TAG,
      `refreshAdminActivationState | activated=${this.adminState.activated}, errorCode=${this.adminState.errorCode ?? 0}, message=${this.adminState.errorMessage ?? ''}`
    )
    this.refreshDerivedState()
  }

  private areConfigsEqual(left: PasswordComplexityConfig | null, right: PasswordComplexityConfig): boolean {
    return !!left &&
      left.minLength === right.minLength &&
      left.requireUppercase === right.requireUppercase &&
      left.requireLowercase === right.requireLowercase &&
      left.requireDigit === right.requireDigit &&
      left.requireSpecialChar === right.requireSpecialChar &&
      left.validityPeriod === right.validityPeriod
  }
}
