import { describe, expect, it } from '@ohos/hypium'
import {
  CommonLabelStrings,
  DeviceDetailStrings,
  DeviceTypeLabels,
  DialogButtonStrings,
  EmptyStateStrings,
  FirewallDialogStrings,
  FirewallRuleLabelStrings,
  LoadingStrings,
  ResultStrings,
  ValidationErrorStrings
} from '../../main/ets/constants/modules/DialogStrings'

export default function dialogStringsTest() {
  describe('DialogStrings', () => {
    it('should expose shared button, loading and empty-state copy', 0, () => {
      expect(DialogButtonStrings.CONFIRM).assertEqual('确定')
      expect(DialogButtonStrings.CANCEL).assertEqual('取消')
      expect(LoadingStrings.LOADING_POLICY).assertEqual('正在读取防火墙状态...')
      expect(EmptyStateStrings.CHECK_PERMISSIONS).assertEqual('请检查账户权限或系统账户状态')
      expect(ResultStrings.SAVE_SUCCESS).assertEqual('保存成功')
    })

    it('should expose firewall dialog labels and builders', 0, () => {
      expect(FirewallDialogStrings.RULE_NAME_PLACEHOLDER).assertEqual('请输入规则名称')
      expect(FirewallDialogStrings.MODE_ALLOWLIST).assertEqual('白名单模式')
      expect(FirewallDialogStrings.buildPolicySummary(true, '允许', '阻止'))
        .assertEqual('主开关已开启，默认入站允许，默认出站阻止')
      expect(FirewallDialogStrings.buildApplyModeSuccess(3)).assertEqual('策略下发成功，本次下发 3 条规则')
    })

    it('should expose device detail and shared label strings', 0, () => {
      expect(DeviceDetailStrings.TITLE).assertEqual('设备详情')
      expect(DeviceDetailStrings.HISTORY_COUNT_SUFFIX).assertEqual('条')
      expect(DeviceTypeLabels.BLUETOOTH).assertEqual('蓝牙设备')
      expect(CommonLabelStrings.ALL).assertEqual('全部')
      expect(FirewallRuleLabelStrings.DOMAIN_RULE).assertEqual('域名规则')
    })

    it('should expose validation copy used by pages', 0, () => {
      expect(ValidationErrorStrings.PIN_FAILED).assertEqual('PIN 验证失败，已取消本次变更')
      expect(ValidationErrorStrings.PERMISSION_DENIED).assertEqual('权限不足')
      expect(ValidationErrorStrings.STATUS_UNKNOWN).assertEqual('状态未知')
    })
  })
}
