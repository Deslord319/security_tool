import { describe, expect, it } from '@ohos/hypium'
import { PeripheralStrings } from '../../main/ets/constants/modules/PeripheralStrings'

export default function peripheralStringsTest() {
  describe('PeripheralStrings', () => {
    it('should keep commercial page copy and tab labels stable', 0, () => {
      expect(PeripheralStrings.pageSubtitle).assertEqual('管控 USB、蓝牙、Wi-Fi 等外设接口，配置设备黑白名单策略')
      expect(PeripheralStrings.interfaceTabTitle).assertEqual('接口管控')
      expect(PeripheralStrings.deviceTabTitle).assertEqual('设备连接记录')
      expect(PeripheralStrings.policyTabTitle).assertEqual('黑白名单')
    })

    it('should expose stable operator labels for toolbar actions', 0, () => {
      expect(PeripheralStrings.exportHistoryLabel).assertEqual('导出记录')
      expect(PeripheralStrings.clearHistoryLabel).assertEqual('清理记录')
      expect(PeripheralStrings.exportPolicyLabel).assertEqual('导出名单')
      expect(PeripheralStrings.clearPolicyLabel).assertEqual('还原策略')
    })

    it('should map common failure reasons to actionable messages', 0, () => {
      expect(PeripheralStrings.resolveReason(PeripheralStrings.adminRequired)).assertEqual('请先激活企业管理员权限')
      expect(PeripheralStrings.resolveReason(PeripheralStrings.toggleInterfaceFailed)).assertEqual('接口管控设置失败，请稍后重试')
      expect(PeripheralStrings.resolveReason(PeripheralStrings.setUsbInterfaceConflict).indexOf('USB 冲突规则') >= 0).assertTrue()
      expect(PeripheralStrings.resolveReason('自定义错误')).assertEqual('自定义错误')
      expect(PeripheralStrings.resolveReason('')).assertEqual('请稍后重试')
    })

    it('should keep policy option order stable for the UI layer', 0, () => {
      expect(PeripheralStrings.policyOptions.length).assertEqual(2)
      expect(PeripheralStrings.policyOptions[0]).assertEqual('允许接入')
      expect(PeripheralStrings.policyOptions[1]).assertEqual('禁止接入')
      expect(PeripheralStrings.interfaceToggleOptions[0]).assertEqual('启用')
      expect(PeripheralStrings.interfaceToggleOptions[1]).assertEqual('禁用')
    })
  })
}
