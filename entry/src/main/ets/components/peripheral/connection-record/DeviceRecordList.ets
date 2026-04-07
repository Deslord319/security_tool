import { ActionButtonStyles, AppColors, AppStyles } from '../../../constants/AppConstants'
import {
  getPeripheralRecordActionLabel,
  getPeripheralTypeLabel,
  PeripheralConnectionRecord
} from '../../../models/DataModels'
import { PeripheralStrings } from '../../../constants/modules/PeripheralStrings'
import { DeviceDetailStrings } from '../../../constants/modules/DialogStrings'
import { LogManageStrings } from '../../../constants/modules/LogManageStrings'
import { ThemeMode, getThemeColors } from '../../../theme/ThemeColors'
import { HoverUtils } from '../../../utils/HoverUtils'
import { getPeripheralConnectionPolicyLabel } from '../../../viewmodels/peripheral/connection-record/PeripheralRecordPresentationMapper'
import { EmptyStatePanel } from '../../EmptyStatePanel'
import { EmptyStateStrings } from '../../../constants/modules/DialogStrings'

@ComponentV2
export struct DeviceRecordList {
  @Param deviceRecords: PeripheralConnectionRecord[] = []
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Param hoveredPanelIndex: number = -1
  @Event onRecordClick?: (record: PeripheralConnectionRecord) => void
  @Event onPanelHover?: (isHover: boolean) => void
  @Local private activeDetailId: string = ''
  @Local private hoveredDetailId: string = ''

  private getDetailButtonBackground(recordId: string): ResourceColor {
    return ActionButtonStyles.getPrimaryBackground(
      this.currentTheme,
      this.hoveredDetailId === recordId,
      this.activeDetailId === recordId
    )
  }

  private getDetailButtonForeground(): ResourceColor {
    return ActionButtonStyles.getPrimaryForeground(this.currentTheme)
  }

  build() {
    Scroll() {
      Column({ space: 0 }) {
        if (this.deviceRecords.length === 0) {
          EmptyStatePanel({
            title: EmptyStateStrings.NO_RECORDS,
            description: EmptyStateStrings.CHECK_PERMISSIONS,
            radius: AppStyles.RADIUS_LG,
            verticalPadding: 24,
            currentTheme: this.currentTheme
          })
        } else {
          Column({ space: 0 }) {
            this.header()
            ForEach(this.deviceRecords, (record: PeripheralConnectionRecord, index: number) => {
              Column({ space: 0 }) {
                this.row(record)
                if (index < this.deviceRecords.length - 1) {
                  Divider()
                    .color(AppColors.getColors(this.currentTheme).BORDER)
                    .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
                    .margin({ left: 20, right: 20 })
                }
              }
            }, (record: PeripheralConnectionRecord) => record.id)
          }
          .width('100%')
          .borderRadius(AppStyles.RADIUS_LG)
          .clip(true)
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
          .border({ width: 1, color: AppColors.getColors(this.currentTheme).BORDER })
          .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredPanelIndex === 1, true))
          .translate({ y: HoverUtils.getTranslateY(this.hoveredPanelIndex === 1, 4) })
          .onHover((isHover: boolean) => this.onPanelHover && this.onPanelHover(isHover))
        }
      }
      .width('100%')
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD, bottom: AppStyles.PADDING_MD })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .align(Alignment.Top)
  }

  @Builder
  private header() {
    Row() {
      this.headerCell(PeripheralStrings.deviceNameLabel, 2.6)
      this.headerCell(PeripheralStrings.deviceTypeLabel, 1.5)
      this.headerCell(DeviceDetailStrings.CONNECTION_EVENT, 1.3)
      this.headerCell(PeripheralStrings.policyLabel, 1.2)
      this.headerCell(PeripheralStrings.connectionTimeLabel, 1.9)
      this.headerCell(PeripheralStrings.actionLabel, 1.0)
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 14, bottom: 14 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }

  @Builder
  private row(record: PeripheralConnectionRecord) {
    Row() {
      Column({ space: 6 }) {
        Text(record.deviceName)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(record.deviceId)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(2.6)

      this.typeTag(this.getDeviceTypeLabel(record), 1.5)

      Row() {
        Text(this.getActionLabel(record))
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.eventTextColor(record))
          .textAlign(TextAlign.Center)
      }
      .layoutWeight(1.3)
      .justifyContent(FlexAlign.Center)

      Row() {
        Text(this.getPolicyText(record))
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Regular)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          .textAlign(TextAlign.Center)
      }
      .layoutWeight(1.2)
      .justifyContent(FlexAlign.Center)

      Row() {
        Text(this.formatConnectionTime(record))
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          .textAlign(TextAlign.Center)
      }
      .layoutWeight(1.9)
      .justifyContent(FlexAlign.Center)

      Row() {
        Text(LogManageStrings.detailTitle)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Regular)
          .fontColor(this.getDetailButtonForeground())
      }
      .height(ActionButtonStyles.CHIP_HEIGHT)
      .padding({
        left: ActionButtonStyles.CHIP_HORIZONTAL_PADDING,
        right: ActionButtonStyles.CHIP_HORIZONTAL_PADDING
      })
      .justifyContent(FlexAlign.Center)
      .borderRadius(8)
      .backgroundColor(this.getDetailButtonBackground(record.id))
      .layoutWeight(1.0)
      .onHover((isHover: boolean) => {
        this.hoveredDetailId = isHover ? record.id : ''
      })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.activeDetailId = record.id
          return
        }
        if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.activeDetailId = ''
        }
      })
      .onClick(() => {
        this.activeDetailId = ''
        this.onRecordClick && this.onRecordClick(record)
      })
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 18, bottom: 18 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private headerCell(label: string, weight: number, textAlign: TextAlign = TextAlign.Center) {
    Text(label)
      .fontSize(AppStyles.FONT_SIZE_SMALL)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
      .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
      .layoutWeight(weight)
      .textAlign(textAlign)
  }

  @Builder
  private typeTag(label: string, weight: number) {
    Row() {
      Row() {
        Text(label)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .borderRadius(6)
      .backgroundColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_BG)
    }
    .layoutWeight(weight)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  private getDeviceTypeLabel(record: PeripheralConnectionRecord): string {
    return getPeripheralTypeLabel(record.deviceType)
  }

  private getActionLabel(record: PeripheralConnectionRecord): string {
    return getPeripheralRecordActionLabel(record.action)
  }

  private formatConnectionTime(record: PeripheralConnectionRecord): string {
    const date = new Date(record.timestamp)
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')} ${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}:${String(date.getSeconds()).padStart(2, '0')}`
  }

  private getPolicyText(record: PeripheralConnectionRecord): string {
    if (record.effectivePolicyLabel && record.effectivePolicyLabel.trim().length > 0) {
      return record.effectivePolicyLabel
    }
    return getPeripheralConnectionPolicyLabel(record)
  }

  private eventTextColor(record: PeripheralConnectionRecord): ResourceColor {
    if (record.action === 'connect') {
      return AppColors.getColors(this.currentTheme).TAG_GREEN_TEXT
    }
    if (record.action === 'disconnect') {
      return AppColors.getColors(this.currentTheme).TAG_ORANGE_TEXT
    }
    return AppColors.getColors(this.currentTheme).TAG_RED_TEXT
  }
}
