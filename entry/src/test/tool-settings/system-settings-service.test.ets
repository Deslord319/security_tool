import { describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { SystemSettingsService } from '../../main/ets/services/tool-settings/system-settings/SystemSettingsService'

export default function systemSettingsServiceTest() {
  describe('SystemSettingsService', () => {
    it('should return false when password settings cannot be opened in unit test env', 0, async (done: Function) => {
      let opened = await SystemSettingsService.openPasswordSettings({} as common.UIAbilityContext)
      expect(opened).assertFalse()
      done()
    })
  })
}
