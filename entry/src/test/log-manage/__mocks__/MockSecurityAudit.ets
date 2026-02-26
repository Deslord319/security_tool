/**
 * Mock securityAudit API
 * 模拟 @kit.DeviceSecurityKit 的 securityAudit 模块
 * 用于 L2 服务层测试
 */

// 模拟 AuditEvent 结构
export class MockAuditEvent {
  timestamp: number = 0
  eventId: number = 0
  content: string = ''
}

// 订阅回调类型
type AuditCallback = (event: MockAuditEvent) => void

// 模块级状态
let subscribedCallback: AuditCallback | null = null
let isSubscribed: boolean = false
let shouldFail: boolean = false
let failErrorMessage: string = 'Mock SecurityAudit API Error'
let emittedEvents: MockAuditEvent[] = []

// ==================== 测试控制方法 ====================

/**
 * 重置所有 Mock 状态
 */
export function resetMock(): void {
  subscribedCallback = null
  isSubscribed = false
  shouldFail = false
  failErrorMessage = 'Mock SecurityAudit API Error'
  emittedEvents = []
}

/**
 * 设置失败模式
 */
export function setFailMode(fail: boolean, errorMsg?: string): void {
  shouldFail = fail
  if (errorMsg !== undefined) {
    failErrorMessage = errorMsg
  }
}

/**
 * 获取订阅状态
 */
export function getSubscriptionStatus(): boolean {
  return isSubscribed
}

/**
 * 模拟系统发送审计事件（测试用）
 */
export function emitAuditEvent(event: MockAuditEvent): void {
  emittedEvents.push(event)
  if (subscribedCallback && isSubscribed) {
    subscribedCallback(event)
  }
}

/**
 * 获取已发送的事件列表
 */
export function getEmittedEvents(): MockAuditEvent[] {
  let result: MockAuditEvent[] = []
  for (let event of emittedEvents) {
    result.push(event)
  }
  return result
}

// ==================== 模拟 securityAudit API ====================

/**
 * 模拟 securityAudit.on('securityAudit', callback)
 */
export function onSecurityAudit(type: string, callback: AuditCallback): void {
  if (shouldFail) {
    throw new Error(failErrorMessage)
  }
  if (type !== 'securityAudit') {
    throw new Error(`Unknown event type: ${type}`)
  }
  subscribedCallback = callback
  isSubscribed = true
}

/**
 * 模拟 securityAudit.off('securityAudit')
 */
export function offSecurityAudit(type: string): void {
  if (shouldFail) {
    throw new Error(failErrorMessage)
  }
  if (type !== 'securityAudit') {
    throw new Error(`Unknown event type: ${type}`)
  }
  subscribedCallback = null
  isSubscribed = false
}

// 创建 MockAuditEvent 辅助函数
export function createMockAuditEvent(
  eventId: number,
  content: string,
  timestamp?: number
): MockAuditEvent {
  let event = new MockAuditEvent()
  event.eventId = eventId
  event.content = content
  event.timestamp = timestamp !== undefined ? timestamp : Date.now()
  return event
}
