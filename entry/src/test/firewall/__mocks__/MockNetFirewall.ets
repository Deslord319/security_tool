/**
 * Mock netFirewall API
 * 用于服务层测试，模拟系统 API 行为
 * 注意：符合 ArkTS 语法规范
 */

// 模拟 netFirewall 模块的类型定义
export class MockNetFirewallRule {
  ruleId: number = 0
  userId: number = 0
  name: string = ''
  direction: number = 1  // 1=IN, 2=OUT
  action: number = 0     // 0=ALLOW, 1=DENY
  type: number = 1       // 1=IP, 2=DOMAIN, 3=DNS
  isEnabled: boolean = true
  protocol: number = 0
}

export class MockNetFirewallPolicy {
  isOpen: boolean = false
  inAction: number = 0
  outAction: number = 0
}

export class MockRequestParam {
  page: number = 1
  pageSize: number = 50
  orderField: number = 0
  orderType: number = 0
}

export class MockPageResult {
  data: MockNetFirewallRule[] = []
  totalCount: number = 0
}

// 模块级变量（替代静态属性）
let mockRules: MockNetFirewallRule[] = []
let mockPolicy: MockNetFirewallPolicy = new MockNetFirewallPolicy()
let nextRuleId: number = 1
let shouldFail: boolean = false
let failErrorMessage: string = 'Mock API Error'

/**
 * Mock netFirewall 实现
 * 使用模块函数替代静态方法，符合 ArkTS 规范
 */

// ==================== 测试数据控制方法 ====================

/**
 * 重置所有 Mock 状态
 */
export function resetMock(): void {
  mockRules = []
  mockPolicy = new MockNetFirewallPolicy()
  mockPolicy.isOpen = false
  mockPolicy.inAction = 0
  mockPolicy.outAction = 0
  nextRuleId = 1
  shouldFail = false
  failErrorMessage = 'Mock API Error'
}

/**
 * 设置 Mock 规则数据
 */
export function setMockRules(rules: MockNetFirewallRule[]): void {
  mockRules = []
  for (let i = 0; i < rules.length; i++) {
    let rule = new MockNetFirewallRule()
    rule.ruleId = rules[i].ruleId > 0 ? rules[i].ruleId : i + 1
    rule.userId = rules[i].userId
    rule.name = rules[i].name
    rule.direction = rules[i].direction
    rule.action = rules[i].action
    rule.type = rules[i].type
    rule.isEnabled = rules[i].isEnabled
    rule.protocol = rules[i].protocol
    mockRules.push(rule)
  }
  nextRuleId = mockRules.length + 1
}

/**
 * 设置 Mock 策略数据
 */
export function setMockPolicy(policy: MockNetFirewallPolicy): void {
  mockPolicy = new MockNetFirewallPolicy()
  mockPolicy.isOpen = policy.isOpen
  mockPolicy.inAction = policy.inAction
  mockPolicy.outAction = policy.outAction
}

/**
 * 设置失败模式（模拟 API 调用失败）
 */
export function setFailMode(fail: boolean, errorMsg?: string): void {
  shouldFail = fail
  if (errorMsg !== undefined) {
    failErrorMessage = errorMsg
  }
}

/**
 * 获取当前 Mock 规则（用于测试验证）
 */
export function getMockRules(): MockNetFirewallRule[] {
  let result: MockNetFirewallRule[] = []
  for (let rule of mockRules) {
    result.push(rule)
  }
  return result
}

/**
 * 获取当前 Mock 策略（用于测试验证）
 */
export function getMockPolicy(): MockNetFirewallPolicy {
  let result = new MockNetFirewallPolicy()
  result.isOpen = mockPolicy.isOpen
  result.inAction = mockPolicy.inAction
  result.outAction = mockPolicy.outAction
  return result
}

// ==================== 模拟 API 方法 ====================

/**
 * 获取防火墙策略
 */
export async function getNetFirewallPolicy(userId: number): Promise<MockNetFirewallPolicy> {
  if (shouldFail) {
    throw new Error(failErrorMessage)
  }
  let result = new MockNetFirewallPolicy()
  result.isOpen = mockPolicy.isOpen
  result.inAction = mockPolicy.inAction
  result.outAction = mockPolicy.outAction
  return result
}

/**
 * 设置防火墙策略
 */
export async function setNetFirewallPolicy(userId: number, policy: MockNetFirewallPolicy): Promise<void> {
  if (shouldFail) {
    throw new Error(failErrorMessage)
  }
  mockPolicy.isOpen = policy.isOpen
  mockPolicy.inAction = policy.inAction
  mockPolicy.outAction = policy.outAction
}

/**
 * 获取防火墙规则列表
 */
export async function getNetFirewallRules(userId: number, params: MockRequestParam): Promise<MockPageResult> {
  if (shouldFail) {
    throw new Error(failErrorMessage)
  }

  // 简单分页模拟
  let start = (params.page - 1) * params.pageSize
  let end = start + params.pageSize
  if (end > mockRules.length) {
    end = mockRules.length
  }

  let result = new MockPageResult()
  result.data = []
  for (let i = start; i < end; i++) {
    result.data.push(mockRules[i])
  }
  result.totalCount = mockRules.length

  return result
}

/**
 * 添加防火墙规则
 */
export async function addNetFirewallRule(rule: MockNetFirewallRule): Promise<number> {
  if (shouldFail) {
    throw new Error(failErrorMessage)
  }
  let newRule = new MockNetFirewallRule()
  newRule.ruleId = nextRuleId
  nextRuleId++
  newRule.userId = rule.userId
  newRule.name = rule.name
  newRule.direction = rule.direction
  newRule.action = rule.action
  newRule.type = rule.type
  newRule.isEnabled = rule.isEnabled
  newRule.protocol = rule.protocol
  mockRules.push(newRule)
  return newRule.ruleId
}

/**
 * 删除防火墙规则
 */
export async function removeNetFirewallRule(userId: number, ruleId: number): Promise<void> {
  if (shouldFail) {
    throw new Error(failErrorMessage)
  }
  let newRules: MockNetFirewallRule[] = []
  for (let rule of mockRules) {
    if (rule.ruleId !== ruleId) {
      newRules.push(rule)
    }
  }
  mockRules = newRules
}

// 模拟枚举值（与真实 API 保持一致）
export class MockNetFirewallRuleType {
  static readonly RULE_IP: number = 1
  static readonly RULE_DOMAIN: number = 2
  static readonly RULE_DNS: number = 3
}

export class MockNetFirewallRuleDirection {
  static readonly RULE_IN: number = 1
  static readonly RULE_OUT: number = 2
}

export class MockFirewallRuleAction {
  static readonly RULE_ALLOW: number = 0
  static readonly RULE_DENY: number = 1
}
