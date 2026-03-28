import { IconTextActionButton } from '../IconTextActionButton'

@Component
export struct PageHeaderActions {
  @Prop exportLabel: string = '导出历史记录'
  @Prop clearLabel: string = '清理历史记录'
  @Prop showClear: boolean = true
  onExport?: () => void
  onClear?: () => void

  build() {
    Row({ space: 8 }) {
      IconTextActionButton({
        label: this.exportLabel,
        icon: $r('app.media.save'),
        kind: 'primary',
        onTap: () => this.onExport && this.onExport()
      })

      if (this.showClear) {
        IconTextActionButton({
          label: this.clearLabel,
          icon: $r('app.media.trash'),
          kind: 'danger',
          onTap: () => this.onClear && this.onClear()
        })
      }
    }
  }
}
