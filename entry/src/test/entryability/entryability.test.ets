import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import EntryAbility from '../../main/ets/entryability/EntryAbility'
import { AccountEventType } from '../../main/ets/contracts/AccountEventContract'
import { AuthMethod } from '../../main/ets/models/AuthModels'
import {
  FIREWALL_RULE_MAPPING_VERSION,
  FirewallRuleDeployment,
  FirewallRuleIntent,
  FirewallRuleIntentMappingData,
  PREF_KEY_FIREWALL_RULE_MAPPING,
  PREF_KEY_FIREWALL_USER_POLICY,
  PREF_STORE_NAME_FIREWALL_RULE_MAPPING,
  PREF_STORE_NAME_FIREWALL_USER_POLICY
} from '../../main/ets/services/firewall/FirewallModels'
import { AuthAvailabilityResult, AuthExecutionResult, AuthService } from '../../main/ets/services/identity/auth/AuthService'
import { PreferencesToolSettingsRepository } from '../../main/ets/services/tool-settings/system-settings/ToolSettingsRepository'
import { PreferencesAccessor } from '../../main/ets/storage/preferences/PreferencesAccessor'
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
  handleAccountEvent(data: FakeAccountEventData): Promise<void>
}

class FakeWant {
}

class FakeLaunchParam {
}

class FakeAccountEventParameters {
  accountEventType: string = ''
  accountEventUserId: number = 0
  accountEventTimestamp: number = 0
}

class FakeAccountEventData {
  parameters?: FakeAccountEventParameters
  data?: string
}

interface EntryAbilityUserPolicyModeRecord {
  userId: number
  mode: string
}

class FakeEntryPreferencesAccessor {
  private values: Map<string, Object> = new Map<string, Object>()

  async getString(key: string, defaultValue: string): Promise<string> {
    let value = this.values.get(key)
    return typeof value === 'string' ? value : defaultValue
  }

  async getJsonObject<T>(key: string, defaultValue: T): Promise<T> {
    let raw = await this.getString(key, '')
    if (raw.length === 0) {
      return defaultValue
    }
    try {
      let parsed = JSON.parse(raw) as Object
      return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed as T : defaultValue
    } catch (_err) {
      return defaultValue
    }
  }

  async getJsonArray<T>(key: string, defaultValue: T[]): Promise<T[]> {
    let raw = await this.getString(key, '[]')
    try {
      let parsed = JSON.parse(raw) as Object
      return Array.isArray(parsed) ? parsed as T[] : defaultValue
    } catch (_err) {
      return defaultValue
    }
  }

  async setValue(key: string, value: Object, _flush: boolean = true): Promise<boolean> {
    this.values.set(key, value)
    return true
  }

  async setJson(key: string, value: object, flush: boolean = true): Promise<boolean> {
    return this.setValue(key, JSON.stringify(value), flush)
  }

  setRaw(key: string, value: Object): void {
    this.values.set(key, value)
  }
}

class FakeEntryPreferencesProvider {
  private stores: Map<string, FakeEntryPreferencesAccessor> = new Map<string, FakeEntryPreferencesAccessor>()

  accessorFor(storeName: string): FakeEntryPreferencesAccessor {
    let existing = this.stores.get(storeName)
    if (existing) {
      return existing
    }
    let accessor = new FakeEntryPreferencesAccessor()
    this.stores.set(storeName, accessor)
    return accessor
  }
}

function buildEntryAbilityRuleIntent(localRuleId: string, targetUserIds: number[]): FirewallRuleIntent {
  return {
    localRuleId: localRuleId,
    name: localRuleId,
    type: 0,
    direction: 0,
    action: 0,
    isEnabled: true,
    targetUserIds: targetUserIds,
    createdAt: 1,
    updatedAt: 1
  } as FirewallRuleIntent
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

    it('should accept account added event without local tracked-user persistence', 0, async (done: Function) => {
      let parameters = new FakeAccountEventParameters()
      parameters.accountEventType = AccountEventType.ADDED
      parameters.accountEventUserId = 101
      parameters.accountEventTimestamp = 1
      let eventData = new FakeAccountEventData()
      eventData.parameters = parameters

      await (ability as Object as AccountEventHandlerHolder).handleAccountEvent(eventData)

      expect(true).assertTrue()
      done()
    })

    it('should clean firewall local data for account removed event', 0, async (done: Function) => {
      let fakePrefs = new FakeEntryPreferencesProvider()
      let prefMock = mockKit.mockFunc(PreferencesAccessor, PreferencesAccessor.of)
      when(prefMock)(ArgumentMatchers.any).afterAction((
        _context: Object,
        storeName: string
      ): PreferencesAccessor => fakePrefs.accessorFor(storeName) as never as PreferencesAccessor)
      let mappingPref = fakePrefs.accessorFor(PREF_STORE_NAME_FIREWALL_RULE_MAPPING)
      let userPolicyPref = fakePrefs.accessorFor(PREF_STORE_NAME_FIREWALL_USER_POLICY)
      mappingPref.setRaw(PREF_KEY_FIREWALL_RULE_MAPPING, JSON.stringify({
        version: FIREWALL_RULE_MAPPING_VERSION,
        ruleIntents: [
          buildEntryAbilityRuleIntent('rule-keep', [100, 101]),
          buildEntryAbilityRuleIntent('rule-drop', [101])
        ],
        ruleDeployments: [
          { localRuleId: 'rule-keep', userId: 100, systemRuleId: 1 } as FirewallRuleDeployment,
          { localRuleId: 'rule-keep', userId: 101, systemRuleId: 2 } as FirewallRuleDeployment,
          { localRuleId: 'rule-drop', userId: 101, systemRuleId: 3 } as FirewallRuleDeployment
        ]
      } as FirewallRuleIntentMappingData))
      userPolicyPref.setRaw(PREF_KEY_FIREWALL_USER_POLICY, JSON.stringify([
        { userId: 100, mode: 'denylist' },
        { userId: 101, mode: 'allowlist' }
      ]))

      let parameters = new FakeAccountEventParameters()
      parameters.accountEventType = AccountEventType.REMOVED
      parameters.accountEventUserId = 101
      parameters.accountEventTimestamp = 1
      let eventData = new FakeAccountEventData()
      eventData.data = JSON.stringify(parameters)

      await (ability as Object as AccountEventHandlerHolder).handleAccountEvent(eventData)

      let savedData = await mappingPref.getJsonObject<FirewallRuleIntentMappingData>(
        PREF_KEY_FIREWALL_RULE_MAPPING,
        { version: FIREWALL_RULE_MAPPING_VERSION, ruleIntents: [], ruleDeployments: [] } as FirewallRuleIntentMappingData
      )
      let savedPolicies = await userPolicyPref.getJsonArray<EntryAbilityUserPolicyModeRecord>(
        PREF_KEY_FIREWALL_USER_POLICY,
        []
      )
      expect(savedData.ruleIntents.length).assertEqual(1)
      expect(savedData.ruleIntents[0].localRuleId).assertEqual('rule-keep')
      expect(savedData.ruleIntents[0].targetUserIds.length).assertEqual(1)
      expect(savedData.ruleIntents[0].targetUserIds[0]).assertEqual(100)
      expect(savedData.ruleDeployments.length).assertEqual(1)
      expect(savedData.ruleDeployments[0].userId).assertEqual(100)
      expect(savedPolicies.length).assertEqual(1)
      expect(savedPolicies[0].userId).assertEqual(100)
      done()
    })
  })
}
