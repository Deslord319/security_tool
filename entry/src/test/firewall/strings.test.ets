import { describe, expect, it } from '@ohos/hypium'
import { FirewallStrings } from '../../main/ets/constants/modules/FirewallStrings'

export default function firewallStringsTest() {
  describe('FirewallStrings', () => {
    it('should keep current page copy populated and scoped to custom rules', 0, () => {
      expect(FirewallStrings.pageSubtitle).assertEqual('统一配置设备防火墙策略，支持按网络场景选择预置模式并维护自定义访问规则')
      expect(FirewallStrings.customRulesSubtitle).assertEqual('支持IP、域名和DNS规则自定义配置')
    })

    it('should expose preset mode titles and descriptions for each scenario', 0, () => {
      expect(FirewallStrings.getModeTitle('public')).assertEqual('公共网络模式')
      expect(FirewallStrings.getModeTitle('private')).assertEqual('私有网络模式')
      expect(FirewallStrings.getModeTitle('custom')).assertEqual('自定义模式')
      expect(FirewallStrings.getModeDescription('public').indexOf('严格') >= 0).assertTrue()
      expect(FirewallStrings.getModeDescription('private').indexOf('可信网络环境') >= 0).assertTrue()
      expect(FirewallStrings.getModeDescription('custom').indexOf('自定义') >= 0).assertTrue()
    })

    it('should build conflict summaries with concrete counts', 0, () => {
      expect(FirewallStrings.buildConflictNotice(0, 0, 0)).assertEqual('')
      expect(FirewallStrings.buildConflictNotice(1, 0, 0)).assertEqual('当前自定义规则集中存在：重复 1 条')
      expect(FirewallStrings.buildConflictNotice(1, 2, 3)).assertEqual('当前自定义规则集中存在：重复 1 条，硬冲突 2 条，范围重叠 3 条')
    })

    it('should map toggle rejection reasons to actionable copy', 0, () => {
      expect(FirewallStrings.buildToggleFailedMessage('lockout', 30)).assertEqual('PIN 校验失败次数过多，请在 30 秒后重试')
      expect(FirewallStrings.buildToggleFailedMessage('pin_unavailable', undefined)).assertEqual('当前设备未配置 PIN')
      expect(FirewallStrings.buildToggleFailedMessage('policy_apply_failed', undefined)).assertEqual('防火墙状态写入失败')
      expect(FirewallStrings.buildToggleFailedMessage(undefined, undefined)).assertEqual('防火墙状态切换失败')
    })
  })
}
