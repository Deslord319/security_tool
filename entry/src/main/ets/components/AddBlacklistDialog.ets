import { AppColors, AppStyles } from '../constants/AppConstants'
import { PeripheralBlacklistTemplate } from '../models/DataModels'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { FormControlUtils } from '../utils/FormControlUtils'

@CustomDialog
export struct AddBlacklistDialog {
  controller: CustomDialogController
  onConfirm: (baseClass: number, subClass: number, protocol: number, description: string) => void = () => {}
  getTemplates: () => PeripheralBlacklistTemplate[] = () => []

  @State manualMode: boolean = false
  @State selectedTemplateId: string = ''
  @State baseClassText: string = ''
  @State subClassText: string = ''
  @State protocolText: string = ''
  @State description: string = ''
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  aboutToAppear(): void {
    this.manualMode = false
    this.selectedTemplateId = ''
    this.baseClassText = ''
    this.subClassText = ''
    this.protocolText = ''
    this.description = ''
    this.selectFirstTemplate()
  }

  private parseHex(text: string): number {
    let trimmed = text.trim()
    if (trimmed.startsWith('0x') || trimmed.startsWith('0X')) {
      return parseInt(trimmed.substring(2), 16)
    }
    return parseInt(trimmed, 16)
  }

  private formatHex(value: number): string {
    return '0x' + value.toString(16).toUpperCase().padStart(2, '0')
  }

  private selectFirstTemplate(): void {
    let templates = this.getTemplates()
    let first = templates.find((item: PeripheralBlacklistTemplate) => !item.disabled)
    this.selectedTemplateId = first ? first.id : ''
  }

  private getSelectedTemplate(templates: PeripheralBlacklistTemplate[]): PeripheralBlacklistTemplate | undefined {
    return templates.find((item: PeripheralBlacklistTemplate) => item.id === this.selectedTemplateId)
  }

  private isTemplateSelected(item: PeripheralBlacklistTemplate): boolean {
    return item.id === this.selectedTemplateId
  }

  private submitSelection(templates: PeripheralBlacklistTemplate[]): void {
    let selected = this.getSelectedTemplate(templates)
    if (!selected || selected.disabled) {
      return
    }
    this.onConfirm(selected.baseClass, selected.subClass, selected.protocol, selected.description)
    this.controller.close()
  }

  private submitManual(): void {
    let bc = this.parseHex(this.baseClassText)
    let sc = this.parseHex(this.subClassText)
    let pr = this.parseHex(this.protocolText)
    if (!isNaN(bc) && !isNaN(sc) && !isNaN(pr)) {
      this.onConfirm(bc, sc, pr, this.description)
      this.controller.close()
    }
  }

