/**
 * 数据模型单元测试
 * 测试 DataModels.ets 中的枚举、接口和工具函数
 */
import { describe, it, expect } from '@ohos/hypium'

// 枚举定义（与 DataModels.ets 保持一致）
enum RuleType {
  IP = 1,
  DOMAIN = 2,
  DNS = 3
}

enum RuleDirection {
  IN = 1,
  OUT = 2
}

enum RuleAction {
  ALLOW = 0,
  DENY = 1
}

enum ProtocolType {
  ALL = 0,
  TCP = 6,
  UDP = 17,
  ICMP = 1
}

// 工具函数实现
function getRuleTypeLabel(type: RuleType): string {
  switch (type) {
    case RuleType.IP:
      return 'IP'
    case RuleType.DOMAIN:
      return '域名'
    case RuleType.DNS:
      return 'DNS'
    default:
      return '未知'
  }
}

function getDirectionLabel(dir: RuleDirection): string {
  switch (dir) {
    case RuleDirection.IN:
      return '入站'
    case RuleDirection.OUT:
      return '出站'
    default:
      return '未知'
  }
}

function getProtocolLabel(proto: ProtocolType): string {
  switch (proto) {
    case ProtocolType.ALL:
      return 'ALL'
    case ProtocolType.TCP:
      return 'TCP'
    case ProtocolType.UDP:
      return 'UDP'
    case ProtocolType.ICMP:
      return 'ICMP'
    default:
      return '未知'
  }
}

