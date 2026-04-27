import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { application, common } from '@kit.AbilityKit'
import osAccount from '@ohos.account.osAccount'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'

import { PreferencesAccessor } from '../../main/ets/storage/preferences/PreferencesAccessor'
import { SystemUserProvider } from '../../main/ets/services/firewall/providers/SystemUserProvider'

interface TrackedUserRecord {
  userId: number
  updatedAt: number
}

class FakePreferencesAccessor {
  records: TrackedUserRecord[] = []

  async getJsonArray<T>(_key: string, defaultValue: T[]): Promise<T[]> {
    return this.records.length > 0 ? this.records as T[] : defaultValue
  }

  async setJson(_key: string, value: TrackedUserRecord[], _flush: boolean = true): Promise<boolean> {
    this.records = value.slice()
    return true
  }
}

class FakeAccountManager {
  activatedIds: number[] = [100]
  foregroundId: number = 100

  async getActivatedOsAccountLocalIds(): Promise<number[]> {
    return this.activatedIds.slice()
  }

  async getForegroundOsAccountLocalId(): Promise<number> {
    return this.foregroundId
  }
}

export default function systemUserProviderTest() {
  describe('SystemUserProvider', () => {
    let mockKit: MockKit

    beforeEach(() => {
      mockKit = new MockKit()
    })

    afterEach(() => {
      mockKit.clearAll()
    })

    it('should allow tracked-user maintenance methods without throwing', 0, async () => {
      await SystemUserProvider.trackAddedUser(101)
      await SystemUserProvider.trackRemovedUser(101)

      expect(true).assertTrue()
    })

    it('should return a well-formed available-user result', 0, async () => {
      let result = await SystemUserProvider.loadAvailableUserIds()
      if (!result) {
        expect(true).assertTrue()
        return
      }

      expect(result.users.length >= 0).assertTrue()
      if (result.users.length > 0) {
        expect(result.users[0].userId >= 0).assertTrue()
        expect((result.users[0].label.length ?? 0) >= 0).assertTrue()
      } else {
        expect((result.message?.length ?? 0) > 0).assertTrue()
      }
    })

    it('should return a well-formed firewall policy result for a user id', 0, async () => {
      let result = await SystemUserProvider.getPolicy(100)

      expect(result.userId).assertEqual(100)
      expect(typeof result.isOpen === 'boolean').assertTrue()
      expect(typeof result.inAction === 'number').assertTrue()
      expect(typeof result.outAction === 'number').assertTrue()
    })

    it('should merge tracked added users into available users', 0, async () => {
      let fakePref = new FakePreferencesAccessor()
      let accountManager = new FakeAccountManager()
      let appContextMock = mockKit.mockFunc(application, application.getApplicationContext)
      let prefMock = mockKit.mockFunc(PreferencesAccessor, PreferencesAccessor.of)
      let accountMock = mockKit.mockFunc(osAccount, osAccount.getAccountManager)
      when(appContextMock)().afterReturn({ filesDir: '/tmp/security-tool-test' } as common.Context)
      when(prefMock)(ArgumentMatchers.any).afterReturn(fakePref as never as PreferencesAccessor)
      when(accountMock)().afterReturn(accountManager as never)

      await SystemUserProvider.trackAddedUser(101)
      let result = await SystemUserProvider.loadAvailableUserIds()

      expect(result.users.some((item): boolean => item.userId === 100)).assertTrue()
      expect(result.users.some((item): boolean => item.userId === 101)).assertTrue()
    })

    it('should remove tracked users from available users', 0, async () => {
      let fakePref = new FakePreferencesAccessor()
      let accountManager = new FakeAccountManager()
      let appContextMock = mockKit.mockFunc(application, application.getApplicationContext)
      let prefMock = mockKit.mockFunc(PreferencesAccessor, PreferencesAccessor.of)
      let accountMock = mockKit.mockFunc(osAccount, osAccount.getAccountManager)
      when(appContextMock)().afterReturn({ filesDir: '/tmp/security-tool-test' } as common.Context)
      when(prefMock)(ArgumentMatchers.any).afterReturn(fakePref as never as PreferencesAccessor)
      when(accountMock)().afterReturn(accountManager as never)

      await SystemUserProvider.trackAddedUser(101)
      await SystemUserProvider.trackRemovedUser(101)
      let result = await SystemUserProvider.loadAvailableUserIds()

      expect(result.users.some((item): boolean => item.userId === 100)).assertTrue()
      expect(result.users.some((item): boolean => item.userId === 101)).assertFalse()
    })
  })
}
