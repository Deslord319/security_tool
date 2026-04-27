import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import EntryAbility from '../../main/ets/entryability/EntryAbility'
import {
  ACCOUNT_EVENT_PARAM_TIMESTAMP,
  ACCOUNT_EVENT_PARAM_TYPE,
  ACCOUNT_EVENT_PARAM_USER_ID,
  AccountEventType
} from '../../main/ets/contracts/AccountEventContract'
import { AuthMethod } from '../../main/ets/models/DataModels'
import { SystemUserProvider } from '../../main/ets/services/firewall/providers/SystemUserProvider'
import { AuthAvailabilityResult, AuthExecutionResult, AuthService } from '../../main/ets/services/identity/auth/AuthService'
import { PreferencesToolSettingsRepository } from '../../main/ets/services/tool-settings/system-settings/ToolSettingsRepository'
import { ThemeManager } from '../../main/ets/theme/ThemeManager'

interface ToolSettingsConfigLike {
  startupAuthEnabled: boolean
  authMethod: AuthMethod
}

interface ApplicationContextLike {
  setColorMode(mode: number): void
}

interface AbilityContextLike {
  getApplicationContext(): ApplicationContextLike
  terminateSelf(): void
}

interface MainWindowLike {
  getUIContext(): UIContext
  setWindowPrivacyMode(enabled: boolean): void
  setWindowDecorVisible(visible: boolean): void
  setWindowDecorHeight(height: number): void
}

interface WindowStageLike {
  loadContent(path: string, callback: (err: EntryLoadResult) => void): void
  getMainWindow(): Promise<MainWindowLike>
}

interface EntryLoadResult {
  code?: number
}

class FakeAuthAvailability implements AuthAvailabilityResult {
  available: boolean = true
  message: string = ''
  errorCode?: number
}

class FakeAuthExecution implements AuthExecutionResult {
  success: boolean = true
  reason?: 'failed' | 'unavailable'
  errorCode?: number
  message?: string
}

class FakeMainWindow implements MainWindowLike {
  privacyMode: boolean | null = null
  decorVisible: boolean | null = null
  decorHeight: number | null = null

  getUIContext(): UIContext {
    return {} as UIContext
  }

  setWindowPrivacyMode(enabled: boolean): void {
    this.privacyMode = enabled
  }

  setWindowDecorVisible(visible: boolean): void {
    this.decorVisible = visible
  }

  setWindowDecorHeight(height: number): void {
    this.decorHeight = height
  }
}

class FakeWindowStage implements WindowStageLike {
  loadedPath: string = ''
  loadCalls: number = 0
  mainWindow: FakeMainWindow = new FakeMainWindow()

  loadContent(path: string, callback: (err: EntryLoadResult) => void): void {
    this.loadedPath = path
    this.loadCalls++
    callback(new EntryLoadSuccess())
  }

  async getMainWindow(): Promise<MainWindowLike> {
    return this.mainWindow
  }
}

class EntryLoadSuccess implements EntryLoadResult {
  code?: number
}

class FakeApplicationContext implements ApplicationContextLike {
  setColorMode(_mode: number): void {
  }
}

class FakeAbilityContext implements AbilityContextLike {
  applicationContext: FakeApplicationContext = new FakeApplicationContext()
  terminated: boolean = false

  getApplicationContext(): ApplicationContextLike {
    return this.applicationContext
  }

  terminateSelf(): void {
    this.terminated = true
  }
}

class DisabledStartupAuthConfig implements ToolSettingsConfigLike {
  startupAuthEnabled: boolean = false
  authMethod: AuthMethod = AuthMethod.PIN
}

class EnabledStartupAuthConfig implements ToolSettingsConfigLike {
  startupAuthEnabled: boolean = true
  authMethod: AuthMethod

  constructor(authMethod: AuthMethod) {
    this.authMethod = authMethod
  }
}

function setAbilityContext(ability: EntryAbility, context: AbilityContextLike): void {
  const target = ability as Object as EntryAbilityContextHolder
  target.context = context
}

function setToolSettingsRepository(
  ability: EntryAbility,
  repository: PreferencesToolSettingsRepository
): void {
  const target = ability as Object as EntryAbilityRepositoryHolder
  target.toolSettingsRepository = repository
}

interface EntryAbilityContextHolder {
  context: AbilityContextLike
}

interface EntryAbilityRepositoryHolder {
  toolSettingsRepository: PreferencesToolSettingsRepository
}

interface AccountEventHandlerHolder {
  handleAccountEvent(data: Object): Promise<void>
}

class FakeWant {
}

class FakeLaunchParam {
}

