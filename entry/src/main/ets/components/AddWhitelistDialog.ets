import { AppColors, AppStyles } from '../constants/AppConstants'
import {
  formatLogTimestamp,
  getPeripheralCandidateSourceLabel,
  getPeripheralTypeLabel,
  PeripheralWhitelistCandidate
} from '../models/DataModels'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { FormControlUtils } from '../utils/FormControlUtils'

@CustomDialog
export struct AddWhitelistDialog {
  controller: CustomDialogController
  @State mode: string = 'usb'
  onConfirmUsb: (vendorId: number, productId: number, remark: string) => void = () => {}
  onConfirmBluetooth: (mac: string, remark: string) => void = () => {}
  getCandidates: () => PeripheralWhitelistCandidate[] = () => []
  emptyHint: string = '暂无可选设备，请使用手动录入。'

  @State manualMode: boolean = false
  @State selectedCandidateId: string = ''
  @State vendorIdText: string = ''
  @State productIdText: string = ''
  @State macAddress: string = ''
  @State remark: string = ''
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  aboutToAppear(): void {
    this.manualMode = false
    this.selectedCandidateId = ''
    this.vendorIdText = ''
    this.productIdText = ''
    this.macAddress = ''
    this.remark = ''
    this.selectFirstCandidate()
  }

  private parseHex(text: string): number {
    let trimmed = text.trim()
    if (trimmed.startsWith('0x') || trimmed.startsWith('0X')) {
      return parseInt(trimmed.substring(2), 16)
    }
    return parseInt(trimmed, 16)
  }

  private normalizeMac(mac: string): string {
    return mac.toUpperCase().replace(/-/g, ':').trim()
  }

  private getTitle(): string {
    return this.mode === 'usb' ? '添加 USB 白名单' : '添加蓝牙白名单'
  }

  private getSelectedCandidate(candidates: PeripheralWhitelistCandidate[]): PeripheralWhitelistCandidate | undefined {
    return candidates.find((candidate: PeripheralWhitelistCandidate) => candidate.id === this.selectedCandidateId)
  }

  private isCandidateSelected(candidate: PeripheralWhitelistCandidate): boolean {
    return candidate.id === this.selectedCandidateId
  }

  private selectFirstCandidate(): void {
    let candidates = this.getCandidates()
    let first = candidates.find((candidate: PeripheralWhitelistCandidate) => !candidate.disabled)
    this.selectedCandidateId = first ? first.id : ''
  }

  private submitSelection(candidates: PeripheralWhitelistCandidate[]): void {
    let selected = this.getSelectedCandidate(candidates)
    if (!selected || selected.disabled) {
      return
    }
    if (this.mode === 'usb') {
      if (selected.vendorId === undefined || selected.productId === undefined) {
        return
      }
      this.onConfirmUsb(selected.vendorId, selected.productId, this.remark)
    } else {
      let mac = selected.mac ? this.normalizeMac(selected.mac) : ''
      if (mac.length <= 0) {
        return
      }
      this.onConfirmBluetooth(mac, this.remark)
    }
    this.controller.close()
  }

