import { ActionButtonStyles, AppColors, AppStyles } from '../../constants/AppConstants'
import { AppResources } from '../../constants/AppResources'
import {
  PermissionAccountStrings,
  PermissionApplicationStrings,
  PermissionEmptyStrings,
  PermissionSectionStrings
} from '../../constants/modules/PermissionStrings'
import {
  PermissionAppSnapshot,
  PermissionManagedAccount
} from '../../models/PermissionModels'
import { ThemeMode } from '../../theme/ThemeColors'
import { AsyncSelectRow } from '../AsyncSelectRow'
import { IconTextActionButton } from '../IconTextActionButton'
import { LoadingStatePanel } from '../LoadingStatePanel'
import { SectionLabel } from '../SectionRows'
import { StyledTextInput } from '../StyledTextInput'

const INSTALL_BLOCK_INPUT_WIDTH = 280
const TARGET_APPLICATION_SELECT_WIDTH =
  INSTALL_BLOCK_INPUT_WIDTH +
    ActionButtonStyles.HORIZONTAL_PADDING_START +
    ActionButtonStyles.ICON_SIZE +
    AppStyles.PADDING_SM +
    PermissionApplicationStrings.INSTALL_BLOCK_ACTION.length * ActionButtonStyles.FONT_SIZE +
    ActionButtonStyles.HORIZONTAL_PADDING_END +
    AppStyles.CONTROL_ROW_ACTION_GAP -
    (AppStyles.CONTROL_ROW_HORIZONTAL_PADDING - AppStyles.PADDING_MD)
const EMPTY_VERTICAL_PADDING = 28

@ComponentV2
export struct PermissionTargetPanel {
  @Param initialized: boolean = false
  @Param accounts: PermissionManagedAccount[] = []
  @Param selectedAccountId: number = 0
  @Param appSnapshots: PermissionAppSnapshot[] = []
  @Param filteredAppKeys: string[] = []
  @Param selectedAppKey: string = ''
  @Param installBlockKeyword: string = ''
  @Param inventoryMessage: string = ''
  @Param loading: boolean = false
  @Param loadingSelectedApp: boolean = false
  @Param processingActionKey: string = ''
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Event onSelectAccount: (accountId: number) => Promise<boolean> = async () => false
  @Event onSelectApplication: (appKey: string) => Promise<boolean> = async () => false
  @Event onInstallBlockKeywordChange: (value: string) => void = () => {}
  @Event onSubmitInstallBlock: () => void = () => {}

  build() {
    Column() {
      if (!this.initialized) {
        LoadingStatePanel({
          indicatorSize: 24,
          currentTheme: this.currentTheme
        })
          .height(128)
      } else {
        this.targetContent()
      }
    }
    .width('100%')
  }

  @Builder
  private targetContent() {
    AsyncSelectRow({
      label: PermissionAccountStrings.SELECT_TITLE,
      description: PermissionAccountStrings.SELECT_DESC,
      options: this.getAccountOptions(),
      selectedIndex: this.getSelectedAccountIndex(),
      selectWidth: AppStyles.SELECT_WIDTH_DEFAULT,
      processing: false,
      enabledValue: !this.loading &&
        this.accounts.length > 0 &&
        !this.hasProcessingAction() &&
        !this.loadingSelectedApp,
      currentTheme: this.currentTheme,
      onSelectAsync: async (index: number): Promise<boolean> => {
        let account = this.accounts[index]
        return account !== undefined ? await this.onSelectAccount(account.accountId) : false
      }
    })

    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    this.installBlockInputRow()

    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    if (this.filteredAppKeys.length === 0) {
      this.applicationInventoryEmptyText()
    } else {
      this.targetApplicationSelectRow()
    }
  }

  @Builder
  private targetApplicationSelectRow() {
    AsyncSelectRow({
      label: PermissionSectionStrings.TARGET_APPLICATION,
      description: PermissionSectionStrings.TARGET_APPLICATION_DESC,
      options: this.getApplicationOptions(),
      selectedIndex: this.getSelectedApplicationIndex(),
      selectWidth: TARGET_APPLICATION_SELECT_WIDTH,
      processing: this.loadingSelectedApp,
      enabledValue: !this.hasProcessingAction(),
      currentTheme: this.currentTheme,
      onSelectAsync: async (index: number): Promise<boolean> => {
        if (index <= 0) {
          return await this.onSelectApplication('')
        }
        let appKey = this.filteredAppKeys[index - 1]
        return appKey !== undefined ? await this.onSelectApplication(appKey) : false
      }
    })
  }

