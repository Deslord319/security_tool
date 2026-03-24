/**
 * 外设策略列表组件
 */
import { AppColors, AppStyles } from '../../constants/AppConstants'
import { PeripheralPolicyRecord, PeripheralType, getPeripheralTypeLabel } from '../../models/DataModels'
import { ThemeMode } from '../../theme/ThemeColors'
import { FormControlUtils } from '../../utils/FormControlUtils'
import { EmptyStatePanel } from '../EmptyStatePanel'

interface PolicyListProps {
  policyRecords: PeripheralPolicyRecord[]
  policyListOptions: Array<{ value: string }>
  currentTheme: ThemeMode
  updatingKeys: string[]
  onPolicyChange: (index: number, policyIndex: number) => void
  getPolicyLabel: (index: number) => string
  isUpdating: (deviceId: string) => boolean
}

@Component
export struct PolicyList {
  @Prop policyRecords: PeripheralPolicyRecord[] = []
  @Prop policyListOptions: Array<{ value: string }> = []
  @Prop currentTheme: ThemeMode = ThemeMode.LIGHT
  @Prop updatingKeys: string[] = []
  onPolicyChange?: (index: number, policyIndex: number) => void
  getPolicyLabel?: (index: number) => string
  isUpdating?: (deviceId: string) => boolean

  build() {
    Scroll() {
      Column() {
        if (this.policyRecords.length === 0) {
          EmptyStatePanel({
            title: '暂无可管理的 USB 设备记录',
            description: '设备接入后会按最近记录去重展示，并可直接设置允许接入或禁止访问。',
            radius: AppStyles.RADIUS_LG,
            verticalPadding: 24
          })
        } else {
          Column({ space: 0 }) {
            this.tableHeader()

            Column({ space: 0 }) {
              ForEach(this.policyRecords, (record: PeripheralPolicyRecord, index: number) => {
                Column({ space: 0 }) {
                  this.tableRow(record, index)
                  if (index < this.policyRecords.length - 1) {
                    Divider()
                      .color(AppColors.getColors(this.currentTheme).BORDER)
                      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
                      .margin({ left: 20, right: 20 })
                  }
                }
              })
            }
            .width('100%')
          }
          .width('100%')
          .borderRadius(AppStyles.RADIUS_LG)
          .clip(true)
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
          .border({
            width: 1,
            color: AppColors.getColors(this.currentTheme).BORDER
          })
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD, bottom: AppStyles.PADDING_MD })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .align(Alignment.Top)
  }

  @Builder
  private tableHeader() {
    Row({ space: 12 }) {
      Text('设备名称')
        .fontSize(AppStyles.FONT_SIZE_SMALL)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .layoutWeight(1.8)
      Text('设备类型')
        .fontSize(AppStyles.FONT_SIZE_SMALL)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .layoutWeight(1.1)
      Text('设备标识')
        .fontSize(AppStyles.FONT_SIZE_SMALL)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .layoutWeight(1.6)
      Text('最近连接时间')
        .fontSize(AppStyles.FONT_SIZE_SMALL)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .layoutWeight(1.3)
      Text('当前策略')
        .fontSize(AppStyles.FONT_SIZE_SMALL)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .layoutWeight(1.2)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 14, bottom: 14 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }

  @Builder
  private tableRow(record: PeripheralPolicyRecord, index: number) {
    Row({ space: 12 }) {
      Text(record.deviceName)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        .layoutWeight(1.8)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Row() {
        Text(getPeripheralTypeLabel(record.deviceType))
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_TEXT)
          .backgroundColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_BG)
          .borderRadius(AppStyles.RADIUS_SM)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      }
      .layoutWeight(1.1)

      Text(record.deviceId)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        .layoutWeight(1.6)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(record.lastSeenLabel)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        .layoutWeight(1.3)

      Select(this.policyListOptions)
        .selected(record.policyIndex)
        .value(this.getPolicyLabel ? this.getPolicyLabel(record.policyIndex) : String(record.policyIndex))
        .font({ size: AppStyles.FONT_SIZE_CAPTION })
        .fontColor(FormControlUtils.text(this.currentTheme))
        .textModifier(new TextModifier().fontColor(FormControlUtils.text(this.currentTheme)))
        .arrowModifier(new SymbolGlyphModifier().fontColor([FormControlUtils.selectArrow(this.currentTheme)]))
        .selectedOptionFont({ size: AppStyles.FONT_SIZE_CAPTION })
        .optionFont({ size: AppStyles.FONT_SIZE_CAPTION })
        .backgroundColor(FormControlUtils.background(this.currentTheme))
        .borderRadius(AppStyles.RADIUS_SM)
        .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
        .layoutWeight(1.2)
        .enabled(!(this.isUpdating ? this.isUpdating(record.deviceId) : false))
        .opacity((this.isUpdating ? this.isUpdating(record.deviceId) : false) ? 0.6 : 1)
        .onSelect((selectIndex: number) => {
          if (this.onPolicyChange) {
            this.onPolicyChange(index, selectIndex)
          }
        })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 10, bottom: 10 })
    .backgroundColor(index % 2 === 0 ? AppColors.getColors(this.currentTheme).BG_CARD : AppColors.getColors(this.currentTheme).BG_PAGE)
  }
}
