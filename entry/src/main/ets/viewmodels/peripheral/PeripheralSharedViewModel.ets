/**
 * 外设管理共享 ViewModel
 */
import { Observed } from '@kit.ArkUI'
import { PeripheralViewModelBase } from './PeripheralViewModelBase'
import { AdminActivationState, ResultMessageStatus } from '../../models/DataModels'
import { EnterpriseAdminService } from '../../services/EnterpriseAdminService'
import { ThemeMode } from '../../theme/ThemeColors'
import { ThemeManager } from '../../theme/ThemeManager'
import { ResultDialogHelper } from '../../utils/ResultDialogHelper'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'PeripheralSharedViewModel', DOMAIN = 0x0013

@Observed
export class PeripheralSharedViewModel extends PeripheralViewModelBase {
  @Observed currentTab: number = 0
  @Observed hoveredPanelIndex: number = -1
  @Observed touchStartTab: number = 0
  @Observed touchStartX: number = 0
  @Observed touchStartY: number = 0
  @Observed currentTheme: ThemeMode = ThemeMode.LIGHT
  @Observed override _adminState: AdminActivationState = { activated: false, enableCommand: EnterpriseAdminService.buildEnableCommand(), adminType: EnterpriseAdminService.DEFAULT_ADMIN_TYPE }
  private tabsController: any = null

  protected async onInitialize(): Promise<void> { this.loadTheme(); await this.refreshAdminActivationState(); await this.loadAllData() }
  switchToTab(index: number): void { if (index < 0 || index > 2 || index === this.currentTab) return; this.currentTab = index; if (this.tabsController) this.tabsController.changeIndex(index); if (index === 2) this.onSwitchToPolicyTab() }
  handlePageTouch(eventType: string, touchX: number, touchY: number): void {
    if (eventType === 'Down') { this.touchStartTab = this.currentTab; this.touchStartX = touchX; this.touchStartY = touchY; return }
    if (eventType !== 'Up') return
    const offsetX = touchX - this.touchStartX, offsetY = touchY - this.touchStartY
    if (Math.abs(offsetX) < 120 || Math.abs(offsetX) <= Math.abs(offsetY)) return
    if (offsetX > 0 && this.touchStartTab > 0) this.switchToTab(this.touchStartTab - 1)
    else if (offsetX < 0 && this.touchStartTab < 2) this.switchToTab(this.touchStartTab + 1)
  }
  async refreshAdminActivationState(): Promise<void> { try { this._adminState = await EnterpriseAdminService.getActivationState() } catch (err) { hilog.error(DOMAIN, TAG, `Failed to refresh admin state: ${JSON.stringify(err)}`) } }
  ensureAdminReady(action: string): boolean { if (!this._adminState.activated) { this.errorMessage = `${action}失败：请先激活企业管理员`; return false } return true }
  showResultDialog(status: ResultMessageStatus, message: string): void { ResultDialogHelper.prepareResultDialog(status, message) }
  setPanelHover(index: number, isHover: boolean): void { this.hoveredPanelIndex = isHover ? index : -1 }
  private loadTheme(): void { try { this.currentTheme = ThemeManager.getTheme() } catch (err) { hilog.warn(DOMAIN, TAG, `Failed to load theme: ${JSON.stringify(err)}`); this.currentTheme = ThemeMode.LIGHT } }
  toggleTheme(): void { this.currentTheme = this.currentTheme === ThemeMode.LIGHT ? ThemeMode.DARK : ThemeMode.LIGHT; ThemeManager.setTheme(this.currentTheme) }
  private async loadAllData(): Promise<void> { this.isLoading = true; try { await this.refreshAdminActivationState() } catch (err) { this.handleOperationResult(false, '加载数据', err) } finally { this.isLoading = false } }
  private onSwitchToPolicyTab(): void { hilog.info(DOMAIN, TAG, 'Switched to policy tab') }
  setTabsController(controller: any): void { this.tabsController = controller }
}