  @Builder
  private modeSwitchButton(label: string, active: boolean, onTap: () => void) {
    Text(label)
      .fontSize(AppStyles.FONT_SIZE_BODY)
      .fontWeight(active ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(active ? AppColors.BRAND_PRIMARY : AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
      .opacity(active ? 1 : AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .backgroundColor(active ? AppColors.getColors(this.currentTheme).BG_PAGE : AppColors.getColors(this.currentTheme).BG_CARD)
      .borderRadius(AppStyles.RADIUS_SM)
      .onClick(() => {
        onTap()
      })
  }

  @Builder
  private templateItem(item: PeripheralBlacklistTemplate) {
    Row({ space: 12 }) {
      Column({ space: 6 }) {
        Row({ space: 8 }) {
          Text(item.title)
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (item.fromConnectedDevice) {
            Text('当前设备')
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontColor(AppColors.BRAND_PRIMARY)
              .backgroundColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_BG)
              .borderRadius(AppStyles.RADIUS_SM)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          }
        }
        .width('100%')

        Text(`${this.formatHex(item.baseClass)} / ${this.formatHex(item.subClass)} / ${this.formatHex(item.protocol)}`)
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)

        Text(item.description)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (item.disabled) {
        Text('已存在')
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      } else if (this.isTemplateSelected(item)) {
        Text('已选择')
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.BRAND_PRIMARY)
          .fontWeight(FontWeight.Medium)
      }
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .backgroundColor(
      this.isTemplateSelected(item) ? AppColors.getColors(this.currentTheme).BG_PAGE : AppColors.getColors(this.currentTheme).BG_CARD
    )
    .borderRadius(AppStyles.RADIUS_MD)
    .border({
      width: 1,
      color: this.isTemplateSelected(item) ? AppColors.BRAND_PRIMARY : AppColors.getColors(this.currentTheme).BORDER,
      style: BorderStyle.Solid
    })
    .opacity(item.disabled ? 0.45 : 1)
    .onClick(() => {
      if (item.disabled) {
        return
      }
      this.selectedTemplateId = item.id
      this.description = item.description
    })
  }

  @Builder
  private manualForm() {
    Column({ space: 12 }) {
      Column({ space: 6 }) {
        Text('Base Class')
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        TextInput({ placeholder: '例如: 0x08', text: this.baseClassText })
          .height(40)
          .fontColor(FormControlUtils.text(this.currentTheme))
          .placeholderColor(FormControlUtils.placeholder(this.currentTheme))
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .onChange((value: string) => {
            this.baseClassText = value
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 6 }) {
        Text('Sub Class')
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        TextInput({ placeholder: '例如: 0x06', text: this.subClassText })
          .height(40)
          .fontColor(FormControlUtils.text(this.currentTheme))
          .placeholderColor(FormControlUtils.placeholder(this.currentTheme))
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .onChange((value: string) => {
            this.subClassText = value
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 6 }) {
        Text('Protocol')
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        TextInput({ placeholder: '例如: 0x50', text: this.protocolText })
          .height(40)
          .fontColor(FormControlUtils.text(this.currentTheme))
          .placeholderColor(FormControlUtils.placeholder(this.currentTheme))
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .onChange((value: string) => {
            this.protocolText = value
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
  }

  build() {
    Column({ space: 16 }) {
      Row() {
        Text('添加 USB 黑名单')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          .layoutWeight(1)
        Text('×')
          .fontSize(20)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          .onClick(() => {
            this.controller.close()
          })
      }
      .width('100%')

      Row({ space: 8 }) {
        this.modeSwitchButton('类型模板', !this.manualMode, () => {
          this.manualMode = false
          if (this.selectedTemplateId.length <= 0) {
            this.selectFirstTemplate()
          }
        })
        this.modeSwitchButton('高级录入', this.manualMode, () => {
          this.manualMode = true
        })
      }
      .width('100%')

      if (!this.manualMode) {
        Text('优先选择当前 USB 设备或常用类型模板，高级录入用于补充特殊三元组。')
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)

        if (this.getTemplates().length <= 0) {
          Column({ space: 8 }) {
            Text('暂无可用模板')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            Text('当前没有可推导的 USB 设备类型，请改用高级录入。')
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .padding({ top: 20, bottom: 20, left: 16, right: 16 })
          .alignItems(HorizontalAlign.Center)
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
          .borderRadius(AppStyles.RADIUS_MD)
        } else {
          Scroll() {
            Column({ space: 10 }) {
              ForEach(this.getTemplates(), (item: PeripheralBlacklistTemplate) => {
                this.templateItem(item)
              })
            }
            .width('100%')
          }
          .width('100%')
          .height(280)
        }
      } else {
        this.manualForm()
      }

      Column({ space: 6 }) {
        Text('描述')
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        TextInput({ placeholder: '例如: USB 大容量存储设备', text: this.description })
          .height(40)
          .fontColor(FormControlUtils.text(this.currentTheme))
          .placeholderColor(FormControlUtils.placeholder(this.currentTheme))
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .onChange((value: string) => {
            this.description = value
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row({ space: 16 }) {
        Button('取消')
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: 1, color: AppColors.getColors(this.currentTheme).BORDER, style: BorderStyle.Solid })
          .layoutWeight(1)
          .height(40)
          .onClick(() => {
            this.controller.close()
          })

        Button('添加')
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(Color.White)
          .backgroundColor(AppColors.BRAND_PRIMARY)
          .borderRadius(AppStyles.RADIUS_MD)
          .layoutWeight(1)
          .height(40)
          .opacity(!this.manualMode && !this.getSelectedTemplate(this.getTemplates()) ? 0.55 : 1)
          .onClick(() => {
            if (this.manualMode) {
              this.submitManual()
              return
            }
            this.submitSelection(this.getTemplates())
          })
      }
      .width('100%')
    }
    .padding(32)
    .constraintSize({ maxWidth: 640 })
    .width('92%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_XL)
  }
}