  @Builder
  private installBlockInputRow() {
    Row() {
      SectionLabel({
        title: PermissionApplicationStrings.INSTALL_BLOCK_TARGET,
        description: PermissionApplicationStrings.INSTALL_BLOCK_TARGET_DESC,
        currentTheme: this.currentTheme
      })

      Row({ space: 10 }) {
        StyledTextInput({
          text: this.installBlockKeyword,
          placeholder: PermissionApplicationStrings.INSTALL_BLOCK_PLACEHOLDER,
          controlWidth: INSTALL_BLOCK_INPUT_WIDTH,
          controlHeight: 36,
          radius: AppStyles.RADIUS_SM,
          enabledValue: !this.hasProcessingAction(),
          currentTheme: this.currentTheme,
          onChange: (value: string) => {
            this.onInstallBlockKeywordChange(value)
          }
        })

        if (this.isActionProcessing(this.getInstallActionKey())) {
          LoadingProgress()
            .width(AppStyles.INLINE_LOADING_INDICATOR_SIZE)
            .height(AppStyles.INLINE_LOADING_INDICATOR_SIZE)
            .color(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        }

        IconTextActionButton({
          label: PermissionApplicationStrings.INSTALL_BLOCK_ACTION,
          icon: AppResources.ALERT_ICON,
          kind: 'danger',
          isEnabled: this.canSubmitInstallBlock(),
          currentTheme: this.currentTheme,
          onTap: () => {
            this.onSubmitInstallBlock()
          }
        })
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({
      left: 16,
      right: 16,
      top: 14,
      bottom: 14
    })
  }

  @Builder
  private applicationInventoryEmptyText() {
    Text(this.getApplicationEmptyText())
      .width('100%')
      .fontSize(AppStyles.FONT_SIZE_BODY)
      .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
      .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
      .textAlign(TextAlign.Center)
      .padding({
        left: AppStyles.TABLE_HORIZONTAL_PADDING,
        right: AppStyles.TABLE_HORIZONTAL_PADDING,
        top: EMPTY_VERTICAL_PADDING,
        bottom: EMPTY_VERTICAL_PADDING
      })
  }

  private getAccountOptions(): string[] {
    return this.accounts.map((account: PermissionManagedAccount): string => account.displayName)
  }

  private getSelectedAccountIndex(): number {
    let index = this.accounts.findIndex((account: PermissionManagedAccount): boolean =>
      account.accountId === this.selectedAccountId
    )
    return index >= 0 ? index : 0
  }

  private getApplicationOptions(): string[] {
    let options: string[] = [PermissionSectionStrings.TARGET_APPLICATION_PLACEHOLDER]
    this.filteredAppKeys.forEach((appKey: string): void => {
      let snapshot = this.appSnapshots.find((item: PermissionAppSnapshot): boolean => item.appKey === appKey)
      if (snapshot !== undefined) {
        options.push(this.formatApplicationOption(snapshot))
      }
    })
    return options
  }

  private formatApplicationOption(snapshot: PermissionAppSnapshot): string {
    if (snapshot.label === snapshot.bundleName) {
      return snapshot.bundleName
    }
    return `${snapshot.label} (${snapshot.bundleName})`
  }

  private getSelectedApplicationIndex(): number {
    let index = this.filteredAppKeys.indexOf(this.selectedAppKey)
    return index >= 0 ? index + 1 : 0
  }

  private getApplicationEmptyText(): string {
    return this.inventoryMessage.length > 0 ? this.inventoryMessage : PermissionEmptyStrings.APPLICATIONS
  }

  private canSubmitInstallBlock(): boolean {
    return !this.hasProcessingAction() && this.installBlockKeyword.trim().length > 0
  }

  private hasProcessingAction(): boolean {
    return this.processingActionKey.length > 0
  }

  private isActionProcessing(actionKey: string): boolean {
    return this.processingActionKey === actionKey
  }

  private getInstallActionKey(): string {
    return 'install-deny'
  }
}
