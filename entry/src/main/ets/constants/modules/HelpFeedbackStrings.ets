import { ModuleText } from '../StringCatalog'
import { AppStrings } from '../AppStrings'

export interface FaqItemString {
  question: string
  answer: string
}

export interface GuideItemString {
  title: string
  description: string
}

/**
 * 帮助与反馈模块文案资源门面
 *
 * 文案唯一来源为 resources/{base,en_US}/element/string.json 中的 help_feedback_* 资源。
 * 门面保持与旧常量一致的访问方式，内部经 AppStrings 资源管理器按当前 locale 解析。
 * 反馈邮箱为 locale 无关常量，不进入资源。
 *
 * 使用指南与 FAQ 条目以惰性函数提供：模块顶层常量不得在 AppStrings.init 之前
 * 读取文案门面。单元测试环境（AppStrings 未初始化）下门面返回资源名；相关断言
 * 必须经门面构造，不得断言中文或英文字面量。
 */
export class HelpFeedbackPageStrings {
  static get SUBTITLE(): string {
    return AppStrings.get('help_feedback_page_subtitle')
  }



  static get CONTACT_SECTION_TITLE(): string {
    return AppStrings.get('help_feedback_contact_section_title')
  }
}

export class HelpFeedbackContactStrings {


  static readonly EMAIL: string = 'consumer@huawei.com'
}

export class HelpFeedbackActionStrings {
  static get EXPAND(): string {
    return AppStrings.get('help_feedback_action_expand')
  }

  static get COLLAPSE(): string {
    return AppStrings.get('help_feedback_action_collapse')
  }
}

export function getHelpFeedbackGuideItems(): GuideItemString[] {
  return [
    {
      title: ModuleText.FIREWALL,
      description: AppStrings.get('help_feedback_guide_firewall_desc')
    },
    {
      title: ModuleText.PERIPHERAL_MANAGE,
      description: AppStrings.get('help_feedback_guide_peripheral_desc')
    },
    {
      title: ModuleText.IDENTITY,
      description: AppStrings.get('help_feedback_guide_identity_desc')
    },
    {
      title: ModuleText.TOOL_SETTINGS,
      description: AppStrings.get('help_feedback_guide_tool_settings_desc')
    },
    {
      title: AppStrings.get('help_feedback_guide_theme_title'),
      description: AppStrings.get('help_feedback_guide_theme_desc')
    }
  ]
}

export function getHelpFeedbackFaqItems(): FaqItemString[] {
  return [
    {
      question: AppStrings.get('help_feedback_faq_audit_types_q'),
      answer: AppStrings.get('help_feedback_faq_audit_types_a')
    },
    {
      question: AppStrings.get('help_feedback_faq_audit_subscribe_q'),
      answer: AppStrings.get('help_feedback_faq_audit_subscribe_a')
    },
    {
      question: AppStrings.get('help_feedback_faq_startup_auth_q'),
      answer: AppStrings.get('help_feedback_faq_startup_auth_a')
    },
    {
      question: AppStrings.get('help_feedback_faq_firewall_rules_q'),
      answer: AppStrings.get('help_feedback_faq_firewall_rules_a')
    },
    {
      question: AppStrings.get('help_feedback_faq_forgot_password_q'),
      answer: AppStrings.get('help_feedback_faq_forgot_password_a')
    },
    {
      question: AppStrings.get('help_feedback_faq_peripheral_policy_q'),
      answer: AppStrings.get('help_feedback_faq_peripheral_policy_a')
    },
    {
      question: AppStrings.get('help_feedback_faq_identity_sync_q'),
      answer: AppStrings.get('help_feedback_faq_identity_sync_a')
    },
    {
      question: AppStrings.get('help_feedback_faq_change_pin_q'),
      answer: AppStrings.get('help_feedback_faq_change_pin_a')
    }
  ]
}
