import { LogUtils } from './LogUtils'
import { AppColors } from '../constants/AppConstants'
import { ActionText, MessageText } from '../constants/StringCatalog'
import { CommonLoadingDialog } from '../components/CommonLoadingDialog'
import { ThemeMode } from '../theme/ThemeColors'

export type ActionDialogStatus = 'success' | 'failure'

const TAG = 'DialogService'

export interface ConfirmDialogOptions {
  title: string
  message: string
  confirmText?: string
  cancelText?: string
  onConfirm?: () => void
  onCancel?: () => void
}

export interface ResultDialogOptions {
  title?: string
  message: string
  status: ActionDialogStatus
  confirmText?: string
  onConfirm?: () => void
}

export class DialogService {
  static displayReason(reason?: string, fallback: string = MessageText.RETRY_LATER): string {
    let value = reason?.trim() ?? ''
    return value.length > 0 ? value : fallback
  }

  static createLoadingController(message: string, currentTheme: ThemeMode): CustomDialogController {
    return new CustomDialogController({
      builder: CommonLoadingDialog({
        message: message,
        currentTheme: currentTheme
      }),
      alignment: DialogAlignment.Center,
      autoCancel: false,
      customStyle: true
    })
  }

  static closeController(controller?: CustomDialogController): CustomDialogController | undefined {
    try {
      controller?.close()
    } catch (_err) {
    }
    return undefined
  }

  static async openConfirm(uiContext: UIContext, options: ConfirmDialogOptions): Promise<void> {
    try {
      await uiContext.showAlertDialog({
        autoCancel: false,
        title: options.title,
        message: options.message,
        primaryButton: {
          value: options.confirmText ?? ActionText.CONTINUE,
          fontColor: `${AppColors.BRAND_PRIMARY}`,
          action: () => {
            options.onConfirm?.()
          }
        },
        secondaryButton: {
          value: options.cancelText ?? ActionText.CANCEL,
          action: () => {
            options.onCancel?.()
          }
        }
      })
    } catch (err) {
      LogUtils.error(TAG, `openConfirm failed: ${JSON.stringify(err)}`)
    }
  }

  static async openResult(uiContext: UIContext, options: ResultDialogOptions): Promise<void> {
    try {
      await uiContext.showAlertDialog({
        autoCancel: false,
        title: options.title ?? (options.status === 'success' ? MessageText.SUCCESS_TITLE : MessageText.FAILURE_TITLE),
        message: options.message,
        primaryButton: {
          value: options.confirmText ?? ActionText.ACKNOWLEDGE,
          fontColor: `${options.status === 'success' ? AppColors.BRAND_PRIMARY : AppColors.DANGER}`,
          action: () => {
            options.onConfirm?.()
          }
        }
      })
    } catch (err) {
      LogUtils.error(TAG, `openResult failed: ${JSON.stringify(err)}`)
    }
  }

  static async openSuccess(uiContext: UIContext, message: string, title?: string): Promise<void> {
    await DialogService.openResult(uiContext, {
      status: 'success',
      title: title,
      message: message
    })
  }

  static async openFailure(uiContext: UIContext, message: string, title?: string): Promise<void> {
    await DialogService.openResult(uiContext, {
      status: 'failure',
      title: title,
      message: message
    })
  }
}
