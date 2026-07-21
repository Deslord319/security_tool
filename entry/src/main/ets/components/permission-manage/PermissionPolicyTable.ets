import { ActionButtonStyles, AppColors, AppStyles } from '../../constants/AppConstants'
import {
  PermissionApplicationStrings,
  PermissionEmptyStrings
} from '../../constants/modules/PermissionStrings'
import { PermissionPolicyRecord } from '../../models/PermissionModels'
import { ThemeMode } from '../../theme/ThemeColors'
import { LoadingStatePanel } from '../LoadingStatePanel'

const POLICY_EMPTY_VERTICAL_PADDING = 28
const POLICY_ACTION_COLUMN_WIDTH = 88

@ComponentV2
export struct PermissionPolicyTable {
  @Param records: PermissionPolicyRecord[] = []
  @Param loadingSelectedApp: boolean = false
  @Param processingActionKey: string = ''
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Event onRequestDelete: (recordKey: string) => void = () => {}
  @Local private hoveredRecordKey: string = ''
  @Local private activeRecordKey: string = ''

  build() {
    Column() {
      if (this.loadingSelectedApp && this.records.length === 0) {
        LoadingStatePanel({
          indicatorSize: 22,
          currentTheme: this.currentTheme
        })
          .height(92)
      } else if (this.records.length === 0) {
        Text(PermissionEmptyStrings.POLICIES)
          .width('100%')
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          .textAlign(TextAlign.Center)
          .padding({
            left: AppStyles.TABLE_HORIZONTAL_PADDING,
            right: AppStyles.TABLE_HORIZONTAL_PADDING,
            top: POLICY_EMPTY_VERTICAL_PADDING,
            bottom: POLICY_EMPTY_VERTICAL_PADDING
          })
      } else {
        this.policyTable()
      }
    }
    .width('100%')
  }

  @Builder
  private policyTable() {
    Column({ space: 0 }) {
      this.policyTableHeader()
      ForEach(this.records, (record: PermissionPolicyRecord, index: number) => {
        Column({ space: 0 }) {
          this.policyTableRow(record)
          if (index < this.records.length - 1) {
            Divider()
              .color(AppColors.getColors(this.currentTheme).BORDER)
              .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
              .margin({
                left: AppStyles.TABLE_DIVIDER_MARGIN,
                right: AppStyles.TABLE_DIVIDER_MARGIN
              })
          }
        }
      }, (record: PermissionPolicyRecord): string => record.key)
    }
    .width('100%')
  }

  @Builder
  private policyTableHeader() {
    Row() {
      this.policyHeaderCell(PermissionApplicationStrings.POLICY_TABLE_TYPE, 1.15)
      this.policyHeaderCell(PermissionApplicationStrings.POLICY_TABLE_TARGET, 2.2)
      this.policyHeaderCell(PermissionApplicationStrings.POLICY_TABLE_STATUS, 0.9)
      this.policyHeaderCell(PermissionApplicationStrings.POLICY_TABLE_SCOPE, 1.1)
      this.policyActionHeaderCell(PermissionApplicationStrings.POLICY_TABLE_ACTION)
    }
    .width('100%')
    .padding({
      left: AppStyles.TABLE_HORIZONTAL_PADDING,
      right: AppStyles.TABLE_HORIZONTAL_PADDING,
      top: AppStyles.TABLE_HEADER_VERTICAL_PADDING,
      bottom: AppStyles.TABLE_HEADER_VERTICAL_PADDING
    })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }

  @Builder
  private policyHeaderCell(label: string, weight: number) {
    Text(label)
      .fontSize(AppStyles.FONT_SIZE_CAPTION)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
      .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .layoutWeight(weight)
  }

  @Builder
  private policyActionHeaderCell(label: string) {
    Text(label)
      .fontSize(AppStyles.FONT_SIZE_CAPTION)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
      .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .textAlign(TextAlign.Center)
      .width(POLICY_ACTION_COLUMN_WIDTH)
  }

  @Builder
  private policyTableRow(record: PermissionPolicyRecord) {
    Row() {
      this.policyTextCell(record.policyType, 1.15)
      this.policyTargetCell(record, 2.2)
      this.policyTextCell(record.statusLabel, 0.9)
      this.policyTextCell(record.scopeLabel, 1.1)
      this.policyDeleteActionCell(record)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({
      left: AppStyles.TABLE_HORIZONTAL_PADDING,
      right: AppStyles.TABLE_HORIZONTAL_PADDING,
      top: AppStyles.TABLE_ROW_VERTICAL_PADDING,
      bottom: AppStyles.TABLE_ROW_VERTICAL_PADDING
    })
  }

  @Builder
  private policyTextCell(value: string, weight: number) {
    Text(value)
      .fontSize(AppStyles.FONT_SIZE_BODY)
      .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
      .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .layoutWeight(weight)
  }

  @Builder
  private policyTargetCell(record: PermissionPolicyRecord, weight: number) {
    Column({ space: 2 }) {
      Text(record.targetName)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(record.targetDetail)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(weight)
  }

  @Builder
  private policyDeleteActionCell(record: PermissionPolicyRecord) {
    Row({ space: 6 }) {
      if (this.isActionProcessing(this.getDeletePolicyActionKey(record.key))) {
        LoadingProgress()
          .width(AppStyles.INLINE_LOADING_INDICATOR_SIZE)
          .height(AppStyles.INLINE_LOADING_INDICATOR_SIZE)
          .color(this.getDeleteButtonForeground())
      }

      Text(PermissionApplicationStrings.DELETE_POLICY_ACTION)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Regular)
        .fontColor(this.getDeleteButtonForeground())
    }
    .height(ActionButtonStyles.CHIP_HEIGHT)
    .padding({
      left: ActionButtonStyles.CHIP_HORIZONTAL_PADDING,
      right: ActionButtonStyles.CHIP_HORIZONTAL_PADDING
    })
    .justifyContent(FlexAlign.Center)
    .borderRadius(AppStyles.RADIUS_MD)
    .backgroundColor(this.getDeleteButtonBackground(record.key))
    .opacity(this.canOperateAction(this.getDeletePolicyActionKey(record.key)) ? 1 : 0.56)
    .width(POLICY_ACTION_COLUMN_WIDTH)
    .onHover((isHover: boolean) => {
      if (this.hasProcessingAction()) {
        return
      }
      this.hoveredRecordKey = isHover ? record.key : ''
    })
    .onTouch((event: TouchEvent) => {
      if (this.hasProcessingAction()) {
        return
      }
      if (event.type === TouchType.Down) {
        this.activeRecordKey = record.key
        return
      }
      if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.activeRecordKey = ''
      }
    })
    .onClick(() => {
      if (this.hasProcessingAction()) {
        return
      }
      this.activeRecordKey = ''
      this.onRequestDelete(record.key)
    })
  }

  private getDeletePolicyActionKey(recordKey: string): string {
    return `delete-policy:${recordKey}`
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

  private getDeleteButtonBackground(recordKey: string): ResourceColor {
    return ActionButtonStyles.getDangerBackground(
      this.currentTheme,
      this.hoveredRecordKey === recordKey && !this.hasProcessingAction(),
      this.activeRecordKey === recordKey && !this.hasProcessingAction()
    )
  }

  private getDeleteButtonForeground(): ResourceColor {
    return ActionButtonStyles.getDangerForeground(this.currentTheme)
  }
}
