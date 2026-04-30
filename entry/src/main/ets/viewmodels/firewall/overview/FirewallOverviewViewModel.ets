import { common } from '@kit.AbilityKit'

import { FirewallOperationResult, FirewallOverviewState, FirewallPresetMode, FirewallToggleOperationResult } from '../../../services/firewall/FirewallModels'
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
    let overview = await this.loadAndApply(context)
    this.state.initialized = true
    return overview
  }

  async refresh(context: common.UIAbilityContext): Promise<FirewallOverviewState> {
    return await this.loadAndApply(context)
  }

  private async loadAndApply(context: common.UIAbilityContext): Promise<FirewallOverviewState> {
    this.state.isLoading = true
    try {
      let overview = await FirewallService.loadOverviewState(context)
      this.applyOverview(overview)
      return overview
    } finally {
      this.state.isLoading = false
    }
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
      let result = await FirewallService.setFirewallEnabledForAllUsers(context, targetEnabled)
      await this.loadAndApply(context)
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
      await this.loadAndApply(context)
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
