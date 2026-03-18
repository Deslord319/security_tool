import { ResultMessageBox, ResultMessageStatus } from '../components/ResultMessageBox'

export interface ResultDialogOptions {
  status: ResultMessageStatus
  message: string
  onConfirm?: () => void
  onClose?: () => void
}

export class ResultDialogHelper {
  static createController(options: ResultDialogOptions): CustomDialogController {
    return new CustomDialogController({
      builder: ResultMessageBox({
        status: options.status,
        message: options.message,
        onConfirm: () => {
          options.onConfirm?.()
        },
        onClose: () => {
          options.onClose?.()
        }
      }),
      alignment: DialogAlignment.Center,
      autoCancel: false,
      customStyle: true
    })
  }

  static displayLocation(directory?: string): string {
    let value = directory?.trim() ?? ''
    return value.length > 0 ? value : '未知位置'
  }

  static displayReason(reason?: string, fallback: string = '操作未完成，请稍后重试'): string {
    let value = reason?.trim() ?? ''
    return value.length > 0 ? value : fallback
  }
}
