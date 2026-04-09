import { common } from '@kit.AbilityKit'
import {
  FIREWALL_PIN_LOCK_DURATION_MS,
  FIREWALL_PIN_LOCK_MAX_ATTEMPTS,
  PREF_KEY_FIREWALL_PIN_FAILED_COUNT,
  PREF_KEY_FIREWALL_PIN_LOCK_UNTIL,
  PREF_STORE_NAME_FIREWALL_AUTH
} from '../../../models/DataModels'
import { LogUtils } from '../../../utils/LogUtils'
import { PreferencesAccessor } from '../../../storage/preferences/PreferencesAccessor'

const TAG = 'FirewallAuthStateStore'

export interface FirewallAuthState {
  failedCount: number
  lockUntil: number
}

export interface FirewallAuthLockState {
  locked: boolean
  remainingSec: number
  state: FirewallAuthState
}

export interface FirewallAuthFailureUpdate {
  failedCount: number
  locked: boolean
  remainingSec: number
}

export class FirewallAuthStateStore {
  static async getState(context: common.UIAbilityContext): Promise<FirewallAuthState> {
    try {
      let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_FIREWALL_AUTH)
      return {
        failedCount: await pref.getNumber(PREF_KEY_FIREWALL_PIN_FAILED_COUNT, 0),
        lockUntil: await pref.getNumber(PREF_KEY_FIREWALL_PIN_LOCK_UNTIL, 0)
      }
    } catch (err) {
      LogUtils.error(TAG, `getState failed: ${JSON.stringify(err)}`)
      return { failedCount: 0, lockUntil: 0 }
    }
  }

  static async getLockState(
    context: common.UIAbilityContext,
    now: number = Date.now()
  ): Promise<FirewallAuthLockState> {
    let state = await FirewallAuthStateStore.getState(context)
    let remainingMs = state.lockUntil - now
    let locked = remainingMs > 0
    let remainingSec = locked ? Math.ceil(remainingMs / 1000) : 0
    return {
      locked: locked,
      remainingSec: remainingSec,
      state: state
    }
  }

  static async recordFailure(
    context: common.UIAbilityContext,
    now: number = Date.now()
  ): Promise<FirewallAuthFailureUpdate> {
    try {
      let state = await FirewallAuthStateStore.getState(context)
      let nextFailedCount = state.failedCount + 1
      let lockUntil = state.lockUntil
      let locked = false
      let remainingSec = 0
      if (nextFailedCount >= FIREWALL_PIN_LOCK_MAX_ATTEMPTS) {
        lockUntil = now + FIREWALL_PIN_LOCK_DURATION_MS
        nextFailedCount = 0
        locked = true
        remainingSec = Math.ceil(FIREWALL_PIN_LOCK_DURATION_MS / 1000)
      }

      let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_FIREWALL_AUTH)
      let saved = await pref.setMany([
        { key: PREF_KEY_FIREWALL_PIN_FAILED_COUNT, value: nextFailedCount },
        { key: PREF_KEY_FIREWALL_PIN_LOCK_UNTIL, value: lockUntil }
      ])
      if (!saved) {
        LogUtils.error(TAG, 'recordFailure failed: preferences_write_failed')
        return {
          failedCount: 0,
          locked: false,
          remainingSec: 0
        }
      }
      return {
        failedCount: nextFailedCount,
        locked: locked,
        remainingSec: remainingSec
      }
    } catch (err) {
      LogUtils.error(TAG, `recordFailure failed: ${JSON.stringify(err)}`)
      return {
        failedCount: 0,
        locked: false,
        remainingSec: 0
      }
    }
  }

  static async clearFailures(context: common.UIAbilityContext): Promise<void> {
    try {
      let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_FIREWALL_AUTH)
      let saved = await pref.setMany([
        { key: PREF_KEY_FIREWALL_PIN_FAILED_COUNT, value: 0 },
        { key: PREF_KEY_FIREWALL_PIN_LOCK_UNTIL, value: 0 }
      ])
      if (!saved) {
        LogUtils.error(TAG, 'clearFailures failed: preferences_write_failed')
      }
    } catch (err) {
      LogUtils.error(TAG, `clearFailures failed: ${JSON.stringify(err)}`)
    }
  }
}
