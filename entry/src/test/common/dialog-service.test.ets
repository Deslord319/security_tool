import { describe, expect, it } from '@ohos/hypium'
import { MessageText } from '../../main/ets/constants/StringCatalog'
import { DialogService } from '../../main/ets/utils/DialogService'

interface DialogButtonLike {
  value: string
  fontColor: string
  action: () => void
}

interface AlertDialogOptionsLike {
  autoCancel: boolean
  title: string
  message: string
  primaryButton: DialogButtonLike
  secondaryButton?: DialogButtonLike
}

class RecordingUIContext {
  lastOptions?: AlertDialogOptionsLike

  async showAlertDialog(options: AlertDialogOptionsLike): Promise<void> {
    this.lastOptions = options
  }
}

class ThrowingUIContext {
  async showAlertDialog(_options: AlertDialogOptionsLike): Promise<void> {
    throw new Error('dialog failed')
  }
}

function asUIContext(value: Object): UIContext {
  return value as UIContext
}

export default function dialogServiceTest() {
  describe('DialogService', () => {
    it('should display fallback location and reason when values are empty', 0, () => {
      expect(DialogService.displayLocation('  ')).assertEqual(MessageText.RETRY_LATER)
      expect(DialogService.displayReason('')).assertEqual(MessageText.RETRY_LATER)
      expect(DialogService.displayReason('', 'fallback')).assertEqual('fallback')
    })

    it('should open confirm dialog and trigger callbacks', 0, async () => {
      let uiContext = new RecordingUIContext()
      let confirmed = 0
      let canceled = 0

      await DialogService.openConfirm(asUIContext(uiContext as Object), {
        title: 'confirm',
        message: 'message',
        onConfirm: () => {
          confirmed++
        },
        onCancel: () => {
          canceled++
        }
      })

      expect(uiContext.lastOptions?.title ?? '').assertEqual('confirm')
      uiContext.lastOptions?.primaryButton.action()
      uiContext.lastOptions?.secondaryButton?.action()
      expect(confirmed).assertEqual(1)
      expect(canceled).assertEqual(1)
    })

    it('should open result dialog and use status-aware defaults', 0, async () => {
      let uiContext = new RecordingUIContext()
      let acknowledged = 0

      await DialogService.openResult(asUIContext(uiContext as Object), {
        message: 'done',
        status: 'success',
        onConfirm: () => {
          acknowledged++
        }
      })

      expect(uiContext.lastOptions?.title ?? '').assertEqual(MessageText.SUCCESS_TITLE)
      uiContext.lastOptions?.primaryButton.action()
      expect(acknowledged).assertEqual(1)
    })

    it('should delegate success and failure helpers to result dialog', 0, async () => {
      let successContext = new RecordingUIContext()
      let failureContext = new RecordingUIContext()

      await DialogService.openSuccess(asUIContext(successContext as Object), 'success-message')
      await DialogService.openFailure(asUIContext(failureContext as Object), 'failure-message')

      expect(successContext.lastOptions?.message ?? '').assertEqual('success-message')
      expect(failureContext.lastOptions?.message ?? '').assertEqual('failure-message')
    })

    it('should swallow dialog exceptions', 0, async () => {
      let uiContext = new ThrowingUIContext()

      await DialogService.openConfirm(asUIContext(uiContext as Object), {
        title: 'confirm',
        message: 'message'
      })
      await DialogService.openResult(asUIContext(uiContext as Object), {
        message: 'result',
        status: 'failure'
      })

      expect(true).assertTrue()
    })
  })
}
