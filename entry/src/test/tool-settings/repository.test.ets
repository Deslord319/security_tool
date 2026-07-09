import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { AuthMethod } from '../../main/ets/models/AuthModels'
import { DEFAULT_TOOL_SETTINGS } from '../../main/ets/models/ToolSettingsModels'
import { PreferencesAccessor } from '../../main/ets/storage/preferences/PreferencesAccessor'
import { PreferencesToolSettingsRepository } from '../../main/ets/services/tool-settings/system-settings/ToolSettingsRepository'

interface FakePrefWriteItem {
  key: string
  value: Object
}

class FakeBusinessError extends Error {
  code: number = 0

  constructor(code: number, message: string) {
    super(message)
    this.code = code
    this.name = 'BusinessError'
  }
}

class FakePreferencesAccessor {
  private values: Map<string, Object> = new Map<string, Object>()
  failOnGet: boolean = false
  failOnSetMany: boolean = false
  setManyResult: boolean = true
  throwBusinessError: boolean = false

  async getBoolean(key: string, defaultValue: boolean): Promise<boolean> {
    if (this.failOnGet) {
      if (this.throwBusinessError) {
        throw new FakeBusinessError(15000001, 'preferences get failed')
      }
      throw new Error('fake_get_failed')
    }
    let val = this.values.get(key)
    return val !== undefined ? val as boolean : defaultValue
  }

  async getNumber(key: string, defaultValue: number): Promise<number> {
    if (this.failOnGet) {
      if (this.throwBusinessError) {
        throw new FakeBusinessError(15000002, 'preferences get failed')
      }
      throw new Error('fake_get_failed')
    }
    let val = this.values.get(key)
    return val !== undefined ? val as number : defaultValue
  }

  async setMany(items: FakePrefWriteItem[], _flush?: boolean): Promise<boolean> {
    if (this.failOnSetMany) {
      if (this.throwBusinessError) {
        throw new FakeBusinessError(15000003, 'preferences set failed')
      }
      throw new Error('fake_set_many_failed')
    }
    if (!this.setManyResult) {
      return false
    }
    for (let item of items) {
      this.values.set(item.key, item.value)
    }
    return true
  }

  set(key: string, value: Object): void {
    this.values.set(key, value)
  }
}

