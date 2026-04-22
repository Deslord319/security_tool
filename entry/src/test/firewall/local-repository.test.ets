import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'

import { FirewallLocalRepository } from '../../main/ets/services/firewall/FirewallLocalRepository'
import {
  FIREWALL_RULE_MAPPING_VERSION,
  FirewallRuleDeployment,
  FirewallRuleIntent,
  PREF_KEY_FIREWALL_ACTIVE_MODE,
  PREF_KEY_FIREWALL_RULE_MAPPING,
  PREF_KEY_FIREWALL_USER_POLICY,
  PREF_STORE_NAME_FIREWALL_MODE,
  PREF_STORE_NAME_FIREWALL_RULE_MAPPING,
  PREF_STORE_NAME_FIREWALL_USER_POLICY
} from '../../main/ets/services/firewall/FirewallModels'
import { PreferencesAccessor } from '../../main/ets/storage/preferences/PreferencesAccessor'

class FakePreferencesAccessor {
  private values: Map<string, Object> = new Map<string, Object>()
  failSet: boolean = false

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
    if (this.failSet) {
      return false
    }
    this.values.set(key, value)
    return true
  }

  async setJson(key: string, value: object | object[], flush: boolean = true): Promise<boolean> {
    return this.setValue(key, JSON.stringify(value), flush)
  }

  setRaw(key: string, value: Object): void {
    this.values.set(key, value)
  }
}

class FakePreferencesProvider {
  private stores: Map<string, FakePreferencesAccessor> = new Map<string, FakePreferencesAccessor>()

  accessorFor(storeName: string): FakePreferencesAccessor {
    let existing = this.stores.get(storeName)
    if (existing) {
      return existing
    }
    let accessor = new FakePreferencesAccessor()
    this.stores.set(storeName, accessor)
    return accessor
  }
}

function buildIntent(localRuleId: string, name: string, targetUserIds: number[] = [100]): FirewallRuleIntent {
  return {
    localRuleId: localRuleId,
    name: name,
    type: 1,
    direction: 1,
    action: 1,
    isEnabled: true,
    targetUserIds: targetUserIds,
    createdAt: 1,
    updatedAt: 1
  }
}

function buildDeployment(localRuleId: string, userId: number, systemRuleId: number): FirewallRuleDeployment {
  return {
    localRuleId: localRuleId,
    userId: userId,
    systemRuleId: systemRuleId
  }
}

