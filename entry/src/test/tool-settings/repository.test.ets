import { describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { AuthMethod } from '../../main/ets/models/DataModels'
import { PreferencesToolSettingsRepository } from '../../main/ets/services/tool-settings/system-settings/ToolSettingsRepository'

export default function toolSettingsRepositoryTest() {
  describe('PreferencesToolSettingsRepository', () => {
    it('should load a normalized config shape in unit test env', 0, async (done: Function) => {
      let repository = new PreferencesToolSettingsRepository()

      let config = await repository.loadConfig({} as common.UIAbilityContext)

      expect(typeof config.startupAuthEnabled).assertEqual('boolean')
      expect(config.authMethod === AuthMethod.PIN || config.authMethod === AuthMethod.FINGERPRINT).assertTrue()
      done()
    })

    it('should return a stable boolean result when saving config in unit test env', 0, async (done: Function) => {
      let repository = new PreferencesToolSettingsRepository()

      let saved = await repository.saveConfig({} as common.UIAbilityContext, {
        startupAuthEnabled: true,
        authMethod: AuthMethod.FINGERPRINT
      })

      expect(typeof saved).assertEqual('boolean')
      done()
    })
  })
}
