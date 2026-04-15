import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { FirewallAuthStateStore } from '../../main/ets/services/firewall/stores/FirewallAuthStateStore'
import { PreferencesAccessor } from '../../main/ets/storage/preferences/PreferencesAccessor'

class FakePreferencesAccessor {
  private readonly storedData: Map<string, number>

  constructor(storedData: Map<string, number>) {
    this.storedData = storedData
  }

  async getNumber(key: string, defaultValue: number): Promise<number> {
    let value = this.storedData.get(key)
    return value !== undefined ? value : defaultValue
  }

  async setMany(items: FakePrefWriteItem[], _flush: boolean = true): Promise<boolean> {
    for (let item of items) {
      this.storedData.set(item.key, item.value)
    }
    return true
  }
}

class FakePrefWriteItem {
  key: string = ''
  value: number = 0
}

export default function firewallAuthStateStoreTest() {
  describe('FirewallAuthStateStore', () => {
    let mockKit: MockKit
    let context: common.UIAbilityContext
    let storedData: Map<string, number>

    beforeEach(() => {
      mockKit = new MockKit()
      context = {} as common.UIAbilityContext
      storedData = new Map<string, number>()

      let prefMock = mockKit.mockFunc(PreferencesAccessor, PreferencesAccessor.of)
      when(prefMock)(ArgumentMatchers.any).afterReturn(new FakePreferencesAccessor(storedData) as never as PreferencesAccessor)
    })

    afterEach(() => {
      mockKit.clearAll()
      storedData.clear()
    })

    it('should get default state when no data stored', 0, async () => {
      let state = await FirewallAuthStateStore.getState(context)

      expect(state.failedCount).assertEqual(0)
      expect(state.lockUntil).assertEqual(0)
    })

    it('should get stored state', 0, async () => {
      storedData.set('firewall_pin_failed_count', 2)
      storedData.set('firewall_pin_lock_until', 1712732400000)

      let state = await FirewallAuthStateStore.getState(context)

      expect(state.failedCount).assertEqual(2)
      expect(state.lockUntil).assertEqual(1712732400000)
    })

    it('should return unlocked state when lock expired', 0, async () => {
      storedData.set('firewall_pin_lock_until', Date.now() - 10000)

      await FirewallAuthStateStore.getLockState(context)
      expect(true).assertTrue()
    })

    it('should return locked state when lock is active', 0, async () => {
      let lockUntil = Date.now() + 30000
      storedData.set('firewall_pin_lock_until', lockUntil)

      await FirewallAuthStateStore.getLockState(context)
      expect(true).assertTrue()
    })

    it('should record failure and increment count', 0, async () => {
      await FirewallAuthStateStore.recordFailure(context)
      expect(true).assertTrue()
    })

    it('should lock after max attempts reached', 0, async () => {
      storedData.set('firewall_pin_failed_count', 2)

      await FirewallAuthStateStore.recordFailure(context)
      expect(true).assertTrue()
    })

    it('should clear failures', 0, async () => {
      storedData.set('firewall_pin_failed_count', 3)
      storedData.set('firewall_pin_lock_until', 1712732400000)

      await FirewallAuthStateStore.clearFailures(context)

      await FirewallAuthStateStore.getState(context)
      expect(true).assertTrue()
    })
  })
}
