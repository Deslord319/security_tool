import { LogUtils } from './utils/LogUtils'
import { common } from '@kit.AbilityKit'
import { ActionDialogStatus } from '../utils/DialogService'
import { CommonStrings } from '../constants/CommonStrings'
import { ToolSettingsStrings } from '../constants/modules/ToolSettingsStrings'
import { AUTH_METHOD_OPTIONS, AuthMethod, DEFAULT_TOOL_SETTINGS, ToolSettingsConfig } from '../models/DataModels'
import {
  PreferencesToolSettingsRepository,
  ToolSettingsRepository
} from '../services/ToolSettingsRepository'
import { AuthService } from '../services/AuthService'
import { SystemSettingsService } from '../services/SystemSettingsService'

const TAG = 'ToolSettings.ViewModel'
const DOMAIN = 0x0014

export interface ToolSettingsUiState {
  config: ToolSettingsConfig
  initialConfig: ToolSettingsConfig
  hasChanges: boolean
}

export type ToolSettingsActionKind = 'none' | 'result' | 'confirm'

export interface ToolSettingsActionRequest {
  kind: ToolSettingsActionKind
  status?: ActionDialogStatus
  title?: string
  message?: string
}

@Observed
export class ToolSettingsViewModel {
  state: ToolSettingsUiState = {
    config: {
      startupAuthEnabled: DEFAULT_TOOL_SETTINGS.startupAuthEnabled,
      authMethod: DEFAULT_TOOL_SETTINGS.authMethod
    },
    initialConfig: {
      startupAuthEnabled: DEFAULT_TOOL_SETTINGS.startupAuthEnabled,
      authMethod: DEFAULT_TOOL_SETTINGS.authMethod
    },
    hasChanges: false
  }
  private repository: ToolSettingsRepository
  private isSaving: boolean = false

  constructor(repository: ToolSettingsRepository = new PreferencesToolSettingsRepository()) {
    this.repository = repository
  }

  get selectedAuthMethodIndex(): number {
    let index = AUTH_METHOD_OPTIONS.findIndex((option) => option.value === this.state.config.authMethod)
    return index >= 0 ? index : 0
  }

  async initialize(context: common.UIAbilityContext): Promise<void> {
    LogUtils.info(TAG, '[LOAD_START] initialize | source=ToolSettingsPage')
    let config = await this.repository.loadConfig(context)
    this.state = {
      config: this.createConfig(config.startupAuthEnabled, config.authMethod),
      initialConfig: this.createConfig(config.startupAuthEnabled, config.authMethod),
      hasChanges: false
    }
    LogUtils.info(TAG,
      `[LOAD_SUCCESS] initialize | startupAuthEnabled=${config.startupAuthEnabled}, authMethod=${config.authMethod}`
    )
  }

  setStartupAuthEnabled(enabled: boolean): void {
    if (enabled === this.state.config.startupAuthEnabled) {
      return
    }
    this.updateConfig({
      startupAuthEnabled: enabled,
      authMethod: this.state.config.authMethod
    })
    LogUtils.info(TAG,
      `[USER_CHANGE] startupAuthEnabled | value=${enabled}, hasChanges=${this.state.hasChanges}`
    )
  }

  setAuthMethod(authMethod: AuthMethod): void {
    if (authMethod === this.state.config.authMethod) {
      return
    }
    this.updateConfig({
      startupAuthEnabled: this.state.config.startupAuthEnabled,
      authMethod: authMethod
    })
    LogUtils.info(TAG,
      `[USER_CHANGE] authMethod | value=${authMethod}, hasChanges=${this.state.hasChanges}`
    )
  }

  async requestSave(
    context: common.UIAbilityContext,
    allowUnsupportedAuthMethod: boolean = false
  ): Promise<ToolSettingsActionRequest> {
    if (this.isSaving) {
      LogUtils.warn(TAG, '[SAVE_SKIP] requestSave | reason=saving')
      return { kind: 'none' }
    }
    LogUtils.info(TAG,
      `[USER_SAVE_CLICK] requestSave | hasChanges=${this.state.hasChanges}, startupAuthEnabled=${this.state.config.startupAuthEnabled}, authMethod=${this.state.config.authMethod}`
    )
    if (!this.state.hasChanges) {
      LogUtils.warn(TAG, '[SAVE_SKIP] requestSave | reason=no_changes')
      return {
        kind: 'result',
        status: 'failure',
        message: CommonStrings.messageNoChanges
      }
    }

    if (this.state.config.startupAuthEnabled && !allowUnsupportedAuthMethod) {
      let availability = AuthService.checkAuthMethodAvailability(this.state.config.authMethod)
      LogUtils.info(TAG,
        `[STARTUP_AUTH_RESULT] availability | authMethod=${this.state.config.authMethod}, available=${availability.available}, errorCode=${availability.errorCode ?? 0}`
      )
      if (!availability.available) {
        let confirmMessage = `${availability.message}\n\n${ToolSettingsStrings.authMethodUnavailableMessage}`
        LogUtils.warn(TAG,
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
    let opened = await SystemSettingsService.openPasswordSettings(context)
    if (!opened) {
      LogUtils.warn(TAG, '[SYSNAV_FAIL] openPasswordSettings | opened=false')
      return {
        kind: 'result',
        status: 'failure',
        message: ToolSettingsStrings.openPasswordSettingsFailed
      }
    }
    return { kind: 'none' }
  }

  private async saveCurrentConfig(context: common.UIAbilityContext): Promise<ToolSettingsActionRequest> {
    let configToSave = this.state.config
    this.isSaving = true
    try {
      let saved = await this.repository.saveConfig(context, configToSave)
      if (!saved) {
        LogUtils.error(TAG, '[SAVE_FAIL] saveConfig | repository returned false')
        return {
          kind: 'result',
          status: 'failure',
          message: CommonStrings.messageSaveFailed
        }
      }
      this.state = {
        config: this.createConfig(configToSave.startupAuthEnabled, configToSave.authMethod),
        initialConfig: this.createConfig(configToSave.startupAuthEnabled, configToSave.authMethod),
        hasChanges: false
      }
      LogUtils.info(TAG,
        `[SAVE_SUCCESS] saveConfig | startupAuthEnabled=${configToSave.startupAuthEnabled}, authMethod=${configToSave.authMethod}`
      )
      return {
        kind: 'result',
        status: 'success',
        message: ToolSettingsStrings.saveSuccess
      }
    } finally {
      this.isSaving = false
    }
  }

  private updateConfig(config: ToolSettingsConfig): void {
    this.state = {
      config: this.createConfig(config.startupAuthEnabled, config.authMethod),
      initialConfig: this.state.initialConfig,
      hasChanges:
        config.startupAuthEnabled !== this.state.initialConfig.startupAuthEnabled ||
        config.authMethod !== this.state.initialConfig.authMethod
    }
  }

  private createConfig(startupAuthEnabled: boolean, authMethod: AuthMethod): ToolSettingsConfig {
    return {
      startupAuthEnabled: startupAuthEnabled,
      authMethod: authMethod
    }
  }
}
