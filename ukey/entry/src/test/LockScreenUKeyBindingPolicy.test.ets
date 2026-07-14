import { describe, expect, it } from '@ohos/hypium'
import { LockScreenUKeyBinding } from '../main/ets/models/identity/lockscreen-auth/LockScreenAuthModels'
import { canUpdateUKeyBinding } from '../main/ets/services/identity/lockscreen-auth/LockScreenUKeyBindingRepository'

function binding(fingerprint: string): LockScreenUKeyBinding {
  return {
    fingerprint: fingerprint,
    deviceId: 'VID:1234 PID:5678',
    deviceName: 'Secure UKey',
    boundAt: 1,
    stableIdentifier: true,
    userCredentials: []
  }
}

export default function lockScreenUKeyBindingPolicyTest(): void {
  describe('LockScreenUKeyBindingPolicy', () => {
    it('allows_the_first_binding', 0, () => {
      expect(canUpdateUKeyBinding(null, binding('SN:FIRST'))).assertTrue()
    })

    it('allows_credential_updates_for_the_same_binding', 0, () => {
      expect(canUpdateUKeyBinding(binding('SN:FIRST'), binding('SN:FIRST'))).assertTrue()
    })

    it('rejects_replacing_the_first_binding', 0, () => {
      expect(canUpdateUKeyBinding(binding('SN:FIRST'), binding('SN:SECOND'))).assertFalse()
    })
  })
}
