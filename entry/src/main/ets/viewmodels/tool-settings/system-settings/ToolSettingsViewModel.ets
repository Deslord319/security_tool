import { LogUtils } from '../../../utils/LogUtils'
import { common } from '@kit.AbilityKit'
import { ActionDialogStatus } from '../../../utils/DialogService'
import { MessageText } from '../../../constants/StringCatalog'
import { AuthMethod } from '../../../models/AuthModels'
import {
  DEFAULT_TOOL_SETTINGS,
  ToolSettingsConfig
} from '../../../models/ToolSettingsModels'
import { AUTH_METHOD_OPTIONS } from './ToolSettingsPresentationOptions'
import {
  ToolSettingsConfirmationStrings,
  ToolSettingsPageStrings
} from '../../../constants/modules/ToolSettingsStrings'
import {
  PreferencesToolSettingsRepository,
  ToolSettingsRepository
} from '../../../services/tool-settings/system-settings/ToolSettingsRepository'
import { AuthService } from '../../../services/identity/auth/AuthService'
import { SystemSettingsService } from '../../../services/tool-settings/system-settings/SystemSettingsService'

const TAG = 'ToolSettings.ViewModel'

type ToolSettingsActionKind = 'none' | 'result' | 'confirm'

export interface ToolSettingsActionRequest {
  kind: ToolSettingsActionKind
  status?: ActionDialogStatus
  title?: string
  message?: string
}

@ObservedV2
export class ToolSettingsConfigState {
  @Trace startupAuthEnabled: boolean = DEFAULT_TOOL_SETTINGS.startupAuthEnabled
  @Trace authMethod: AuthMethod = DEFAULT_TOOL_SETTINGS.authMethod
}

@ObservedV2
class ToolSettingsUiState {
  @Trace config: ToolSettingsConfigState = new ToolSettingsConfigState()
  @Trace initialConfig: ToolSettingsConfigState = new ToolSettingsConfigState()
  @Trace hasChanges: boolean = false
  @Trace saving: boolean = false
  @Trace initialized: boolean = false
}

@ObservedV2
export class ToolSettingsViewModel {
  @Trace state: ToolSettingsUiState = new ToolSettingsUiState()
  private repository: ToolSettingsRepository

  constructor(repository: ToolSettingsRepository = new PreferencesToolSettingsRepository()) {
    this.repository = repository
  }

  get selectedAuthMethodIndex(): number {
    let index = AUTH_METHOD_OPTIONS.findIndex((option) => option.value === this.state.config.authMethod)
    return index >= 0 ? index : 0
  }

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.state.initialized = false
    let config = await this.repository.loadConfig(context)
    this.applyConfig(this.state.config, config.startupAuthEnabled, config.authMethod)
    this.applyConfig(this.state.initialConfig, config.startupAuthEnabled, config.authMethod)
    this.state.hasChanges = false
    this.state.initialized = true
  }

  setStartupAuthEnabled(enabled: boolean): void {
    if (enabled === this.state.config.startupAuthEnabled) {
      return
    }
    this.updateConfig({
      startupAuthEnabled: enabled,
      authMethod: this.state.config.authMethod
    })
  }

  setAuthMethod(authMethod: AuthMethod): void {
    if (authMethod === this.state.config.authMethod) {
      return
    }
    this.updateConfig({
      startupAuthEnabled: this.state.config.startupAuthEnabled,
      authMethod: authMethod
    })
  }

  async requestSave(
    context: common.UIAbilityContext,
    allowUnsupportedAuthMethod: boolean = false
  ): Promise<ToolSettingsActionRequest> {
    if (this.state.saving) {
      LogUtils.warn(TAG, '[SAVE_SKIP] requestSave | reason=saving')
      return { kind: 'none' }
    }
    if (!this.state.hasChanges) {
      LogUtils.warn(TAG, '[SAVE_SKIP] requestSave | reason=no_changes')
      return {
        kind: 'result',
        status: 'failure',
        message: MessageText.NO_CHANGES
      }
    }

    if (this.state.config.startupAuthEnabled && !allowUnsupportedAuthMethod) {
      let availability = AuthService.checkAuthMethodAvailability(this.state.config.authMethod)
      if (!availability.available) {
        let confirmMessage = `${availability.message}\n\n${ToolSettingsConfirmationStrings.AUTH_METHOD_UNAVAILABLE_MESSAGE}`
        LogUtils.warn(TAG,
          `[CONFIRM_REQUIRED] requestSave | authMethod=${this.state.config.authMethod}, errorCode=${availability.errorCode ?? 0}`
        )
        return {
          kind: 'confirm',
          title: ToolSettingsConfirmationStrings.AUTH_METHOD_UNAVAILABLE_TITLE,
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
        message: ToolSettingsPageStrings.OPEN_PASSWORD_SETTINGS_FAILED
      }
    }
    return { kind: 'none' }
  }

  private async saveCurrentConfig(context: common.UIAbilityContext): Promise<ToolSettingsActionRequest> {
    let configToSave: ToolSettingsConfig = {
      startupAuthEnabled: this.state.config.startupAuthEnabled,
      authMethod: this.state.config.authMethod
    }
    this.state.saving = true
    try {
      let saved = await this.repository.saveConfig(context, configToSave)
      if (!saved) {
        LogUtils.error(TAG, '[SAVE_FAIL] saveConfig | repository returned false')
      return {
        kind: 'result',
        status: 'failure',
        message: MessageText.SAVE_FAILED
      }
    }
      this.applyConfig(this.state.config, configToSave.startupAuthEnabled, configToSave.authMethod)
      this.applyConfig(this.state.initialConfig, configToSave.startupAuthEnabled, configToSave.authMethod)
      this.state.hasChanges = false
      return {
        kind: 'result',
        status: 'success',
        message: ToolSettingsPageStrings.SAVE_SUCCESS
      }
    } finally {
      this.state.saving = false
    }
  }

  private updateConfig(config: ToolSettingsConfig): void {
    this.applyConfig(this.state.config, config.startupAuthEnabled, config.authMethod)
    this.state.hasChanges =
      config.startupAuthEnabled !== this.state.initialConfig.startupAuthEnabled ||
      config.authMethod !== this.state.initialConfig.authMethod
  }

  private applyConfig(target: ToolSettingsConfigState, startupAuthEnabled: boolean, authMethod: AuthMethod): void {
    target.startupAuthEnabled = startupAuthEnabled
    target.authMethod = authMethod
  }
}
