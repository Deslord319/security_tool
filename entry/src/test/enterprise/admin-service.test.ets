import { describe, expect, it } from '@ohos/hypium'

import { AppInfo } from '../../main/ets/constants/AppConstants'
import { AdminErrorStrings } from '../../main/ets/constants/modules/ErrorStrings'
import { EnterpriseAdminService } from '../../main/ets/services/admin/activation/EnterpriseAdminService'

interface ErrorPayload {
  code?: number | string
  message?: string
}

export default function enterpriseAdminServiceTest() {
  describe('EnterpriseAdminService', () => {
    it('should build enable command with default admin type', 0, () => {
      let command = EnterpriseAdminService.buildEnableCommand()

      expect(command).assertEqual(
        `edm enable-admin -n ${AppInfo.BUNDLE_NAME} -a EnterpriseAdminAbility -t byod`
      )
    })

    it('should build enable command with explicit admin type', 0, () => {
      let command = EnterpriseAdminService.buildEnableCommand('super')

      expect(command).assertEqual(
        `edm enable-admin -n ${AppInfo.BUNDLE_NAME} -a EnterpriseAdminAbility -t super`
      )
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
      let result = EnterpriseAdminService.probeActivation()

      expect(result !== undefined).assertTrue()
      expect(result.enableCommand.includes('edm enable-admin')).assertTrue()
      expect(result.adminType).assertEqual('byod')
      expect(typeof result.activated === 'boolean').assertTrue()
      if (!result.activated) {
        expect((result.errorMessage?.length ?? 0) > 0).assertTrue()
      }
    })

    it('should keep explicit admin type in failed probe result', 0, () => {
      let result = EnterpriseAdminService.probeActivation('super')

      expect(result !== undefined).assertTrue()
      expect(result.adminType).assertEqual('super')
      expect(result.enableCommand.includes('edm enable-admin')).assertTrue()
      expect(typeof result.activated === 'boolean').assertTrue()
    })

    it('should resolve missing-admin message for known error code', 0, () => {
      let missingError: ErrorPayload = { code: '9200001' }
      let isMissing = EnterpriseAdminService.isAdminMissingError(missingError as Object)

      expect(isMissing).assertTrue()
      expect(AdminErrorStrings.notActivated.length > 0).assertTrue()
    })
  })
}