  private submitManual(): void {
    if (this.mode === 'usb') {
      let vid = this.parseHex(this.vendorIdText)
      let pid = this.parseHex(this.productIdText)
      if (!isNaN(vid) && !isNaN(pid)) {
        this.onConfirmUsb(vid, pid, this.remark)
        this.controller.close()
      }
      return
    }

    let mac = this.normalizeMac(this.macAddress)
    if (mac.length > 0) {
      this.onConfirmBluetooth(mac, this.remark)
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
  private candidateItem(candidate: PeripheralWhitelistCandidate) {
    Row({ space: 12 }) {
      Column({ space: 6 }) {
        Row({ space: 8 }) {
          Text(candidate.deviceName)
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          Text(getPeripheralTypeLabel(candidate.deviceType))
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_TEXT)
            .backgroundColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_BG)
            .borderRadius(AppStyles.RADIUS_SM)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        }
        .width('100%')

        Text(candidate.deviceId)
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(
          `${getPeripheralCandidateSourceLabel(candidate.source)} · ${candidate.timestamp > 0 ? formatLogTimestamp(candidate.timestamp) : '--'}`
        )
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (candidate.disabled) {
        Text('已存在')
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      } else if (this.isCandidateSelected(candidate)) {
        Text('已选择')
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.BRAND_PRIMARY)
          .fontWeight(FontWeight.Medium)
      }
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .backgroundColor(
      this.isCandidateSelected(candidate) ? AppColors.getColors(this.currentTheme).BG_PAGE : AppColors.getColors(this.currentTheme).BG_CARD
    )
    .borderRadius(AppStyles.RADIUS_MD)
    .border({
      width: 1,
      color: this.isCandidateSelected(candidate) ? AppColors.BRAND_PRIMARY : AppColors.getColors(this.currentTheme).BORDER,
      style: BorderStyle.Solid
    })
    .opacity(candidate.disabled ? 0.45 : 1)
    .onClick(() => {
      if (candidate.disabled) {
        return
      }
      this.selectedCandidateId = candidate.id
    })
  }

  @Builder
  private manualForm() {
    if (this.mode === 'usb') {
      Column({ space: 12 }) {
        Column({ space: 6 }) {
          Text('Vendor ID')
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          TextInput({ placeholder: '例如: 0x2B7E', text: this.vendorIdText })
            .height(40)
            .fontColor(FormControlUtils.text(this.currentTheme))
            .placeholderColor(FormControlUtils.placeholder(this.currentTheme))
            .backgroundColor(FormControlUtils.background(this.currentTheme))
            .borderRadius(AppStyles.RADIUS_MD)
            .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
            .onChange((value: string) => {
              this.vendorIdText = value
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Column({ space: 6 }) {
          Text('Product ID')
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          TextInput({ placeholder: '例如: 0xB5A2', text: this.productIdText })
            .height(40)
            .fontColor(FormControlUtils.text(this.currentTheme))
            .placeholderColor(FormControlUtils.placeholder(this.currentTheme))
            .backgroundColor(FormControlUtils.background(this.currentTheme))
            .borderRadius(AppStyles.RADIUS_MD)
            .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
            .onChange((value: string) => {
              this.productIdText = value
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
    } else {
      Column({ space: 6 }) {
        Text('MAC 地址')
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        TextInput({ placeholder: '例如: AA:BB:CC:DD:EE:01', text: this.macAddress })
          .height(40)
          .fontColor(FormControlUtils.text(this.currentTheme))
          .placeholderColor(FormControlUtils.placeholder(this.currentTheme))
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .onChange((value: string) => {
            this.macAddress = value
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  build() {
    Column({ space: 16 }) {
      Row() {
        Text(this.getTitle())
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          .layoutWeight(1)
        Text('\u00D7')
          .fontSize(20)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          .onClick(() => {
            this.controller.close()
          })
      }
      .width('100%')

      Row({ space: 8 }) {
        this.modeSwitchButton('候选列表', !this.manualMode, () => {
          this.manualMode = false
          if (this.selectedCandidateId.length <= 0) {
            this.selectFirstCandidate()
          }
        })
        this.modeSwitchButton('手动录入', this.manualMode, () => {
          this.manualMode = true
        })
      }
      .width('100%')

      if (!this.manualMode) {
        Text('优先从当前候选中选择设备，手动录入仅作为兜底方式。')
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)

        if (this.getCandidates().length <= 0) {
          Column({ space: 8 }) {
            Text('暂无候选设备')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            Text(this.emptyHint)
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
              ForEach(this.getCandidates(), (candidate: PeripheralWhitelistCandidate) => {
                this.candidateItem(candidate)
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
        Text('备注')
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        TextInput({ placeholder: '设备备注信息', text: this.remark })
          .height(40)
          .fontColor(FormControlUtils.text(this.currentTheme))
          .placeholderColor(FormControlUtils.placeholder(this.currentTheme))
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .onChange((value: string) => {
            this.remark = value
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
          .opacity(!this.manualMode && !this.getSelectedCandidate(this.getCandidates()) ? 0.55 : 1)
          .onClick(() => {
            if (this.manualMode) {
              this.submitManual()
              return
            }
            this.submitSelection(this.getCandidates())
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
