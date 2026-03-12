import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import {
  FIREWALL_PIN_LOCK_DURATION_MS,
  FIREWALL_PIN_LOCK_MAX_ATTEMPTS,
  PREF_KEY_FIREWALL_PIN_FAILED_COUNT,
  PREF_KEY_FIREWALL_PIN_LOCK_UNTIL,
  PREF_STORE_NAME_FIREWALL_AUTH
} from '../models/DataModels'

const TAG = 'FirewallAuthStateRepository'
const DOMAIN = 0x0009

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

export class FirewallAuthStateRepository {
  static async getState(context: common.UIAbilityContext): Promise<FirewallAuthState> {
    try {
      let store = await preferences.getPreferences(context, PREF_STORE_NAME_FIREWALL_AUTH)
      let failedCountRaw = await store.get(PREF_KEY_FIREWALL_PIN_FAILED_COUNT, 0)
      let lockUntilRaw = await store.get(PREF_KEY_FIREWALL_PIN_LOCK_UNTIL, 0)
      let failedCount = FirewallAuthStateRepository.normalizeNumber(failedCountRaw)
      let lockUntil = FirewallAuthStateRepository.normalizeNumber(lockUntilRaw)
      return {
        failedCount: failedCount,
        lockUntil: lockUntil
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, `getState failed: ${JSON.stringify(err)}`)
      return { failedCount: 0, lockUntil: 0 }
    }
  }

  static async getLockState(
    context: common.UIAbilityContext,
    now: number = Date.now()
  ): Promise<FirewallAuthLockState> {
    let state = await FirewallAuthStateRepository.getState(context)
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
      let store = await preferences.getPreferences(context, PREF_STORE_NAME_FIREWALL_AUTH)
      let state = await FirewallAuthStateRepository.getState(context)
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

      await store.put(PREF_KEY_FIREWALL_PIN_FAILED_COUNT, nextFailedCount)
      await store.put(PREF_KEY_FIREWALL_PIN_LOCK_UNTIL, lockUntil)
      await store.flush()
      return {
        failedCount: nextFailedCount,
        locked: locked,
        remainingSec: remainingSec
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, `recordFailure failed: ${JSON.stringify(err)}`)
      return {
        failedCount: 0,
        locked: false,
        remainingSec: 0
      }
    }
  }

  static async clearFailures(context: common.UIAbilityContext): Promise<void> {
    try {
      let store = await preferences.getPreferences(context, PREF_STORE_NAME_FIREWALL_AUTH)
      await store.put(PREF_KEY_FIREWALL_PIN_FAILED_COUNT, 0)
      await store.put(PREF_KEY_FIREWALL_PIN_LOCK_UNTIL, 0)
      await store.flush()
    } catch (err) {
      hilog.error(DOMAIN, TAG, `clearFailures failed: ${JSON.stringify(err)}`)
    }
  }

  private static normalizeNumber(value: Object): number {
    if (typeof value === 'number' && Number.isFinite(value)) {
      return value
    }
    if (typeof value === 'string') {
      let parsed = Number(value)
      if (Number.isFinite(parsed)) {
        return parsed
      }
    }
    return 0
  }
}
