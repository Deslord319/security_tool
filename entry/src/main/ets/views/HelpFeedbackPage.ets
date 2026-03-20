import { AppColors, AppStyles } from '../constants/AppConstants'
import { BackNavButton } from '../components/BackNavButton'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { HoverUtils } from '../utils/HoverUtils'

interface FaqItem {
  question: string
  answer: string
}

interface GuideItem {
  title: string
  description: string
}

@Component
export struct HelpFeedbackPage {
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  onBack: () => void = () => {}
  @State expandedGuide: number = -1
  @State expandedFaq: number = -1
  @State hoveredCardIndex: number = -1

  private guideItems: GuideItem[] = [
    {
      title: '防火墙管理',
      description: '在防火墙页面可以启用或关闭防火墙，并查看和管理规则。支持按域名和 IP 地址配置黑白名单规则。'
    },
    {
      title: '外设管理',
      description: '外设管理页面提供 USB、蓝牙、Wi-Fi 等接口的统一管控能力，可按需启用或禁用对应外设能力。'
    },
    {
      title: '身份鉴别',
      description: '可配置设备口令复杂度和认证策略，用于提升系统身份鉴别强度。'
    },
    {
      title: '工具设置',
      description: '可配置启动校验和访问密码。启用启动校验后，每次打开应用都需要先完成身份验证。'
    },
    {
      title: '主题模式',
      description: '点击右上角菜单可以切换显示模式，支持跟随系统、浅色和深色三种主题。'
    }
  ]

  private faqItems: FaqItem[] = [
    {
      question: '日志导出目录有哪些限制？',
      answer: '日志导出统一使用下载目录。首次导出时系统会引导授权，后续导出会复用该授权目录。'
    },
    {
      question: '导出目录不可写时会怎样？',
      answer: '当选定目录不可写时，系统会自动回退到默认导出目录。你可以在日志管理页查看最终落盘路径和导出结果提示。'
    },
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

  build() {
    Scroll() {
      Column({ space: 20 }) {
        Row({ space: 8 }) {
          BackNavButton({
            onBack: () => {
              this.onBack()
            }
          })

          Column({ space: 4 }) {
            Text('帮助与反馈')
              .fontSize(AppStyles.FONT_SIZE_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

            Text('使用指南、常见问题和反馈渠道')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Column({ space: 12 }) {
          Text('使用指南')
            .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

          ForEach(this.guideItems, (item: GuideItem, index: number) => {
            Column({ space: 0 }) {
              Row() {
                Text(item.title)
                  .fontSize(AppStyles.FONT_SIZE_BODY)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                  .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
                  .layoutWeight(1)

                Text(this.expandedGuide === index ? '▲' : '▼')
                  .fontSize(10)
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                  .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
              }
              .width('100%')
              .padding(12)
              .onClick(() => {
                this.expandedGuide = this.expandedGuide === index ? -1 : index
              })

              if (this.expandedGuide === index) {
                Text(item.description)
                  .fontSize(AppStyles.FONT_SIZE_SMALL)
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                  .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
                  .lineHeight(20)
                  .padding({ left: 12, right: 12, bottom: 12 })
                  .width('100%')
              }
            }
            .width('100%')
            .borderRadius(AppStyles.RADIUS_MD)
            .backgroundColor(AppColors.getColors(this.currentTheme).BG_COMPONENT)
          })
        }
        .width('100%')
        .padding(20)
        .borderRadius(AppStyles.RADIUS_LG)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .alignItems(HorizontalAlign.Start)
        .border({
          width: 1,
          color: this.hoveredCardIndex === 0 ? AppColors.BRAND_PRIMARY : AppColors.getColors(this.currentTheme).BORDER
        })
        .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredCardIndex === 0, true))
        .translate({ y: HoverUtils.getTranslateY(this.hoveredCardIndex === 0, 4) })
        .onHover((isHover: boolean) => {
          HoverUtils.animate(() => {
            this.hoveredCardIndex = isHover ? 0 : -1
          })
        })

        Column({ space: 12 }) {
          Text('常见问题')
            .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

          ForEach(this.faqItems, (item: FaqItem, index: number) => {
            Column({ space: 0 }) {
              Row() {
                Text(item.question)
                  .fontSize(AppStyles.FONT_SIZE_BODY)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                  .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
                  .layoutWeight(1)

                Text(this.expandedFaq === index ? '▲' : '▼')
                  .fontSize(10)
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                  .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
              }
              .width('100%')
              .padding(12)
              .onClick(() => {
                this.expandedFaq = this.expandedFaq === index ? -1 : index
              })

              if (this.expandedFaq === index) {
                Text(item.answer)
                  .fontSize(AppStyles.FONT_SIZE_SMALL)
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                  .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
                  .lineHeight(20)
                  .padding({ left: 12, right: 12, bottom: 12 })
                  .width('100%')
              }
            }
            .width('100%')
            .borderRadius(AppStyles.RADIUS_MD)
            .backgroundColor(AppColors.getColors(this.currentTheme).BG_COMPONENT)
          })
        }
        .width('100%')
        .padding(20)
        .borderRadius(AppStyles.RADIUS_LG)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .alignItems(HorizontalAlign.Start)
        .border({
          width: 1,
          color: this.hoveredCardIndex === 1 ? AppColors.WARNING : AppColors.getColors(this.currentTheme).BORDER
        })
        .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredCardIndex === 1, true))
        .translate({ y: HoverUtils.getTranslateY(this.hoveredCardIndex === 1, 4) })
        .onHover((isHover: boolean) => {
          HoverUtils.animate(() => {
            this.hoveredCardIndex = isHover ? 1 : -1
          })
        })

        Column({ space: 8 }) {
          Text('联系与反馈')
            .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

          Text('如遇到问题或有功能建议，欢迎通过以下方式联系。')
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
            .lineHeight(20)

          Row({ space: 8 }) {
            Text('反馈邮箱')
              .fontSize(AppStyles.FONT_SIZE_SMALL)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)

            Text('cbge@huawei.com')
              .fontSize(AppStyles.FONT_SIZE_SMALL)
              .fontColor(AppColors.BRAND_PRIMARY)
          }

          Row({ space: 8 }) {
            Text('项目版本')
              .fontSize(AppStyles.FONT_SIZE_SMALL)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)

            Text('1.0.0-beta')
              .fontSize(AppStyles.FONT_SIZE_SMALL)
              .fontColor(AppColors.BRAND_PRIMARY)
          }
        }
        .width('100%')
        .padding(20)
        .borderRadius(AppStyles.RADIUS_LG)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .alignItems(HorizontalAlign.Start)
        .border({
          width: 1,
          color: this.hoveredCardIndex === 2 ? AppColors.SUCCESS : AppColors.getColors(this.currentTheme).BORDER
        })
        .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredCardIndex === 2, true))
        .translate({ y: HoverUtils.getTranslateY(this.hoveredCardIndex === 2, 4) })
        .onHover((isHover: boolean) => {
          HoverUtils.animate(() => {
            this.hoveredCardIndex = isHover ? 2 : -1
          })
        })
      }
      .padding(AppStyles.PADDING_LG)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }
}
