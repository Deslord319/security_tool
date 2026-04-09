import { LogUtils } from './LogUtils'

import { AppColors } from '../constants/AppConstants'
import { ActionText, MessageText } from '../constants/StringCatalog'
import { ThemeMode, getThemeColors } from '../theme/ThemeColors'

export type ActionDialogStatus = 'success' | 'failure'

const TAG = 'DialogService'
const LIGHT_THEME_COLORS = getThemeColors(ThemeMode.LIGHT)

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
    return value.length > 0 ? value : MessageText.RETRY_LATER
  }

  static displayReason(reason?: string, fallback: string = MessageText.RETRY_LATER): string {
    let value = reason?.trim() ?? ''
    return value.length > 0 ? value : fallback
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
          fontColor: `${LIGHT_THEME_COLORS.TEXT_PRIMARY}`,
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
