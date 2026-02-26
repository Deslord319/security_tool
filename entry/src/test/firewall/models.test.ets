/**
 * 防火墙模块 - 数据模型单元测试
 * 测试防火墙规则相关的标签函数
 */
import { describe, it, expect } from '@ohos/hypium'
import {
  RuleType, RuleDirection, ProtocolType, RuleAction,
  getRuleTypeLabel, getDirectionLabel, getProtocolLabel, getActionLabel
} from '../../../main/ets/models/DataModels'

export default function firewallModelsTest() {
  describe('Firewall Models', () => {

    describe('getRuleTypeLabel', () => {
      it('should return IP for RuleType.IP', 0, () => {
        expect(getRuleTypeLabel(RuleType.IP)).assertEqual('IP')
      })

      it('should return 域名 for RuleType.DOMAIN', 0, () => {
        expect(getRuleTypeLabel(RuleType.DOMAIN)).assertEqual('域名')
      })

      it('should return DNS for RuleType.DNS', 0, () => {
        expect(getRuleTypeLabel(RuleType.DNS)).assertEqual('DNS')
      })

      it('should return 未知 for invalid type', 0, () => {
        expect(getRuleTypeLabel(99 as RuleType)).assertEqual('未知')
      })
    })

    describe('getDirectionLabel', () => {
      it('should return 入站 for RuleDirection.IN', 0, () => {
        expect(getDirectionLabel(RuleDirection.IN)).assertEqual('入站')
      })

      it('should return 出站 for RuleDirection.OUT', 0, () => {
        expect(getDirectionLabel(RuleDirection.OUT)).assertEqual('出站')
      })

      it('should return 未知 for invalid direction', 0, () => {
        expect(getDirectionLabel(99 as RuleDirection)).assertEqual('未知')
      })
    })

    describe('getProtocolLabel', () => {
      it('should return ALL for ProtocolType.ALL', 0, () => {
        expect(getProtocolLabel(ProtocolType.ALL)).assertEqual('ALL')
      })

      it('should return TCP for ProtocolType.TCP', 0, () => {
        expect(getProtocolLabel(ProtocolType.TCP)).assertEqual('TCP')
      })

      it('should return UDP for ProtocolType.UDP', 0, () => {
        expect(getProtocolLabel(ProtocolType.UDP)).assertEqual('UDP')
      })

      it('should return ICMP for ProtocolType.ICMP', 0, () => {
        expect(getProtocolLabel(ProtocolType.ICMP)).assertEqual('ICMP')
      })

      it('should return ALL for invalid protocol', 0, () => {
        expect(getProtocolLabel(99 as ProtocolType)).assertEqual('ALL')
      })
    })

    describe('getActionLabel', () => {
      it('should return 允许 for RuleAction.ALLOW', 0, () => {
        expect(getActionLabel(RuleAction.ALLOW)).assertEqual('允许')
      })

      it('should return 拒绝 for RuleAction.DENY', 0, () => {
        expect(getActionLabel(RuleAction.DENY)).assertEqual('拒绝')
      })

      it('should return 未知 for invalid action', 0, () => {
        expect(getActionLabel(99 as RuleAction)).assertEqual('未知')
      })
    })

  })
}
