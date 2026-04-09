import { ModuleText } from '../StringCatalog'

export interface FaqItemString {
  question: string
  answer: string
}

export interface GuideItemString {
  title: string
  description: string
}

export class HelpFeedbackPageStrings {
  static readonly SUBTITLE: string = '产品指南、常见问题与客户支持'
  static readonly GUIDE_SECTION_TITLE: string = '使用指南'
  static readonly FAQ_SECTION_TITLE: string = '常见问题'
  static readonly CONTACT_SECTION_TITLE: string = '联系与反馈'
}

export class HelpFeedbackContactStrings {
  static readonly DESCRIPTION: string = '如遇到问题或有功能建议，欢迎通过以下方式联系。'
  static readonly EMAIL_LABEL: string = '反馈邮箱'
  static readonly EMAIL: string = 'consumer@huawei.com'
}

export class HelpFeedbackActionStrings {
  static readonly EXPAND: string = '展开'
  static readonly COLLAPSE: string = '收起'
}

export const HELP_FEEDBACK_GUIDE_ITEMS: GuideItemString[] = [
  {
    title: ModuleText.FIREWALL,
    description: '在防火墙页面可以启用或关闭防火墙，并查看和管理规则。支持按域名和 IP 地址配置黑白名单规则。'
  },
  {
    title: ModuleText.PERIPHERAL_MANAGE,
    description: '外设管理页面提供 USB、蓝牙、Wi-Fi 等接口的统一管控能力，可按需启用或禁用对应外设能力。'
  },
  {
    title: ModuleText.IDENTITY,
    description: '可配置设备口令复杂度和认证策略，用于提升系统身份鉴别强度。'
  },
  {
    title: ModuleText.TOOL_SETTINGS,
    description: '可配置启动校验和访问密码。启用启动校验后，每次打开应用都需要先完成身份验证。'
  },
  {
    title: '主题模式',
    description: '点击右上角菜单可以切换显示模式，支持跟随系统、浅色和深色三种主题。'
  }
]

export const HELP_FEEDBACK_FAQ_ITEMS: FaqItemString[] = [
  {
    question: '审计诊断中的不同事件类型如何触发？',
    answer: '网络连接、流量、权限变更和账户事件依赖系统上报能力。建议先触发对应的系统安全操作，再返回日志管理页刷新查看。'
  },
  {
    question: '审计事件显示订阅失败怎么办？',
    answer: '这通常表示系统限制或事件类型不支持。若账户类事件返回 401，多数是系统策略限制，而不是应用权限缺失。'
  },
  {
    question: '如何启用启动校验？',
    answer: '进入工具设置页，打开“启动时身份校验”开关，并选择认证方式即可。'
  },
  {
    question: '防火墙规则不生效怎么办？',
    answer: '请确认防火墙主开关已启用，并检查规则优先级。防火墙功能需要设备具备企业管理权限。'
  },
  {
    question: '忘记工具访问密码怎么办？',
    answer: '当前版本需要重置应用数据来清除访问密码。可在系统设置中的应用管理里清除安全管理中心数据。'
  },
  {
    question: '外设策略修改后不生效怎么办？',
    answer: '部分外设策略修改后需要重启设备才能生效，同时请确认设备已获取对应企业管理权限。'
  },
  {
    question: '身份策略保存后系统设置未同步怎么办？',
    answer: '系统设置页可能不会实时刷新策略显示。请先关闭系统设置后重新打开查看，必要时重启设备后复核。'
  },
  {
    question: '可以在应用内直接修改系统 PIN 码吗？',
    answer: '当前版本不支持。公开接口主要提供认证和策略下发能力，不提供在应用内直接修改系统 PIN 码的能力。'
  }
]
