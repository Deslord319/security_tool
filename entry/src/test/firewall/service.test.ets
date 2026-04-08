/**
 * 防火墙模块 - 服务层测试
 * 使用 Mock 数据测试业务逻辑
 */
import { describe, beforeEach, it, expect } from '@ohos/hypium'
import { netFirewall } from '@kit.NetworkKit'
import {
  MockNetFirewallRule,
  MockNetFirewallPolicy,
  MockRequestParam,
  MockNetFirewallRuleType,
  MockNetFirewallRuleDirection,
  MockFirewallRuleAction,
  resetMock,
  setMockRules,
  setMockPolicy,
  setFailMode,
  getMockRules,
  getMockPolicy,
  getNetFirewallPolicy,
  setNetFirewallPolicy,
  getNetFirewallRules,
  addNetFirewallRule,
  removeNetFirewallRule,
  updateNetFirewallRule
} from './__mocks__/MockNetFirewall'
import { FirewallRepository } from '../../main/ets/services/firewall/repositories/FirewallRepository'

// 辅助函数：创建规则对象
function createRule(userId: number, name: string, direction: number, action: number, type: number, isEnabled: boolean, ruleId?: number): MockNetFirewallRule {
  let rule = new MockNetFirewallRule()
  if (ruleId !== undefined) {
    rule.ruleId = ruleId
  }
  rule.userId = userId
  rule.name = name
  rule.direction = direction
  rule.action = action
  rule.type = type
  rule.isEnabled = isEnabled
  return rule
}

// 辅助函数：创建策略对象
function createPolicy(isOpen: boolean, inAction: number, outAction: number): MockNetFirewallPolicy {
  let policy = new MockNetFirewallPolicy()
  policy.isOpen = isOpen
  policy.inAction = inAction
  policy.outAction = outAction
  return policy
}

// 辅助函数：创建请求参数
function createRequestParam(page: number, pageSize: number): MockRequestParam {
  let param = new MockRequestParam()
  param.page = page
  param.pageSize = pageSize
  return param
}

