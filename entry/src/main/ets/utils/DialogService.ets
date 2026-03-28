import { hilog } from '@kit.PerformanceAnalysisKit'
import { AppColors } from '../constants/AppConstants'
import { CommonStrings } from '../constants/CommonStrings'

export type ActionDialogStatus = 'success' | 'failure'

const TAG = 'DialogService'
const DOMAIN = 0x0018

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
  static displayLocation(directory?: string): string {
    let value = directory?.trim() ?? ''
    return value.length > 0 ? value : CommonStrings.messageRetryLater
  }

  static displayReason(reason?: string, fallback: string = CommonStrings.messageRetryLater): string {
    let value = reason?.trim() ?? ''
    return value.length > 0 ? value : fallback
  }

  static async openConfirm(uiContext: UIContext, options: ConfirmDialogOptions): Promise<void> {
    try {
      await uiContext.showAlertDialog({
        title: options.title,
        message: options.message,
        primaryButton: {
          value: options.confirmText ?? CommonStrings.actionContinue,
          fontColor: `${AppColors.BRAND_PRIMARY}`,
          action: () => {
            options.onConfirm?.()
          }
        },
        secondaryButton: {
          value: options.cancelText ?? CommonStrings.actionCancel,
          fontColor: `${AppColors.TEXT_PRIMARY}`,
          action: () => {
            options.onCancel?.()
          }
        }
      })
    } catch (err) {
      hilog.error(DOMAIN, TAG, `openConfirm failed: ${JSON.stringify(err)}`)
    }
  }

  static async openResult(uiContext: UIContext, options: ResultDialogOptions): Promise<void> {
    try {
      await uiContext.showAlertDialog({
        title: options.title ?? (options.status === 'success' ? CommonStrings.dialogSuccessTitle : CommonStrings.dialogFailureTitle),
        message: options.message,
        primaryButton: {
          value: options.confirmText ?? CommonStrings.actionAcknowledge,
          fontColor: `${options.status === 'success' ? AppColors.BRAND_PRIMARY : AppColors.DANGER}`,
          action: () => {
            options.onConfirm?.()
          }
        }
      })
    } catch (err) {
      hilog.error(DOMAIN, TAG, `openResult failed: ${JSON.stringify(err)}`)
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
