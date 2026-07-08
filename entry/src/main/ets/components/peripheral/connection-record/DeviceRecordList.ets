import { ActionButtonStyles, AppColors, AppStyles } from '../../../constants/AppConstants'
import {
  PeripheralConnectionRecord,
  PeripheralType,
  isUsbPeripheralType
} from '../../../models/PeripheralModels'
import { LabelText } from '../../../constants/StringCatalog'
import { DeviceDetailStrings, PeripheralPageStrings } from '../../../constants/modules/PeripheralStrings'
import { ThemeMode } from '../../../theme/ThemeColors'
import { HoverUtils } from '../../../utils/HoverUtils'
import { getScrollBarColor, SCROLL_BAR_WIDTH_DEFAULT, SCROLL_BAR_WIDTH_HOVER } from '../../../utils/ScrollBarStyleUtils'
import {
  getPeripheralConnectionListPolicyLabel,
  getPeripheralConnectionActionLabel,
  formatPeripheralTimestamp,
  getPeripheralTypeLabel
} from '../../../viewmodels/peripheral/connection-record/PeripheralRecordPresentationMapper'
import { EmptyStatePanel } from '../../EmptyStatePanel'
import { EmptyStateStrings } from '../../../constants/modules/DialogStrings'
import { PeripheralDeviceIdentityCell, PeripheralHeaderCell, PeripheralTypeTag } from '../common/PeripheralTableCells'

@ComponentV2
export struct DeviceRecordList {
  @Param deviceRecords: PeripheralConnectionRecord[] = []
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Param hoveredPanelIndex: number = -1
  @Event onRecordClick?: (record: PeripheralConnectionRecord) => void
  @Event onPanelHover?: (isHover: boolean) => void
  @Local private activeDetailId: string = ''
  @Local private hoveredDetailId: string = ''
  @Local private scrollBarWidth: number = SCROLL_BAR_WIDTH_DEFAULT

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
                    .margin({
                      left: AppStyles.TABLE_DIVIDER_MARGIN,
                      right: AppStyles.TABLE_DIVIDER_MARGIN
                    })
                }
              }
            }, (record: PeripheralConnectionRecord) => record.id)
          }
          .width('100%')
          .borderRadius(AppStyles.RADIUS_LG)
          .clip(true)
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
          .border({ width: AppStyles.DIVIDER_HEIGHT, color: AppColors.getColors(this.currentTheme).BORDER })
          .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredPanelIndex === 1, true))
          .translate({ y: HoverUtils.getTranslateY(this.hoveredPanelIndex === 1, 4) })
          .onHover((isHover: boolean) => this.onPanelHover && this.onPanelHover(isHover))
        }
      }
      .width('100%')
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_SM, bottom: AppStyles.PADDING_MD })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .scrollBarColor(getScrollBarColor(this.currentTheme))
    .scrollBarWidth(this.scrollBarWidth)
    .onHover((isHover: boolean) => {
      this.scrollBarWidth = isHover ? SCROLL_BAR_WIDTH_HOVER : SCROLL_BAR_WIDTH_DEFAULT
    })
    .align(Alignment.Top)
  }

  @Builder
  private header() {
    Row() {
      PeripheralHeaderCell({ label: PeripheralPageStrings.DEVICE_NAME_LABEL, weight: 3.5, currentTheme: this.currentTheme })
      PeripheralHeaderCell({ label: PeripheralPageStrings.DEVICE_TYPE_LABEL, weight: 1.35, currentTheme: this.currentTheme })
      PeripheralHeaderCell({ label: DeviceDetailStrings.CONNECTION_EVENT, weight: 0.9, currentTheme: this.currentTheme })
      PeripheralHeaderCell({ label: PeripheralPageStrings.POLICY_LABEL, weight: 0.8, currentTheme: this.currentTheme })
      PeripheralHeaderCell({ label: PeripheralPageStrings.CONNECTION_TIME_LABEL, weight: 1.25, currentTheme: this.currentTheme })
      PeripheralHeaderCell({ label: PeripheralPageStrings.ACTION_LABEL, weight: 0.65, currentTheme: this.currentTheme })
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
  private row(record: PeripheralConnectionRecord) {
    Row() {
      PeripheralDeviceIdentityCell({
        deviceName: record.deviceName,
        deviceId: this.getDisplayDeviceId(record.deviceType, record.deviceId),
        currentTheme: this.currentTheme,
        weight: 3.5,
        deviceNameMaxLines: 2
      })

      PeripheralTypeTag({ label: this.getDeviceTypeLabel(record), weight: 1.35, currentTheme: this.currentTheme })

      Row() {
        Text(this.getActionLabel(record))
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.eventTextColor(record))
          .textAlign(TextAlign.Center)
      }
      .layoutWeight(0.9)
      .justifyContent(FlexAlign.Center)

      Row() {
        Text(this.getPolicyText(record))
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Regular)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          .textAlign(TextAlign.Center)
      }
      .layoutWeight(0.8)
      .justifyContent(FlexAlign.Center)

      Row() {
        Text(this.formatConnectionTime(record))
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          .textAlign(TextAlign.Center)
      }
      .layoutWeight(1.25)
      .justifyContent(FlexAlign.Center)

      Row() {
        Text(LabelText.DETAIL)
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
      .borderRadius(AppStyles.RADIUS_MD)
      .backgroundColor(this.getDetailButtonBackground(record.id))
      .layoutWeight(0.65)
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
    .padding({
      left: AppStyles.TABLE_HORIZONTAL_PADDING,
      right: AppStyles.TABLE_HORIZONTAL_PADDING,
      top: AppStyles.TABLE_ROW_VERTICAL_PADDING,
      bottom: AppStyles.TABLE_ROW_VERTICAL_PADDING
    })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .alignItems(VerticalAlign.Center)
  }

  private getDeviceTypeLabel(record: PeripheralConnectionRecord): string {
    return getPeripheralTypeLabel(record.deviceType)
  }

  private getActionLabel(record: PeripheralConnectionRecord): string {
    return getPeripheralConnectionActionLabel(record)
  }

  private formatConnectionTime(record: PeripheralConnectionRecord): string {
    return formatPeripheralTimestamp(record.timestamp)
  }

  private getPolicyText(record: PeripheralConnectionRecord): string {
    return getPeripheralConnectionListPolicyLabel(record)
  }

  private getDisplayDeviceId(deviceType: PeripheralType, deviceId: string): string {
    return isUsbPeripheralType(deviceType) ? '' : deviceId
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
