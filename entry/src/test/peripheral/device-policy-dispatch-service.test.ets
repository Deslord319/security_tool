import { describe, expect, it } from '@ohos/hypium'
import { PeripheralType } from '../../main/ets/models/PeripheralModels'
import { PeripheralDevicePolicyDispatchService } from '../../main/ets/services/peripheral/device-policy/PeripheralDevicePolicyDispatchService'

export default function peripheralDevicePolicyDispatchServiceTest() {
  describe('PeripheralDevicePolicyDispatchService', () => {
    it('should reject unsupported policy before touching system managers', 0, async () => {
      const result = await PeripheralDevicePolicyDispatchService.dispatch({
        deviceId: 'VID:1234 PID:5678',
        deviceType: PeripheralType.USB_STORAGE,
        policy: 'noop' as 'allow' | 'deny'
      })

      expect(result.success).assertFalse()
      expect(result.reason).assertEqual('unsupported_policy')
      expect(result.stage).assertEqual('device_policy_dispatch')
    })

    it('should reject unsupported device type before dispatch', 0, async () => {
      const result = await PeripheralDevicePolicyDispatchService.dispatch({
        deviceId: 'SERIAL:1234',
        deviceType: 'serial' as PeripheralType,
        policy: 'allow'
      })

      expect(result.success).assertFalse()
      expect(result.reason).assertEqual('unsupported_device_type')
      expect(result.stage).assertEqual('device_policy_dispatch')
    })

    it('should reject bluetooth device type before dispatch', 0, async () => {
      const result = await PeripheralDevicePolicyDispatchService.dispatch({
        deviceId: 'MAC: AA:BB:CC:DD:EE:FF',
        deviceType: PeripheralType.BLUETOOTH,
        policy: 'deny'
      })

      expect(result.success).assertFalse()
      expect(result.reason).assertEqual('unsupported_device_type')
      expect(result.stage).assertEqual('device_policy_dispatch')
    })
  })
}
