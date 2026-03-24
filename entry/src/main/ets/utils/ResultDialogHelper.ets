import { ResultMessageStatus } from '../components/ResultMessageBox'

export const STORAGE_KEY_RESULT_DIALOG_STATUS: string = 'result_dialog_status'
export const STORAGE_KEY_RESULT_DIALOG_MESSAGE: string = 'result_dialog_message'
export const STORAGE_KEY_RESULT_DIALOG_BUTTON: string = 'result_dialog_button'

export class ResultDialogHelper {
  static prepareResultDialog(status: ResultMessageStatus, message: string, buttonText: string = '我知道了'): void {
    AppStorage.setOrCreate<string>(STORAGE_KEY_RESULT_DIALOG_STATUS, status)
    AppStorage.setOrCreate<string>(STORAGE_KEY_RESULT_DIALOG_MESSAGE, message)
    AppStorage.setOrCreate<string>(STORAGE_KEY_RESULT_DIALOG_BUTTON, buttonText)
  }

  static openAlertDialog(uiContext: UIContext, status: ResultMessageStatus, message: string): void {
    void uiContext.showAlertDialog({
      title: status === 'success' ? '操作成功' : '操作失败',
      message: message,
      primaryButton: {
        value: '我知道了',
        action: () => {}
      }
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
