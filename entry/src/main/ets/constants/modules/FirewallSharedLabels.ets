/**
 * 共享标签常量
 * 
 * 统一管理系统中重复使用的 UI 标签字符串，避免硬编码重复。
 * 用于防火墙规则、数据模型等模块的标签显示。
 */
export class SharedLabels {
  // 规则类型标签
  static readonly LABEL_IP: string = 'IP'
  static readonly LABEL_DOMAIN: string = '域名'
  static readonly LABEL_DNS: string = 'DNS'
  static readonly LABEL_ALL: string = 'ALL'
  
  // 方向标签
  static readonly LABEL_INBOUND: string = '入站'
  static readonly LABEL_OUTBOUND: string = '出站'
  
  // 其他标签
  static readonly LABEL_UNKNOWN: string = '未知'
}
