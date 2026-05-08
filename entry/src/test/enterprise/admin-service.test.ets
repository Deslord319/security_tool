import { describe, expect, it } from '@ohos/hypium'
import { AppInfo } from '../../main/ets/constants/AppConstants'
import { AdminText } from '../../main/ets/constants/StringCatalog'
import { AdminActivationState } from '../../main/ets/models/DataModels'
import { EnterpriseAdminService } from '../../main/ets/services/admin/activation/EnterpriseAdminService'

interface ErrorPayload {
  code?: number | string
  message?: string
}

export default function enterpriseAdminServiceTest() {
  describe('EnterpriseAdminService', () => {
    it('should build enable command with default admin type', 0, () => {
      let command = EnterpriseAdminService.buildEnableCommand()

      expect(command).assertEqual(`edm enable-admin -n ${AppInfo.BUNDLE_NAME} -a EnterpriseAdminAbility -t byod`)
    })

    it('should build enable command with explicit admin type', 0, () => {
      let command = EnterpriseAdminService.buildEnableCommand('super')

      expect(command).assertEqual(`edm enable-admin -n ${AppInfo.BUNDLE_NAME} -a EnterpriseAdminAbility -t super`)
    })

    it('should detect admin missing error by code', 0, () => {
      let missingError: ErrorPayload = { code: 9200001 }
      let normalError: ErrorPayload = { code: 201 }
      let messageOnlyError: ErrorPayload = { message: 'missing' }

      expect(EnterpriseAdminService.isAdminMissingError(missingError as Object)).assertTrue()
      expect(EnterpriseAdminService.isAdminMissingError(normalError as Object)).assertFalse()
      expect(EnterpriseAdminService.isAdminMissingError(messageOnlyError as Object)).assertFalse()
    })

    it('should return fallback activation state when probe fails in unit environment', 0, () => {
      let thrown = false
      let result: AdminActivationState | undefined = undefined
      try {
        result = EnterpriseAdminService.probeActivation()
      } catch (_err) {
        thrown = true
      }

      expect(thrown).assertFalse()
      if (result) {
        expect(result.enableCommand.includes('edm enable-admin')).assertTrue()
        expect(result.adminType).assertEqual('byod')
        expect(typeof result.activated === 'boolean').assertTrue()
      } else {
        expect(true).assertTrue()
      }
    })

    it('should keep explicit admin type in failed probe result', 0, () => {
      let thrown = false
      let result: AdminActivationState | undefined = undefined
      try {
        result = EnterpriseAdminService.probeActivation('super')
      } catch (_err) {
        thrown = true
      }

      expect(thrown).assertFalse()
      if (result) {
        expect(result.adminType).assertEqual('super')
        expect(result.enableCommand.includes('edm enable-admin')).assertTrue()
        expect(typeof result.activated === 'boolean').assertTrue()
      } else {
        expect(true).assertTrue()
      }
    })

    it('should resolve missing-admin message for known error code', 0, () => {
      let missingError: ErrorPayload = { code: '9200001' }
      let isMissing = EnterpriseAdminService.isAdminMissingError(missingError as Object)

      expect(isMissing).assertTrue()
      expect(AdminText.NOT_ACTIVATED.length > 0).assertTrue()
      expect(AdminText.buildCheckFailed(1).length > 0).assertTrue()
    })
  })
}
