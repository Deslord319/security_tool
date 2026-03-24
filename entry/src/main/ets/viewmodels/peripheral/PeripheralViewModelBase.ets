/**
 * Peripheral ViewModel 基类
 */
import { ObservableObject, Observed } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { AdminActivationState } from '../../models/DataModels'
import { EnterpriseAdminService } from '../../services/EnterpriseAdminService'

@Observed
export abstract class PeripheralViewModelBase extends ObservableObject {
  @Observed protected _adminState: AdminActivationState = { activated: false, enableCommand: EnterpriseAdminService.buildEnableCommand(), adminType: EnterpriseAdminService.DEFAULT_ADMIN_TYPE }
  @Observed isLoading: boolean = false
  @Observed errorMessage: string | null = null
  protected context: common.UIAbilityContext | null = null

  async initialize(context: common.UIAbilityContext): Promise<void> { this.context = context; await this.onInitialize() }
  protected abstract onInitialize(): Promise<void>
  destroy(): void { this.onDestroy() }
  protected onDestroy(): void {}
  protected ensureAdminReady(action: string): boolean { if (!this._adminState.activated) { this.errorMessage = `${action}失败：请先激活企业管理员`; return false } return true }
  updateAdminState(state: AdminActivationState): void { this._adminState = state }
  protected handleOperationResult(success: boolean, action: string, error?: any): void { this.errorMessage = success ? null : `${action}失败：${error?.message || '未知错误'}` }
  clearError(): void { this.errorMessage = null }
}
