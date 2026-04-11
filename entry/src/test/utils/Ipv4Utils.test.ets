import { describe, expect, it } from '@ohos/hypium'

import { Ipv4Utils } from '../../main/ets/utils/Ipv4Utils'

export default function ipv4UtilsTest() {
  describe('Ipv4Utils', () => {
    it('should validate canonical ipv4 addresses', 0, () => {
      expect(Ipv4Utils.isValidIpv4('192.168.0.1')).assertTrue()
      expect(Ipv4Utils.isValidIpv4('255.255.255.255')).assertTrue()
    })

    it('should reject invalid ipv4 addresses', 0, () => {
      expect(Ipv4Utils.isValidIpv4('256.1.1.1')).assertFalse()
      expect(Ipv4Utils.isValidIpv4('1.2.3')).assertFalse()
      expect(Ipv4Utils.isValidIpv4('01.2.3.4')).assertFalse()
      expect(Ipv4Utils.isValidIpv4('1.2.3.a')).assertFalse()
    })

    it('should validate cidr values with ipv4 base address', 0, () => {
      expect(Ipv4Utils.isValidIpv4OrCidr('10.0.0.1')).assertTrue()
      expect(Ipv4Utils.isValidIpv4OrCidr('10.0.0.0/24')).assertTrue()
      expect(Ipv4Utils.isValidIpv4OrCidr('0.0.0.0/0')).assertTrue()
    })

    it('should reject invalid cidr values', 0, () => {
      expect(Ipv4Utils.isValidIpv4OrCidr('10.0.0.0/33')).assertFalse()
      expect(Ipv4Utils.isValidIpv4OrCidr('10.0.0.0/a')).assertFalse()
      expect(Ipv4Utils.isValidIpv4OrCidr('bad-cidr')).assertFalse()
    })

    it('should parse ipv4 into integer value', 0, () => {
      expect(Ipv4Utils.parseIpv4('0.0.0.1')).assertEqual(1)
      expect(Ipv4Utils.parseIpv4('255.255.255.255')).assertEqual(4294967295)
      expect(Ipv4Utils.parseIpv4('01.0.0.1')).assertEqual(null)
    })
  })
}