export default function entryAbilityTest() {
  describe('EntryAbility', () => {
    let ability: EntryAbility
    let mockKit: MockKit
    let repository: PreferencesToolSettingsRepository
    let context: FakeAbilityContext
    let windowStage: FakeWindowStage

    beforeEach(() => {
      ability = new EntryAbility()
      mockKit = new MockKit()
      repository = new PreferencesToolSettingsRepository()
      windowStage = new FakeWindowStage()
      context = new FakeAbilityContext()
      setAbilityContext(ability, context)
      setToolSettingsRepository(ability, repository)
    })

    afterEach(() => {
      mockKit.clearAll()
    })

    it('should initialize theme manager on create', 0, () => {
      let initMock = mockKit.mockFunc(ThemeManager.getInstance(), ThemeManager.getInstance().init)
      when(initMock)(context as never).afterReturn(undefined)

      ability.onCreate(new FakeWant() as never, new FakeLaunchParam() as never)

      expect(true).assertTrue()
    })

    it('should load main page when startup auth is disabled', 0, async (done: Function) => {
      let loadConfigMock = mockKit.mockFunc(repository, repository.loadConfig)
      when(loadConfigMock)(context as never).afterReturn(new DisabledStartupAuthConfig() as never as ToolSettingsConfigLike)

      ability.onWindowStageCreate(windowStage as never)
      await Promise.resolve()

      expect(windowStage.loadedPath).assertEqual('pages/MainPage')
      expect(windowStage.loadCalls).assertEqual(1)
      done()
    })

    it('should fallback to main page when startup auth becomes unavailable', 0, async (done: Function) => {
      let loadConfigMock = mockKit.mockFunc(repository, repository.loadConfig)
      when(loadConfigMock)(context as never).afterReturn(new EnabledStartupAuthConfig(AuthMethod.FINGERPRINT) as never as ToolSettingsConfigLike)
      let availabilityMock = mockKit.mockFunc(AuthService, AuthService.checkAuthMethodAvailability)
      let unavailable = new FakeAuthAvailability()
      unavailable.available = false
      unavailable.message = 'fingerprint unavailable'
      unavailable.errorCode = 12500010
      when(availabilityMock)(AuthMethod.FINGERPRINT).afterReturn(unavailable)

      ability.onWindowStageCreate(windowStage as never)
      await Promise.resolve()
      await Promise.resolve()

      expect(windowStage.loadedPath).assertEqual('pages/MainPage')
      expect(windowStage.loadCalls).assertEqual(1)
      done()
    })

    it('should terminate self when startup auth fails', 0, async (done: Function) => {
      let terminated = false
      context = new FakeAbilityContext()
      setAbilityContext(ability, context)

      let loadConfigMock = mockKit.mockFunc(repository, repository.loadConfig)
      when(loadConfigMock)(context as never).afterReturn(new EnabledStartupAuthConfig(AuthMethod.PIN) as never as ToolSettingsConfigLike)
      let availabilityMock = mockKit.mockFunc(AuthService, AuthService.checkAuthMethodAvailability)
      let available = new FakeAuthAvailability()
      available.available = true
      available.message = 'available'
      when(availabilityMock)(AuthMethod.PIN).afterReturn(available)
      let authenticateMock = mockKit.mockFunc(AuthService, AuthService.authenticate)
      let failed = new FakeAuthExecution()
      failed.success = false
      failed.reason = 'failed'
      failed.message = 'cancelled'
      when(authenticateMock)(AuthMethod.PIN).afterReturn(Promise.resolve(failed))

      ability.onWindowStageCreate(windowStage as never)
      await Promise.resolve()
      await Promise.resolve()

      terminated = context.terminated
      expect(terminated).assertTrue()
      expect(windowStage.loadCalls).assertEqual(0)
      done()
    })

    it('should dispatch account added event to system user provider', 0, async (done: Function) => {
      let trackedUserId = -1
      let trackAddedMock = mockKit.mockFunc(SystemUserProvider, SystemUserProvider.trackAddedUser)
      when(trackAddedMock)(ArgumentMatchers.any).afterAction((userId: number): Promise<void> => {
        trackedUserId = userId
        return Promise.resolve()
      })

      await (ability as Object as AccountEventHandlerHolder).handleAccountEvent({
        parameters: {
          [ACCOUNT_EVENT_PARAM_TYPE]: AccountEventType.ADDED,
          [ACCOUNT_EVENT_PARAM_USER_ID]: 101,
          [ACCOUNT_EVENT_PARAM_TIMESTAMP]: 1
        }
      })

      expect(trackedUserId).assertEqual(101)
      done()
    })

    it('should dispatch account removed event to system user provider', 0, async (done: Function) => {
      let trackedUserId = -1
      let trackRemovedMock = mockKit.mockFunc(SystemUserProvider, SystemUserProvider.trackRemovedUser)
      when(trackRemovedMock)(ArgumentMatchers.any).afterAction((userId: number): Promise<void> => {
        trackedUserId = userId
        return Promise.resolve()
      })

      await (ability as Object as AccountEventHandlerHolder).handleAccountEvent({
        data: JSON.stringify({
          [ACCOUNT_EVENT_PARAM_TYPE]: AccountEventType.REMOVED,
          [ACCOUNT_EVENT_PARAM_USER_ID]: 101,
          [ACCOUNT_EVENT_PARAM_TIMESTAMP]: 1
        })
      })

      expect(trackedUserId).assertEqual(101)
      done()
    })
  })
}