export default function firewallServiceTest() {
  describe('FirewallService', () => {

    // 每个测试前重置 Mock 状态
    beforeEach(() => {
      resetMock()
    })

    // ==================== countByType 测试 ====================

    describe('countByType', () => {
      beforeEach(() => {
        resetMock()
      })

      it('should count IP rules correctly', 0, () => {
        let rules: MockNetFirewallRule[] = [
          createRule(100, 'rule1', 1, 0, MockNetFirewallRuleType.RULE_IP, true),
          createRule(100, 'rule2', 1, 0, MockNetFirewallRuleType.RULE_IP, true),
          createRule(100, 'rule3', 1, 0, MockNetFirewallRuleType.RULE_DOMAIN, true),
          createRule(100, 'rule4', 1, 0, MockNetFirewallRuleType.RULE_DNS, true),
        ]

        let ipCount = 0
        let domainCount = 0
        let dnsCount = 0
        for (let r of rules) {
          if (r.type === MockNetFirewallRuleType.RULE_IP) ipCount++
          if (r.type === MockNetFirewallRuleType.RULE_DOMAIN) domainCount++
          if (r.type === MockNetFirewallRuleType.RULE_DNS) dnsCount++
        }

        expect(ipCount).assertEqual(2)
        expect(domainCount).assertEqual(1)
        expect(dnsCount).assertEqual(1)
      })

      it('should return 0 for empty rules', 0, () => {
        let rules: MockNetFirewallRule[] = []
        let count = 0
        for (let r of rules) {
          if (r.type === MockNetFirewallRuleType.RULE_IP) count++
        }
        expect(count).assertEqual(0)
      })

      it('should handle rules with only one type', 0, () => {
        let rules: MockNetFirewallRule[] = [
          createRule(100, 'rule1', 1, 0, MockNetFirewallRuleType.RULE_DOMAIN, true),
          createRule(100, 'rule2', 1, 0, MockNetFirewallRuleType.RULE_DOMAIN, true),
        ]

        let ipCount = 0
        let domainCount = 0
        for (let r of rules) {
          if (r.type === MockNetFirewallRuleType.RULE_IP) ipCount++
          if (r.type === MockNetFirewallRuleType.RULE_DOMAIN) domainCount++
        }

        expect(ipCount).assertEqual(0)
        expect(domainCount).assertEqual(2)
      })
    })

    // ==================== countByDirection 测试 ====================

    describe('countByDirection', () => {
      beforeEach(() => {
        resetMock()
      })

      it('should count IN and OUT rules correctly', 0, () => {
        let rules: MockNetFirewallRule[] = [
          createRule(100, 'rule1', MockNetFirewallRuleDirection.RULE_IN, 0, 1, true),
          createRule(100, 'rule2', MockNetFirewallRuleDirection.RULE_IN, 0, 1, true),
          createRule(100, 'rule3', MockNetFirewallRuleDirection.RULE_OUT, 0, 1, true),
        ]

        let inCount = 0
        let outCount = 0
        for (let r of rules) {
          if (r.direction === MockNetFirewallRuleDirection.RULE_IN) inCount++
          if (r.direction === MockNetFirewallRuleDirection.RULE_OUT) outCount++
        }

        expect(inCount).assertEqual(2)
        expect(outCount).assertEqual(1)
      })

      it('should return 0 for empty rules', 0, () => {
        let rules: MockNetFirewallRule[] = []
        let inCount = 0
        for (let r of rules) {
          if (r.direction === MockNetFirewallRuleDirection.RULE_IN) inCount++
        }
        expect(inCount).assertEqual(0)
      })
    })

    // ==================== getFirewallPolicy 测试（使用 Mock）====================

    describe('getFirewallPolicy with Mock', () => {
      beforeEach(() => {
        resetMock()
      })

      it('should return policy when firewall is open', 0, async () => {
        setMockPolicy(createPolicy(true, 0, 0))
        let policy = await getNetFirewallPolicy(100)
        expect(policy.isOpen).assertTrue()
      })

      it('should return policy when firewall is closed', 0, async () => {
        setMockPolicy(createPolicy(false, 0, 0))
        let policy = await getNetFirewallPolicy(100)
        expect(policy.isOpen).assertFalse()
      })

      it('should preserve inAction and outAction', 0, async () => {
        setMockPolicy(createPolicy(true, 1, 0))
        let policy = await getNetFirewallPolicy(100)
        expect(policy.inAction).assertEqual(1)
        expect(policy.outAction).assertEqual(0)
      })
    })

    // ==================== setFirewallPolicy 测试 ====================

    describe('setFirewallPolicy with Mock', () => {
      beforeEach(() => {
        resetMock()
      })

      it('should update policy correctly', 0, async () => {
        await setNetFirewallPolicy(100, createPolicy(true, 1, 1))
        let policy = getMockPolicy()
        expect(policy.isOpen).assertTrue()
        expect(policy.inAction).assertEqual(1)
        expect(policy.outAction).assertEqual(1)
      })

      it('should toggle firewall state', 0, async () => {
        // 初始关闭
        setMockPolicy(createPolicy(false, 0, 0))
        let before = await getNetFirewallPolicy(100)
        expect(before.isOpen).assertFalse()

        // 打开
        await setNetFirewallPolicy(100, createPolicy(true, 0, 0))
        let after = await getNetFirewallPolicy(100)
        expect(after.isOpen).assertTrue()
      })
    })

    // ==================== getAllRules 测试（使用 Mock）====================

    describe('getAllRules with Mock', () => {
      beforeEach(() => {
        resetMock()
      })

      it('should return all rules', 0, async () => {
        setMockRules([
          createRule(100, 'rule1', 1, 0, 1, true),
          createRule(100, 'rule2', 2, 1, 2, false),
        ])

        let result = await getNetFirewallRules(100, createRequestParam(1, 50))
        expect(result.data.length).assertEqual(2)
        expect(result.data[0].name).assertEqual('rule1')
        expect(result.data[1].name).assertEqual('rule2')
      })

      it('should return empty array when no rules', 0, async () => {
        let result = await getNetFirewallRules(100, createRequestParam(1, 50))
        expect(result.data.length).assertEqual(0)
      })

      it('should handle pagination correctly', 0, async () => {
        setMockRules([
          createRule(100, 'rule1', 1, 0, 1, true),
          createRule(100, 'rule2', 1, 0, 1, true),
          createRule(100, 'rule3', 1, 0, 1, true),
        ])

        let page1 = await getNetFirewallRules(100, createRequestParam(1, 2))
        expect(page1.data.length).assertEqual(2)
        expect(page1.totalCount).assertEqual(3)

        let page2 = await getNetFirewallRules(100, createRequestParam(2, 2))
        expect(page2.data.length).assertEqual(1)
      })
    })

    // ==================== addRule 测试（使用 Mock）====================

    describe('addRule with Mock', () => {
      beforeEach(() => {
        resetMock()
      })

      it('should add rule and return new ruleId', 0, async () => {
        let newRule = createRule(100, 'Test Rule', MockNetFirewallRuleDirection.RULE_IN, MockFirewallRuleAction.RULE_ALLOW, MockNetFirewallRuleType.RULE_IP, true)

        let ruleId = await addNetFirewallRule(newRule)
        expect(ruleId).assertLarger(0)

        let rules = getMockRules()
        expect(rules.length).assertEqual(1)
        expect(rules[0].name).assertEqual('Test Rule')
        expect(rules[0].ruleId).assertEqual(ruleId)
      })

      it('should assign incremental ruleIds', 0, async () => {
        let rule1 = createRule(100, 'rule1', 1, 0, 1, true)
        let rule2 = createRule(100, 'rule2', 1, 0, 1, true)

        let id1 = await addNetFirewallRule(rule1)
        let id2 = await addNetFirewallRule(rule2)

        expect(id2).assertEqual(id1 + 1)
      })

      it('should handle API failure', 0, async () => {
        setFailMode(true, 'Permission denied')

        let error: Error | null = null
        try {
          await addNetFirewallRule(createRule(100, 'Test', 1, 0, 1, true))
        } catch (e) {
          error = e as Error
        }

        expect(error !== null).assertTrue()
        expect(error!.message).assertEqual('Permission denied')
      })
    })

    describe('FirewallRepository clone and normalize', () => {
      it('should keep remoteIps when cloning a normal IP rule', 0, () => {
        let rule: netFirewall.NetFirewallRule = {
          userId: 100,
          name: 'ip rule with remote address',
          direction: netFirewall.NetFirewallRuleDirection.RULE_IN,
          action: netFirewall.FirewallRuleAction.RULE_ALLOW,
          type: netFirewall.NetFirewallRuleType.RULE_IP,
          isEnabled: true,
          protocol: 6,
          remoteIps: [{
            type: 1,
            family: 1,
            address: '192.168.10.20',
            mask: 24
          }]
        }

        let clonedRule = FirewallRepository.cloneRuleForCreate(rule)
        expect(clonedRule.remoteIps !== undefined).assertTrue()
        expect(clonedRule.remoteIps?.length ?? 0).assertEqual(1)
        expect(clonedRule.remoteIps?.[0].address ?? '').assertEqual('192.168.10.20')
        expect(clonedRule.remoteIps?.[0].mask ?? -1).assertEqual(24)
      })

      it('should still drop any-ipv4 remoteIps when normalizing create payload', 0, () => {
        let rule: netFirewall.NetFirewallRule = {
          userId: 100,
          name: 'any ipv4',
          direction: netFirewall.NetFirewallRuleDirection.RULE_IN,
          action: netFirewall.FirewallRuleAction.RULE_ALLOW,
          type: netFirewall.NetFirewallRuleType.RULE_IP,
          isEnabled: true,
          protocol: 1,
          remoteIps: [{
            type: 1,
            family: 1,
            address: '0.0.0.0',
            mask: 0
          }]
        }

        let normalizedRule = FirewallRepository.normalizeRuleForCreate(rule)
        expect(normalizedRule.remoteIps === undefined).assertTrue()
      })
    })

    // ==================== removeRule 测试 ====================

    describe('removeRule with Mock', () => {
      beforeEach(() => {
        resetMock()
      })

      it('should remove rule by ruleId', 0, async () => {
        setMockRules([
          createRule(100, 'rule1', 1, 0, 1, true, 1),
          createRule(100, 'rule2', 1, 0, 1, true, 2),
        ])

        await removeNetFirewallRule(100, 1)

        let rules = getMockRules()
        expect(rules.length).assertEqual(1)
        expect(rules[0].ruleId).assertEqual(2)
      })

      it('should do nothing when rule not found', 0, async () => {
        setMockRules([
          createRule(100, 'rule1', 1, 0, 1, true, 1),
        ])

        await removeNetFirewallRule(100, 999)

        let rules = getMockRules()
        expect(rules.length).assertEqual(1)
      })

      it('should handle removing all rules', 0, async () => {
        setMockRules([
          createRule(100, 'rule1', 1, 0, 1, true, 1),
        ])

        await removeNetFirewallRule(100, 1)

        let rules = getMockRules()
        expect(rules.length).assertEqual(0)
      })
    })

    // ==================== updateRule 测试 ====================

    describe('updateRule with Mock', () => {
      beforeEach(() => {
        resetMock()
      })

      it('should update existing rule', 0, async () => {
        setMockRules([
          createRule(100, 'original', 1, 0, 1, true, 1),
        ])

        await updateNetFirewallRule(createRule(100, 'updated', 2, 1, 1, false, 1))

        let rules = getMockRules()
        expect(rules[0].name).assertEqual('updated')
        expect(rules[0].direction).assertEqual(2)
        expect(rules[0].action).assertEqual(1)
        expect(rules[0].isEnabled).assertFalse()
      })

      it('should not modify other rules', 0, async () => {
        setMockRules([
          createRule(100, 'rule1', 1, 0, 1, true, 1),
          createRule(100, 'rule2', 1, 0, 1, true, 2),
        ])

        await updateNetFirewallRule(createRule(100, 'updated', 1, 0, 1, true, 1))

        let rules = getMockRules()
        expect(rules[1].name).assertEqual('rule2')
      })
    })

    // ==================== 复合场景测试 ====================

    describe('Complex scenarios', () => {
      beforeEach(() => {
        resetMock()
      })

      it('should handle add then remove correctly', 0, async () => {
        // 添加
        let ruleId = await addNetFirewallRule(createRule(100, 'temp', 1, 0, 1, true))
        expect(getMockRules().length).assertEqual(1)

        // 删除
        await removeNetFirewallRule(100, ruleId)
        expect(getMockRules().length).assertEqual(0)
      })

      it('should handle multiple operations in sequence', 0, async () => {
        // 添加多条
        await addNetFirewallRule(createRule(100, 'rule1', 1, 0, 1, true))
        await addNetFirewallRule(createRule(100, 'rule2', 1, 0, 2, true))
        await addNetFirewallRule(createRule(100, 'rule3', 2, 1, 3, true))

        let rules = getMockRules()
        expect(rules.length).assertEqual(3)

        // 统计
        let ipCount = 0
        let inCount = 0
        for (let r of rules) {
          if (r.type === 1) ipCount++
          if (r.direction === 1) inCount++
        }
        expect(ipCount).assertEqual(1)
        expect(inCount).assertEqual(2)

        // 删除一条
        await removeNetFirewallRule(100, 2)
        expect(getMockRules().length).assertEqual(2)
      })
    })

  })
}
