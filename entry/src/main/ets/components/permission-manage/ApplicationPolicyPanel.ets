import { AppColors, AppStyles } from '../../constants/AppConstants'
import {
  PermissionApplicationStrings,
  PermissionThreeDStrings
} from '../../constants/modules/PermissionStrings'
import { ThemeMode } from '../../theme/ThemeColors'
import {
  PermissionPolicyState,
  ThreeDLoadState,
  ThreeDManagedState,
  ThreeDPermissionItem
} from '../../models/PermissionModels'
import { AsyncSelectRow } from '../AsyncSelectRow'

@ComponentV2
export struct PermissionApplicationPolicyPanel {
  @Param appKey: string = ''
  @Param uid: number = 0
  @Param uninstallProtected: boolean = false
  @Param runningBlocked: boolean = false
  @Param networkBlocked: boolean = false
  @Param threeDGroups: ThreeDPermissionItem[] = []
  @Param threeDLoadState: ThreeDLoadState = 'idle'
  @Param threeDMessage: string = ''
  @Param loadingSelectedApp: boolean = false
  @Param processingActionKey: string = ''
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Event onSetUninstallProtected: (enabled: boolean) => Promise<boolean> = async () => false
  @Event onSetRunningPolicy: (policy: PermissionPolicyState) => Promise<boolean> = async () => false
  @Event onSetNetworkPolicy: (policy: PermissionPolicyState) => Promise<boolean> = async () => false
  @Event onSetThreeDPermissionState: (groupKey: string, state: ThreeDManagedState) => Promise<boolean> =
    async () => false

  build() {
    Column({ space: 0 }) {
      if (this.loadingSelectedApp) {
        this.loadingRow()
      }

      this.applicationControlRows()

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      this.threeDPermissionRows()
    }
    .width('100%')
  }

