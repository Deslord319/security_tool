import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { ResultMessageStatus } from '../components/ResultMessageBox'
import { CommonStrings } from '../constants/CommonStrings'
import { ToolSettingsStrings } from '../constants/modules/ToolSettingsStrings'
import { AUTH_METHOD_OPTIONS, AuthMethod, DEFAULT_TOOL_SETTINGS, ToolSettingsConfig } from '../models/DataModels'
import {
  PreferencesToolSettingsRepository,
  ToolSettingsRepository
} from '../services/ToolSettingsRepository'
import {
  DefaultToolSettingsRuntimeGateway,
  ToolSettingsRuntimeGateway
} from '../services/ToolSettingsRuntimeGateway'

const TAG = 'ToolSettings.ViewModel'
const DOMAIN = 0x0014
const UNKNOWN_TOOL_SETTINGS_ERROR_CODE = -1

interface ToolSettingsLoggableError {
  code?: number
  message?: string
}

export interface ToolSettingsUiState {
  config: ToolSettingsConfig
  initialConfig: ToolSettingsConfig
  hasChanges: boolean
}

export type ToolSettingsActionKind = 'none' | 'result' | 'confirm'

export interface ToolSettingsActionRequest {
  kind: ToolSettingsActionKind
  status?: ResultMessageStatus
  title?: string
  message?: string
}

@Observed
export class ToolSettingsViewModel {
  state: ToolSettingsUiState = this.createInitialState()
  private repository: ToolSettingsRepository
  private runtimeGateway: ToolSettingsRuntimeGateway
  private isInitializing: boolean = false
  private isSaving: boolean = false

  constructor(
    repository: ToolSettingsRepository = new PreferencesToolSettingsRepository(),
    runtimeGateway: ToolSettingsRuntimeGateway = new DefaultToolSettingsRuntimeGateway()
  ) {
    this.repository = repository
    this.runtimeGateway = runtimeGateway
  }

