import { AdminErrorCodes } from '../../../constants/SystemErrorCodes'
import { AdminText } from '../../../constants/StringCatalog'

export function buildAdminActivationErrorMessage(code?: number): string {
  return code === AdminErrorCodes.ADMIN_NOT_ACTIVATED
    ? AdminText.NOT_ACTIVATED
    : AdminText.buildCheckFailed(code)
}