export default function firewallLocalRepositoryTest() {
  describe('FirewallLocalRepository', () => {
    let mockKit: MockKit
    let context: common.UIAbilityContext
    let fakeProvider: FakePreferencesProvider

    beforeEach(() => {
      mockKit = new MockKit()
      context = {} as common.UIAbilityContext
      fakeProvider = new FakePreferencesProvider()

      let prefMock = mockKit.mockFunc(PreferencesAccessor, PreferencesAccessor.of)
      when(prefMock)(ArgumentMatchers.any).afterAction((
        _context: common.Context,
        storeName: string
      ): PreferencesAccessor => {
        return fakeProvider.accessorFor(storeName) as never as PreferencesAccessor
      })
    })

    afterEach(() => {
      mockKit.clearAll()
    })

    it('should default current mode to custom and persist legal modes', 0, async (done: Function) => {
      expect(await FirewallLocalRepository.getCurrentMode(context)).assertEqual('custom')

      await FirewallLocalRepository.saveCurrentMode(context, 'public')
      expect(await FirewallLocalRepository.getCurrentMode(context)).assertEqual('public')

      await FirewallLocalRepository.saveCurrentMode(context, 'private')
      expect(await FirewallLocalRepository.getCurrentMode(context)).assertEqual('private')

      await FirewallLocalRepository.saveCurrentMode(context, 'custom')
      expect(await FirewallLocalRepository.getCurrentMode(context)).assertEqual('custom')

      fakeProvider.accessorFor(PREF_STORE_NAME_FIREWALL_MODE).setRaw(PREF_KEY_FIREWALL_ACTIVE_MODE, 'invalid-mode')
      expect(await FirewallLocalRepository.getCurrentMode(context)).assertEqual('custom')
      done()
    })

    it('should persist and normalize user policy modes', 0, async (done: Function) => {
      await FirewallLocalRepository.saveUserPolicyMode(context, 100, 'allowlist')
      expect(await FirewallLocalRepository.getUserPolicyMode(context, 100)).assertEqual('allowlist')

      await FirewallLocalRepository.saveUserPolicyMode(context, 100, 'denylist')
      expect(await FirewallLocalRepository.getUserPolicyMode(context, 100)).assertEqual('denylist')

      fakeProvider.accessorFor(PREF_STORE_NAME_FIREWALL_USER_POLICY)
        .setRaw(PREF_KEY_FIREWALL_USER_POLICY, '[{"userId":100,"mode":"allowlist"},{"userId":101,"mode":"bad-mode"},{"userId":"102","mode":"denylist"},{"userId":103,"mode":"denylist"}]')

      let records = await FirewallLocalRepository.listUserPolicyModes(context)
      expect(records.length).assertEqual(2)
      expect(records[0].userId).assertEqual(100)
      expect(records[0].mode).assertEqual('allowlist')
      expect(records[1].userId).assertEqual(103)
      expect(records[1].mode).assertEqual('denylist')
      done()
    })

    it('should persist, replace and remove rule intents and deployments', 0, async (done: Function) => {
      let emptyData = await FirewallLocalRepository.loadRuleIntentMappingData(context)
      expect(emptyData.version).assertEqual(FIREWALL_RULE_MAPPING_VERSION)
      expect(emptyData.ruleIntents.length).assertEqual(0)
      expect(emptyData.ruleDeployments.length).assertEqual(0)

      await FirewallLocalRepository.saveRuleIntent(context, buildIntent('rule-1', 'Rule 1', [101, 100]))
      await FirewallLocalRepository.saveRuleIntent(context, buildIntent('rule-2', 'Rule 2', [102]))
      expect((await FirewallLocalRepository.listRuleIntents(context)).length).assertEqual(2)
      expect((await FirewallLocalRepository.getRuleIntent(context, 'rule-1'))?.name).assertEqual('Rule 1')

      await FirewallLocalRepository.saveRuleIntent(context, buildIntent('rule-1', 'Rule 1 updated', [100]))
      let intents = await FirewallLocalRepository.listRuleIntents(context)
      expect(intents.length).assertEqual(2)
      expect((await FirewallLocalRepository.getRuleIntent(context, 'rule-1'))?.name).assertEqual('Rule 1 updated')

      await FirewallLocalRepository.replaceRuleDeployments(context, 'rule-1', [
        buildDeployment('rule-1', 100, 9001),
        buildDeployment('rule-1', 101, 9002),
        buildDeployment('rule-2', 102, 9003)
      ])
      await FirewallLocalRepository.replaceRuleDeployments(context, 'rule-2', [
        buildDeployment('rule-2', 102, 9003)
      ])
      expect((await FirewallLocalRepository.listRuleDeployments(context)).length).assertEqual(3)

      await FirewallLocalRepository.replaceRuleDeployments(context, 'rule-1', [
        buildDeployment('rule-1', 100, 9010)
      ])
      expect((await FirewallLocalRepository.listRuleDeployments(context, 'rule-1')).length).assertEqual(1)
      expect((await FirewallLocalRepository.listRuleDeployments(context, 'rule-2')).length).assertEqual(1)

      await FirewallLocalRepository.removeRuleDeployments(context, 'rule-2')
      expect((await FirewallLocalRepository.listRuleDeployments(context)).length).assertEqual(1)

      await FirewallLocalRepository.clearAllRuleDeployments(context)
      expect((await FirewallLocalRepository.listRuleDeployments(context)).length).assertEqual(0)
      expect((await FirewallLocalRepository.listRuleIntents(context)).length).assertEqual(2)

      await FirewallLocalRepository.removeRuleIntent(context, 'rule-2')
      expect((await FirewallLocalRepository.listRuleIntents(context)).length).assertEqual(1)
      done()
    })

    it('should recover from corrupted mapping json and report write failures', 0, async (done: Function) => {
      fakeProvider.accessorFor(PREF_STORE_NAME_FIREWALL_RULE_MAPPING)
        .setRaw(PREF_KEY_FIREWALL_RULE_MAPPING, '{bad json')
      let data = await FirewallLocalRepository.loadRuleIntentMappingData(context)
      expect(data.ruleIntents.length).assertEqual(0)
      expect(data.ruleDeployments.length).assertEqual(0)

      fakeProvider.accessorFor(PREF_STORE_NAME_FIREWALL_RULE_MAPPING).failSet = true
      let saved = await FirewallLocalRepository.saveRuleIntentMappingData(context, {
        version: FIREWALL_RULE_MAPPING_VERSION,
        ruleIntents: [buildIntent('rule-1', 'Rule 1')],
        ruleDeployments: []
      })
      expect(saved).assertFalse()
      done()
    })
  })
}
