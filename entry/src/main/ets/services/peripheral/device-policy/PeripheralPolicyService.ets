import {
  PeripheralConnectionRecord,
  PeripheralPolicyRecord,
  UsbDevicePolicyStateRecord,
  inferPeripheralTypeFromBaseClass
} from '../../../models/PeripheralModels'
import { PeripheralPolicyOptionIndexes } from '../../../constants/modules/PeripheralStrings'
import { PLACEHOLDER_TEXT } from '../../../constants/StringCatalog'
import { formatStandardDateTimeOrFallback } from '../../../utils/DateTimeFormatUtils'

export class PeripheralPolicyService {
  static buildPolicyRecords(
    _connectionRecords: PeripheralConnectionRecord[],
    usbPolicyStates: UsbDevicePolicyStateRecord[] = []
  ): PeripheralPolicyRecord[] {
    const stateItems: PeripheralPolicyRecord[] = usbPolicyStates.map((state: UsbDevicePolicyStateRecord) => {
      const lastSeenAt = state.lastSeenAt
      return {
        deviceName: state.deviceName?.trim().length ? state.deviceName : state.fingerprintKey,
        deviceType: inferPeripheralTypeFromBaseClass(state.baseClass),
        deviceId: state.fingerprintKey,
        lastSeenAt: lastSeenAt,
        lastSeenLabel: formatStandardDateTimeOrFallback(lastSeenAt, PLACEHOLDER_TEXT),
        policyIndex: state.desiredPolicy === 'deny' ? PeripheralPolicyOptionIndexes.DENY : PeripheralPolicyOptionIndexes.ALLOW,
        present: state.present,
        editable: state.present
      } as PeripheralPolicyRecord
    })
    return stateItems.sort((left: PeripheralPolicyRecord, right: PeripheralPolicyRecord) => {
      return right.lastSeenAt - left.lastSeenAt
    })
  }

  static normalizeDeviceIdForPolicy(deviceId: string): string {
    const normalizedRaw = (deviceId || '').trim().replace(/\s+/g, ' ')
    if (normalizedRaw.length === 0) {
      return ''
    }
    return normalizedRaw.toUpperCase()
  }
}