  get selectedAuthMethodIndex(): number {
    let index = AUTH_METHOD_OPTIONS.findIndex((option) => option.value === this.state.config.authMethod)
    return index >= 0 ? index : 0
  }

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.isInitializing = true
    hilog.info(DOMAIN, TAG, '[LOAD_START] initialize | source=ToolSettingsPage')
    try {
      let config = await this.repository.loadConfig(context)
      this.commitState({
        config: this.cloneConfig(config),
        initialConfig: this.cloneConfig(config),
        hasChanges: false
      })
      hilog.info(
        DOMAIN,
        TAG,
        `[LOAD_SUCCESS] initialize | startupAuthEnabled=${config.startupAuthEnabled}, authMethod=${config.authMethod}`
      )
    } catch (err) {
      let fallbackConfig = this.cloneConfig(DEFAULT_TOOL_SETTINGS)
      let errorCode = this.getErrorCode(err)
      let errorMessage = this.getErrorMessage(err)
      this.commitState({
        config: fallbackConfig,
        initialConfig: this.cloneConfig(fallbackConfig),
        hasChanges: false
      })
      hilog.error(DOMAIN, TAG, `[LOAD_FAIL] initialize | code=${errorCode}, message=${errorMessage}`)
    } finally {
      this.isInitializing = false
    }
  }

  setStartupAuthEnabled(enabled: boolean): void {
    if (enabled === this.state.config.startupAuthEnabled) {
      return
    }
    let nextConfig = this.cloneConfig(this.state.config)
    nextConfig.startupAuthEnabled = enabled
    this.commitConfig(nextConfig)
    hilog.info(
      DOMAIN,
      TAG,
      `[USER_CHANGE] startupAuthEnabled | value=${enabled}, hasChanges=${this.state.hasChanges}`
    )
  }

  setAuthMethod(authMethod: AuthMethod): void {
    if (authMethod === this.state.config.authMethod) {
      return
    }
    let nextConfig = this.cloneConfig(this.state.config)
    nextConfig.authMethod = authMethod
    this.commitConfig(nextConfig)
    hilog.info(
      DOMAIN,
      TAG,
      `[USER_CHANGE] authMethod | value=${authMethod}, hasChanges=${this.state.hasChanges}`
    )
  }

  async requestSave(
    context: common.UIAbilityContext,
    allowUnsupportedAuthMethod: boolean = false
  ): Promise<ToolSettingsActionRequest> {
    if (this.isInitializing || this.isSaving) {
      return { kind: 'none' }
    }
    hilog.info(
      DOMAIN,
      TAG,
      `[USER_SAVE_CLICK] requestSave | hasChanges=${this.state.hasChanges}, startupAuthEnabled=${this.state.config.startupAuthEnabled}, authMethod=${this.state.config.authMethod}`
    )
    if (!this.state.hasChanges) {
      return {
        kind: 'result',
        status: 'failure',
        message: CommonStrings.messageNoChanges
      }
    }

    if (this.state.config.startupAuthEnabled && !allowUnsupportedAuthMethod) {
      let availability = this.runtimeGateway.checkAuthAvailability(this.state.config.authMethod)
      hilog.info(
        DOMAIN,
        TAG,
        `[STARTUP_AUTH_RESULT] availability | authMethod=${this.state.config.authMethod}, available=${availability.available}, errorCode=${availability.errorCode ?? 0}`
      )
      if (!availability.available) {
        let confirmMessage = `${availability.message}\n\n${ToolSettingsStrings.authMethodUnavailableMessage}`
        hilog.warn(
          DOMAIN,
          TAG,
          `[CONFIRM_REQUIRED] requestSave | authMethod=${this.state.config.authMethod}, errorCode=${availability.errorCode ?? 0}`
        )
        return {
          kind: 'confirm',
          title: ToolSettingsStrings.authMethodUnavailableTitle,
          message: confirmMessage
        }
      }
    }

    return this.saveCurrentConfig(context)
  }

  async openPasswordSettings(context: common.UIAbilityContext): Promise<ToolSettingsActionRequest> {
    hilog.info(DOMAIN, TAG, '[SYSNAV_START] openPasswordSettings | target=system_password_settings')
    let opened = await this.runtimeGateway.openPasswordSettings(context)
    hilog.info(DOMAIN, TAG, `[SYSNAV_RESULT] openPasswordSettings | opened=${opened}`)
    if (!opened) {
      return {
        kind: 'result',
        status: 'failure',
        message: ToolSettingsStrings.openPasswordSettingsFailed
      }
    }
    return { kind: 'none' }
  }

  private async saveCurrentConfig(context: common.UIAbilityContext): Promise<ToolSettingsActionRequest> {
    let configToSave = this.cloneConfig(this.state.config)
    this.isSaving = true
    hilog.info(
      DOMAIN,
      TAG,
      `[SAVE_START] saveConfig | startupAuthEnabled=${configToSave.startupAuthEnabled}, authMethod=${configToSave.authMethod}`
    )
    try {
      await this.repository.saveConfig(context, configToSave)
      this.commitState({
        config: this.cloneConfig(configToSave),
        initialConfig: this.cloneConfig(configToSave),
        hasChanges: false
      })
      hilog.info(
        DOMAIN,
        TAG,
        `[SAVE_SUCCESS] saveConfig | startupAuthEnabled=${configToSave.startupAuthEnabled}, authMethod=${configToSave.authMethod}`
      )
      return {
        kind: 'result',
        status: 'success',
        message: ToolSettingsStrings.saveSuccess
      }
    } catch (err) {
      let errorCode = this.getErrorCode(err)
      let errorMessage = this.getErrorMessage(err)
      this.commitState({
        config: this.cloneConfig(this.state.config),
        initialConfig: this.cloneConfig(this.state.initialConfig),
        hasChanges: this.hasChanges(this.state.config, this.state.initialConfig)
      })
      hilog.error(DOMAIN, TAG, `[SAVE_FAIL] saveConfig | code=${errorCode}, message=${errorMessage}`)
      return {
        kind: 'result',
        status: 'failure',
        message: CommonStrings.messageSaveFailed
      }
    } finally {
      this.isSaving = false
    }
  }

  private commitConfig(nextConfig: ToolSettingsConfig): void {
    this.commitState({
      config: this.cloneConfig(nextConfig),
      initialConfig: this.cloneConfig(this.state.initialConfig),
      hasChanges: this.hasChanges(nextConfig, this.state.initialConfig)
    })
  }

  private hasChanges(left: ToolSettingsConfig, right: ToolSettingsConfig): boolean {
    return left.startupAuthEnabled !== right.startupAuthEnabled || left.authMethod !== right.authMethod
  }

  private createInitialState(): ToolSettingsUiState {
    let defaultConfig = this.cloneConfig(DEFAULT_TOOL_SETTINGS)
    return {
      config: defaultConfig,
      initialConfig: this.cloneConfig(defaultConfig),
      hasChanges: false
    }
  }

  private cloneConfig(config: ToolSettingsConfig): ToolSettingsConfig {
    return {
      startupAuthEnabled: config.startupAuthEnabled,
      authMethod: config.authMethod
    }
  }

  private commitState(nextState: ToolSettingsUiState): void {
    this.state = nextState
  }

  private getErrorCode(err: Object): number {
    let error = err as ToolSettingsLoggableError
    if (typeof error?.code === 'number') {
      return error.code
    }
    return UNKNOWN_TOOL_SETTINGS_ERROR_CODE
  }

  private getErrorMessage(err: Object): string {
    let error = err as ToolSettingsLoggableError
    if (typeof error?.message === 'string' && error.message.length > 0) {
      return error.message
    }
    return 'unknown'
  }
}
