import { describe, expect, it } from '@ohos/hypium'
import { SystemSettingsService } from '../../main/ets/services/tool-settings/system-settings/SystemSettingsService'

export default function systemSettingsServiceTest() {
  describe('SystemSettingsService', () => {
    it('should expose openPasswordSettings as a callable action', 0, () => {
      expect(typeof SystemSettingsService.openPasswordSettings).assertEqual('function')
    })
  })
}
