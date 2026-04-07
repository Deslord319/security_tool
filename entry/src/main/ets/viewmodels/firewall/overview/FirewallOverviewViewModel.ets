import { common } from '@kit.AbilityKit'

import { FirewallOperationResult, FirewallOverviewState, FirewallPresetMode, FirewallToggleOperationResult } from '../../../models/firewall/firewall_service_contracts'
import { FirewallService } from '../../../services/firewall/FirewallService'

@ObservedV2
export class FirewallOverviewViewModelState {
  @Trace enabled: boolean = false
  @Trace currentMode: FirewallPresetMode = 'custom'
  @Trace initialized: boolean = false
  @Trace isLoading: boolean = false
  @Trace isToggleProcessing: boolean = false
  @Trace isModeProcessing: boolean = false
}

@ObservedV2
export class FirewallOverviewViewModel {
  @Trace state: FirewallOverviewViewModelState = new FirewallOverviewViewModelState()

  async initialize(context: common.UIAbilityContext): Promise<FirewallOverviewState> {
    this.state.isLoading = true
    try {
      let overview = await FirewallService.loadOverviewState(context)
      this.applyOverview(overview)
      this.state.initialized = true
      return overview
    } finally {
      this.state.isLoading = false
    }
  }

  async refresh(context: common.UIAbilityContext): Promise<FirewallOverviewState> {
    return this.initialize(context)
  }

  async requestToggle(
    context: common.UIAbilityContext,
    targetEnabled: boolean
  ): Promise<FirewallToggleOperationResult> {
    if (this.state.isToggleProcessing) {
      return {
        success: false,
        targetEnabled: targetEnabled,
        errorMessage: 'toggle in progress'
      }
    }

    this.state.isToggleProcessing = true
    try {
      let result = await FirewallService.toggleFirewall(context, this.state.enabled, targetEnabled)
      if (result.success) {
        this.state.enabled = targetEnabled
      }
      return result
    } finally {
      this.state.isToggleProcessing = false
    }
  }

  async requestModeSwitch(
    context: common.UIAbilityContext,
    targetMode: FirewallPresetMode
  ): Promise<FirewallOperationResult> {
    if (this.state.isModeProcessing) {
      return {
        success: false,
        errorMessage: 'mode switch in progress'
      }
    }

    this.state.isModeProcessing = true
    try {
      let result = await FirewallService.switchMode(context, targetMode)
      if (result.success) {
        this.state.currentMode = targetMode
      }
      return result
    } finally {
      this.state.isModeProcessing = false
    }
  }

  private applyOverview(overview: FirewallOverviewState): void {
    this.state.enabled = overview.enabled
    this.state.currentMode = overview.currentMode
  }
}