export default function toolSettingsRepositoryTest() {
  describe('PreferencesToolSettingsRepository', () => {
    let mockKit: MockKit
    let fakeAccessor: FakePreferencesAccessor

    beforeEach(() => {
      mockKit = new MockKit()
      fakeAccessor = new FakePreferencesAccessor()
    })

    afterEach(() => {
      mockKit.clearAll()
    })

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

    it('should load config with PIN auth method', 0, async (done: Function) => {
      fakeAccessor.set('startup_auth_enabled', true)
      fakeAccessor.set('auth_method', AuthMethod.PIN)

      let ofMock = mockKit.mockFunc(PreferencesAccessor, PreferencesAccessor.of)
      when(ofMock)(ArgumentMatchers.any).afterReturn(fakeAccessor as never as PreferencesAccessor)

      let repository = new PreferencesToolSettingsRepository()
      let config = await repository.loadConfig({} as common.UIAbilityContext)

      expect(config.startupAuthEnabled).assertTrue()
      expect(config.authMethod).assertEqual(AuthMethod.PIN)
      done()
    })

    it('should load config with FINGERPRINT auth method', 0, async (done: Function) => {
      fakeAccessor.set('startup_auth_enabled', false)
      fakeAccessor.set('auth_method', AuthMethod.FINGERPRINT)

      let ofMock = mockKit.mockFunc(PreferencesAccessor, PreferencesAccessor.of)
      when(ofMock)(ArgumentMatchers.any).afterReturn(fakeAccessor as never as PreferencesAccessor)

      let repository = new PreferencesToolSettingsRepository()
      let config = await repository.loadConfig({} as common.UIAbilityContext)

      expect(config.startupAuthEnabled).assertFalse()
      expect(config.authMethod).assertEqual(AuthMethod.FINGERPRINT)
      done()
    })

    it('should normalize unknown auth method to default', 0, async (done: Function) => {
      fakeAccessor.set('startup_auth_enabled', false)
      fakeAccessor.set('auth_method', 999)

      let ofMock = mockKit.mockFunc(PreferencesAccessor, PreferencesAccessor.of)
      when(ofMock)(ArgumentMatchers.any).afterReturn(fakeAccessor as never as PreferencesAccessor)

      let repository = new PreferencesToolSettingsRepository()
      let config = await repository.loadConfig({} as common.UIAbilityContext)

      expect(config.authMethod).assertEqual(DEFAULT_TOOL_SETTINGS.authMethod)
      done()
    })

    it('should return default config when loadConfig throws', 0, async (done: Function) => {
      fakeAccessor.failOnGet = true

      let ofMock = mockKit.mockFunc(PreferencesAccessor, PreferencesAccessor.of)
      when(ofMock)(ArgumentMatchers.any).afterReturn(fakeAccessor as never as PreferencesAccessor)

      let repository = new PreferencesToolSettingsRepository()
      let config = await repository.loadConfig({} as common.UIAbilityContext)

      expect(config.startupAuthEnabled).assertEqual(DEFAULT_TOOL_SETTINGS.startupAuthEnabled)
      expect(config.authMethod).assertEqual(DEFAULT_TOOL_SETTINGS.authMethod)
      done()
    })

    it('should throw when loadConfigStrict cannot read preferences', 0, async (done: Function) => {
      fakeAccessor.failOnGet = true

      let ofMock = mockKit.mockFunc(PreferencesAccessor, PreferencesAccessor.of)
      when(ofMock)(ArgumentMatchers.any).afterReturn(fakeAccessor as never as PreferencesAccessor)

      let repository = new PreferencesToolSettingsRepository()
      let threw = false
      try {
        await repository.loadConfigStrict({} as common.UIAbilityContext)
      } catch (err) {
        threw = true
        expect((err as Error).message).assertEqual('fake_get_failed')
      }

      expect(threw).assertTrue()
      done()
    })

    it('should save config successfully', 0, async (done: Function) => {
      let ofMock = mockKit.mockFunc(PreferencesAccessor, PreferencesAccessor.of)
      when(ofMock)(ArgumentMatchers.any).afterReturn(fakeAccessor as never as PreferencesAccessor)

      let repository = new PreferencesToolSettingsRepository()
      let saved = await repository.saveConfig({} as common.UIAbilityContext, {
        startupAuthEnabled: true,
        authMethod: AuthMethod.FINGERPRINT
      })

      expect(saved).assertTrue()
      done()
    })

    it('should return false when setMany returns false', 0, async (done: Function) => {
      fakeAccessor.setManyResult = false

      let ofMock = mockKit.mockFunc(PreferencesAccessor, PreferencesAccessor.of)
      when(ofMock)(ArgumentMatchers.any).afterReturn(fakeAccessor as never as PreferencesAccessor)

      let repository = new PreferencesToolSettingsRepository()
      let saved = await repository.saveConfig({} as common.UIAbilityContext, {
        startupAuthEnabled: true,
        authMethod: AuthMethod.FINGERPRINT
      })

      expect(saved).assertFalse()
      done()
    })

    it('should return false when saveConfig throws', 0, async (done: Function) => {
      fakeAccessor.failOnSetMany = true

      let ofMock = mockKit.mockFunc(PreferencesAccessor, PreferencesAccessor.of)
      when(ofMock)(ArgumentMatchers.any).afterReturn(fakeAccessor as never as PreferencesAccessor)

      let repository = new PreferencesToolSettingsRepository()
      let saved = await repository.saveConfig({} as common.UIAbilityContext, {
        startupAuthEnabled: true,
        authMethod: AuthMethod.FINGERPRINT
      })

      expect(saved).assertFalse()
      done()
    })

    it('should return default config when loadConfig throws BusinessError', 0, async (done: Function) => {
      fakeAccessor.failOnGet = true
      fakeAccessor.throwBusinessError = true

      let ofMock = mockKit.mockFunc(PreferencesAccessor, PreferencesAccessor.of)
      when(ofMock)(ArgumentMatchers.any).afterReturn(fakeAccessor as never as PreferencesAccessor)

      let repository = new PreferencesToolSettingsRepository()
      let config = await repository.loadConfig({} as common.UIAbilityContext)

      expect(config.startupAuthEnabled).assertEqual(DEFAULT_TOOL_SETTINGS.startupAuthEnabled)
      expect(config.authMethod).assertEqual(DEFAULT_TOOL_SETTINGS.authMethod)
      done()
    })

    it('should return false when saveConfig throws BusinessError', 0, async (done: Function) => {
      fakeAccessor.failOnSetMany = true
      fakeAccessor.throwBusinessError = true

      let ofMock = mockKit.mockFunc(PreferencesAccessor, PreferencesAccessor.of)
      when(ofMock)(ArgumentMatchers.any).afterReturn(fakeAccessor as never as PreferencesAccessor)

      let repository = new PreferencesToolSettingsRepository()
      let saved = await repository.saveConfig({} as common.UIAbilityContext, {
        startupAuthEnabled: true,
        authMethod: AuthMethod.FINGERPRINT
      })

      expect(saved).assertFalse()
      done()
    })
  })
}
