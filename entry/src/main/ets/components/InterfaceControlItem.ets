import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { HoverUtils } from '../utils/HoverUtils'
import { SymbolGlyphModifier, TextModifier } from '@kit.ArkUI'
import { FormControlUtils } from '../utils/FormControlUtils'

@Component
export struct InterfaceControlItem {
  @Prop label: string = ''
  @Prop description: string = ''
  @Prop options: string[] = []
  @Prop selectedIndex: number = 0
  @Prop isProcessing: boolean = false
  @Prop syncToken: number = 0
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  onSelect: (index: number) => void = () => {}
  @State isHovered: boolean = false

  @Builder
  private buildSelectControl(): void {
    Select(this.options.map((opt: string) => {
      let item: SelectOption = { value: opt }
      return item
    }))
      .selected(this.selectedIndex)
      .value(this.options[this.selectedIndex] ?? '')
      .fontColor(FormControlUtils.text(this.currentTheme))
      .textModifier(new TextModifier().fontColor(FormControlUtils.text(this.currentTheme)))
      .arrowModifier(new SymbolGlyphModifier().fontColor([FormControlUtils.selectArrow(this.currentTheme)]))
      .font({ size: AppStyles.FONT_SIZE_BODY })
      .backgroundColor(FormControlUtils.background(this.currentTheme))
      .borderRadius(AppStyles.RADIUS_MD)
      .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
      .enabled(!this.isProcessing)
      .opacity(this.isProcessing ? 0.6 : 1)
      .onSelect((index: number) => {
        this.onSelect(index)
      })
  }

  build() {
    Row() {
      Column({ space: 4 }) {
        Text(this.label)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        Text(this.description)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.syncToken % 2 === 0) {
        this.buildSelectControl()
      } else {
        this.buildSelectControl()
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .opacity(this.isProcessing ? 0.8 : 1)
    .translate({ y: HoverUtils.getTranslateY(this.isHovered, 2) })
    .onHover((isHover: boolean) => {
      HoverUtils.animate(() => {
        this.isHovered = isHover
      })
    })
  }
}
