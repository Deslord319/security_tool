import { describe, expect, it } from '@ohos/hypium'
import { PeripheralService } from '../../main/ets/services/PeripheralService'

describe('PeripheralService', () => {
  it('should expose the expected interface feature constants', 0, () => {
    expect(PeripheralService.FEATURE_USB).assertEqual('usb')
    expect(PeripheralService.FEATURE_BLUETOOTH).assertEqual('bluetooth')
    expect(PeripheralService.FEATURE_WIFI).assertEqual('wifi')
    expect(PeripheralService.FEATURE_HDC).assertEqual('hdc')
  })
})