  @Builder
  private loadingRow() {
    Row({ space: 8 }) {
      LoadingProgress()
        .width(AppStyles.INLINE_LOADING_INDICATOR_SIZE)
        .height(AppStyles.INLINE_LOADING_INDICATOR_SIZE)
        .color(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)

      Text(PermissionThreeDStrings.DETAIL_LOADING)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 16, right: 16, top: 12, bottom: 8 })
  }

  @Builder
  private applicationControlRows() {
    this.uninstallProtectedActionRow()

    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    AsyncSelectRow({
      label: PermissionApplicationStrings.RUNNING_POLICY,
      description: this.formatDescriptionWithState(
        PermissionApplicationStrings.RUNNING_POLICY_DESC,
        this.formatBlockedState(this.runningBlocked)
      ),
      options: this.getRunningPolicyOptions(),
      selectedIndex: this.getRunningBlockedIndex(this.runningBlocked),
      selectWidth: 116,
      processing: this.isActionProcessing(this.getRunningActionKey()),
      enabledValue: this.canOperateApplicationPolicy(this.getRunningActionKey()),
      currentTheme: this.currentTheme,
      onSelectAsync: async (index: number): Promise<boolean> => {
        let nextBlocked = this.blockedByIndex(index)
        if (nextBlocked !== this.runningBlocked) {
          return await this.onSetRunningPolicy(nextBlocked ? 'denied' : 'default')
        }
        return true
      }
    })

    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    AsyncSelectRow({
      label: PermissionApplicationStrings.NETWORK_POLICY,
      description: this.uid > 0
        ? this.formatDescriptionWithState(
          PermissionApplicationStrings.NETWORK_POLICY_DESC,
          this.formatBlockedState(this.networkBlocked)
        )
        : PermissionApplicationStrings.MISSING_UID,
      options: this.getNetworkPolicyOptions(),
      selectedIndex: this.getNetworkBlockedIndex(this.networkBlocked),
      selectWidth: 116,
      processing: this.isActionProcessing(this.getNetworkActionKey()),
      enabledValue: this.canOperateApplicationPolicy(this.getNetworkActionKey()) && this.uid > 0,
      currentTheme: this.currentTheme,
      onSelectAsync: async (index: number): Promise<boolean> => {
        let nextBlocked = this.blockedByIndex(index)
        if (nextBlocked !== this.networkBlocked) {
          return await this.onSetNetworkPolicy(nextBlocked ? 'denied' : 'default')
        }
        return true
      }
    })
  }

  @Builder
  private uninstallProtectedActionRow() {
    AsyncSelectRow({
      label: PermissionApplicationStrings.UNINSTALL_PROTECTED,
      description: this.formatDescriptionWithState(
        PermissionApplicationStrings.UNINSTALL_PROTECTED_DESC,
        this.uninstallProtected ? PermissionApplicationStrings.ENABLED : PermissionApplicationStrings.DISABLED
      ),
      options: this.getUninstallProtectedOptions(),
      selectedIndex: this.getUninstallProtectedIndex(this.uninstallProtected),
      selectWidth: 116,
      processing: this.isActionProcessing(this.getUninstallActionKey()),
      enabledValue: this.canOperateApplicationPolicy(this.getUninstallActionKey()),
      currentTheme: this.currentTheme,
      onSelectAsync: async (index: number): Promise<boolean> => {
        let nextEnabled = this.uninstallProtectedByIndex(index)
        if (nextEnabled !== this.uninstallProtected) {
          return await this.onSetUninstallProtected(nextEnabled)
        }
        return true
      }
    })
  }

  @Builder
  private threeDPermissionRows() {
    if (this.threeDLoadState === 'loaded' && this.threeDMessage.length > 0 && this.threeDGroups.length === 0) {
      Text(this.threeDMessage)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
    } else {
      ForEach(this.getThreeDItems(), (item: ThreeDPermissionItem) => {
        AsyncSelectRow({
          label: item.title,
          description: this.getThreeDDescription(item),
          options: this.getThreeDOptionsForItem(item),
          selectedIndex: this.getThreeDStateIndexForItem(item),
          selectWidth: 116,
          processing: this.isActionProcessing(this.getThreeDActionKey(item)),
          enabledValue: this.canOperateApplicationPolicy(this.getThreeDActionKey(item)) && item.canManage,
          currentTheme: this.currentTheme,
          onSelectAsync: async (index: number): Promise<boolean> => {
            let nextState = this.threeDStateByIndex(index)
            if (item.canManage && nextState !== item.managedState) {
              return await this.onSetThreeDPermissionState(item.groupKey, nextState)
            }
            return item.canManage
          }
        })

        Divider()
          .color(AppColors.getColors(this.currentTheme).BORDER)
          .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
      }, (item: ThreeDPermissionItem): string => item.groupKey)
    }
  }

  private getRunningPolicyOptions(): string[] {
    return [
      PermissionApplicationStrings.POLICY_ALLOWED,
      PermissionApplicationStrings.POLICY_DENIED
    ]
  }

  private getNetworkPolicyOptions(): string[] {
    return [
      PermissionApplicationStrings.POLICY_ALLOWED,
      PermissionApplicationStrings.POLICY_DENIED
    ]
  }

  private getUninstallProtectedOptions(): string[] {
    return [
      PermissionApplicationStrings.DISABLED,
      PermissionApplicationStrings.ENABLED
    ]
  }

  private getThreeDOptions(): string[] {
    return [
      PermissionApplicationStrings.POLICY_DEFAULT,
      PermissionApplicationStrings.POLICY_ALLOWED,
      PermissionApplicationStrings.POLICY_DENIED
    ]
  }

  private getThreeDOptionsForItem(item: ThreeDPermissionItem): string[] {
    if (item.canManage) {
      return this.getThreeDOptions()
    }
    return [this.formatThreeDState(item.managedState)]
  }

  private blockedByIndex(index: number): boolean {
    return index === 1
  }

  private uninstallProtectedByIndex(index: number): boolean {
    return index === 1
  }

  private threeDStateByIndex(index: number): ThreeDManagedState {
    if (index === 1) {
      return 'granted'
    }
    if (index === 2) {
      return 'denied'
    }
    return 'default'
  }

  private getRunningBlockedIndex(blocked: boolean): number {
    return blocked ? 1 : 0
  }

  private getNetworkBlockedIndex(blocked: boolean): number {
    return blocked ? 1 : 0
  }

  private getUninstallProtectedIndex(enabled: boolean): number {
    return enabled ? 1 : 0
  }

  private getThreeDStateIndex(state: ThreeDManagedState): number {
    if (state === 'granted') {
      return 1
    }
    if (state === 'denied') {
      return 2
    }
    return 0
  }

  private getThreeDStateIndexForItem(item: ThreeDPermissionItem): number {
    return item.canManage ? this.getThreeDStateIndex(item.managedState) : 0
  }

  private hasProcessingAction(): boolean {
    return this.processingActionKey.length > 0
  }

  private isActionProcessing(actionKey: string): boolean {
    return this.processingActionKey === actionKey
  }

  private canOperateAction(actionKey: string): boolean {
    return !this.hasProcessingAction() || this.isActionProcessing(actionKey)
  }

  private canOperateApplicationPolicy(actionKey: string): boolean {
    return this.canOperateAction(actionKey) && !this.loadingSelectedApp
  }

  private getUninstallActionKey(): string {
    return `uninstall:${this.appKey}`
  }

  private getRunningActionKey(): string {
    return `running:${this.appKey}`
  }

  private getNetworkActionKey(): string {
    return `network:${this.appKey}`
  }

  private getThreeDActionKey(item: ThreeDPermissionItem): string {
    return `three-d:${this.appKey}:${item.groupKey}`
  }

  private getThreeDItems(): ThreeDPermissionItem[] {
    if (this.threeDLoadState === 'loaded') {
      return this.threeDGroups
    }
    return [
      this.createPendingThreeDItem('downloads', PermissionThreeDStrings.DOWNLOADS),
      this.createPendingThreeDItem('desktop', PermissionThreeDStrings.DESKTOP),
      this.createPendingThreeDItem('documents', PermissionThreeDStrings.DOCUMENTS)
    ]
  }

  private createPendingThreeDItem(groupKey: string, title: string): ThreeDPermissionItem {
    return {
      groupKey: groupKey,
      title: title,
      permissionNames: [],
      declaredPermissions: [],
      managedState: 'unsupported',
      canManage: false,
      disabledReason: PermissionThreeDStrings.DETAIL_LOADING
    } as ThreeDPermissionItem
  }

  private formatBlockedState(blocked: boolean): string {
    return blocked ? PermissionApplicationStrings.POLICY_DENIED : PermissionApplicationStrings.POLICY_ALLOWED
  }

  private formatDescriptionWithState(description: string, state: string): string {
    return `${description} · ${PermissionApplicationStrings.CURRENT_STATE_PREFIX}：${state}`
  }

  private getThreeDDescription(item: ThreeDPermissionItem): string {
    let baseDescription = this.getThreeDBaseDescription(item.groupKey)
    if (item.canManage && item.disabledReason.length > 0) {
      return `${baseDescription} · ${item.disabledReason}`
    }
    return baseDescription
  }

  private getThreeDBaseDescription(groupKey: string): string {
    if (groupKey === 'downloads') {
      return PermissionThreeDStrings.DOWNLOADS_DESC
    }
    if (groupKey === 'desktop') {
      return PermissionThreeDStrings.DESKTOP_DESC
    }
    if (groupKey === 'documents') {
      return PermissionThreeDStrings.DOCUMENTS_DESC
    }
    return PermissionApplicationStrings.THREE_D_GROUP_DESC
  }

  private formatThreeDState(state: ThreeDManagedState): string {
    if (state === 'granted') {
      return PermissionApplicationStrings.POLICY_ALLOWED
    }
    if (state === 'denied') {
      return PermissionApplicationStrings.POLICY_DENIED
    }
    if (state === 'undeclared') {
      return PermissionThreeDStrings.NO_DECLARED
    }
    if (state === 'unsupported') {
      return PermissionApplicationStrings.THREE_D_UNSUPPORTED
    }
    return PermissionApplicationStrings.POLICY_DEFAULT
  }
}