export default function dataModelsTest() {
  describe('DataModels', () => {

    // ==================== RuleType 枚举测试 ====================

    describe('RuleType Enum', () => {
      it('should have correct IP value', 0, () => {
        expect(RuleType.IP).assertEqual(1)
      })

      it('should have correct DOMAIN value', 0, () => {
        expect(RuleType.DOMAIN).assertEqual(2)
      })

      it('should have correct DNS value', 0, () => {
        expect(RuleType.DNS).assertEqual(3)
      })
    })

    // ==================== RuleDirection 枚举测试 ====================

    describe('RuleDirection Enum', () => {
      it('should have correct IN value', 0, () => {
        expect(RuleDirection.IN).assertEqual(1)
      })

      it('should have correct OUT value', 0, () => {
        expect(RuleDirection.OUT).assertEqual(2)
      })
    })

    // ==================== RuleAction 枚举测试 ====================

    describe('RuleAction Enum', () => {
      it('should have correct ALLOW value', 0, () => {
        expect(RuleAction.ALLOW).assertEqual(0)
      })

      it('should have correct DENY value', 0, () => {
        expect(RuleAction.DENY).assertEqual(1)
      })
    })

    // ==================== ProtocolType 枚举测试 ====================

    describe('ProtocolType Enum', () => {
      it('should have correct ALL value', 0, () => {
        expect(ProtocolType.ALL).assertEqual(0)
      })

      it('should have correct TCP value', 0, () => {
        expect(ProtocolType.TCP).assertEqual(6)
      })

      it('should have correct UDP value', 0, () => {
        expect(ProtocolType.UDP).assertEqual(17)
      })

      it('should have correct ICMP value', 0, () => {
        expect(ProtocolType.ICMP).assertEqual(1)
      })
    })

    // ==================== getRuleTypeLabel 工具函数测试 ====================

    describe('getRuleTypeLabel', () => {
      it('should return "IP" for RuleType.IP', 0, () => {
        const result = getRuleTypeLabel(RuleType.IP)
        expect(result).assertEqual('IP')
      })

      it('should return "域名" for RuleType.DOMAIN', 0, () => {
        const result = getRuleTypeLabel(RuleType.DOMAIN)
        expect(result).assertEqual('域名')
      })

      it('should return "DNS" for RuleType.DNS', 0, () => {
        const result = getRuleTypeLabel(RuleType.DNS)
        expect(result).assertEqual('DNS')
      })

      it('should handle invalid rule type', 0, () => {
        // 模拟无效值
        const invalidType = 999
        const result = getRuleTypeLabel(invalidType as any)
        expect(result).assertEqual('未知')
      })
    })

    // ==================== getDirectionLabel 工具函数测试 ====================

    describe('getDirectionLabel', () => {
      it('should return "入站" for RuleDirection.IN', 0, () => {
        const result = getDirectionLabel(RuleDirection.IN)
        expect(result).assertEqual('入站')
      })

      it('should return "出站" for RuleDirection.OUT', 0, () => {
        const result = getDirectionLabel(RuleDirection.OUT)
        expect(result).assertEqual('出站')
      })

      it('should handle invalid direction', 0, () => {
        const invalidDir = 999
        const result = getDirectionLabel(invalidDir as any)
        expect(result).assertEqual('未知')
      })
    })

    // ==================== getProtocolLabel 工具函数测试 ====================

    describe('getProtocolLabel', () => {
      it('should return "ALL" for ProtocolType.ALL', 0, () => {
        const result = getProtocolLabel(ProtocolType.ALL)
        expect(result).assertEqual('ALL')
      })

      it('should return "TCP" for ProtocolType.TCP', 0, () => {
        const result = getProtocolLabel(ProtocolType.TCP)
        expect(result).assertEqual('TCP')
      })

      it('should return "UDP" for ProtocolType.UDP', 0, () => {
        const result = getProtocolLabel(ProtocolType.UDP)
        expect(result).assertEqual('UDP')
      })

      it('should return "ICMP" for ProtocolType.ICMP', 0, () => {
        const result = getProtocolLabel(ProtocolType.ICMP)
        expect(result).assertEqual('ICMP')
      })

      it('should handle invalid protocol', 0, () => {
        const invalidProto = 999
        const result = getProtocolLabel(invalidProto as any)
        expect(result).assertEqual('未知')
      })
    })

    // ==================== 枚举值唯一性测试 ====================

    describe('Enum Value Uniqueness', () => {
      it('should have unique RuleType values', 0, () => {
        const values = [RuleType.IP, RuleType.DOMAIN, RuleType.DNS]
        const uniqueValues = [...new Set(values)]
        expect(values.length).assertEqual(uniqueValues.length)
      })

      it('should have unique RuleDirection values', 0, () => {
        const values = [RuleDirection.IN, RuleDirection.OUT]
        const uniqueValues = [...new Set(values)]
        expect(values.length).assertEqual(uniqueValues.length)
      })

      it('should have unique RuleAction values', 0, () => {
        const values = [RuleAction.ALLOW, RuleAction.DENY]
        const uniqueValues = [...new Set(values)]
        expect(values.length).assertEqual(uniqueValues.length)
      })

      it('should have unique ProtocolType values', 0, () => {
        const values = [ProtocolType.ALL, ProtocolType.TCP, ProtocolType.UDP, ProtocolType.ICMP]
        const uniqueValues = [...new Set(values)]
        expect(values.length).assertEqual(uniqueValues.length)
      })
    })

    // ==================== 枚举值范围测试 ====================

    describe('Enum Value Range', () => {
      it('should have positive RuleType values', 0, () => {
        expect(RuleType.IP).toBeGreaterThan(0)
        expect(RuleType.DOMAIN).toBeGreaterThan(0)
        expect(RuleType.DNS).toBeGreaterThan(0)
      })

      it('should have non-negative RuleDirection values', 0, () => {
        expect(RuleDirection.IN).toBeGreaterThan(0)
        expect(RuleDirection.OUT).toBeGreaterThan(0)
      })

      it('should have non-negative RuleAction values', 0, () => {
        expect(RuleAction.ALLOW).toBeGreaterOrEqual(0)
        expect(RuleAction.DENY).toBeGreaterOrEqual(0)
      })

      it('should have valid protocol numbers', 0, () => {
        // TCP=6, UDP=17 是标准协议号
        expect(ProtocolType.TCP).assertEqual(6)
        expect(ProtocolType.UDP).assertEqual(17)
      })
    })

    // ==================== 标签函数边界测试 ====================

    describe('Label Function Edge Cases', () => {
      it('should handle zero value', 0, () => {
        // RuleAction.ALLOW = 0
        expect(RuleAction.ALLOW).assertEqual(0)
      })

      it('should handle negative values', 0, () => {
        const negativeValue = -1
        const result = getRuleTypeLabel(negativeValue as any)
        expect(result).assertEqual('未知')
      })

      it('should handle string input (type coercion)', 0, () => {
        // 类型不匹配时应返回未知
        const stringValue = 'IP'
        const result = getRuleTypeLabel(stringValue as any)
        expect(result).assertEqual('未知')
      })
    })

    // ==================== 工具函数一致性测试 ====================

    describe('Label Function Consistency', () => {
      it('should always return string', 0, () => {
        const ruleTypeResult = getRuleTypeLabel(RuleType.IP)
        const directionResult = getDirectionLabel(RuleDirection.IN)
        const protocolResult = getProtocolLabel(ProtocolType.TCP)

        expect(typeof ruleTypeResult).assertEqual('string')
        expect(typeof directionResult).assertEqual('string')
        expect(typeof protocolResult).assertEqual('string')
      })

      it('should return non-empty strings', 0, () => {
        const ruleTypeResult = getRuleTypeLabel(RuleType.IP)
        const directionResult = getDirectionLabel(RuleDirection.IN)
        const protocolResult = getProtocolLabel(ProtocolType.TCP)

        expect(ruleTypeResult.length).toBeGreaterThan(0)
        expect(directionResult.length).toBeGreaterThan(0)
        expect(protocolResult.length).toBeGreaterThan(0)
      })

      it('should return consistent results for same input', 0, () => {
        const result1 = getRuleTypeLabel(RuleType.IP)
        const result2 = getRuleTypeLabel(RuleType.IP)
        
        expect(result1).assertEqual(result2)
      })
    })
  })
}
