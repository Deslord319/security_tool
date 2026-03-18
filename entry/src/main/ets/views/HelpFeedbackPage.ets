import { AppColors, AppStyles } from '../constants/AppConstants'
import { BackNavButton } from '../components/BackNavButton'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { HoverUtils } from '../utils/HoverUtils'
import { ResultMessageBox } from '../components/ResultMessageBox'

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
  private successPreviewDialogController: CustomDialogController = new CustomDialogController({
    builder: ResultMessageBox({
      status: 'success',
      message: '防火墙规则已保存'
    }),
    alignment: DialogAlignment.Center,
    autoCancel: false,
    customStyle: true
  })
  private failurePreviewDialogController: CustomDialogController = new CustomDialogController({
    builder: ResultMessageBox({
      status: 'failure',
      message: '保存未完成，请稍后重试'
    }),
    alignment: DialogAlignment.Center,
    autoCancel: false,
    customStyle: true
  })

  private guideItems: GuideItem[] = [
    {
      title: '防火墙管理',
      description: '在防火墙页面中可以启用/关闭防火墙，查看和管理防火墙规则。支持按域名、IP 地址配置白名单和黑名单规则。'
    },
    {
      title: '外设管理',
      description: '外设管理页面提供 USB、蓝牙、Wi-Fi 等外设的统一管控。可以按需启用或禁用各类外设接口。'
    },
    {
      title: '身份鉴别',
      description: '配置设备口令复杂度策略，提升系统身份认证的安全性。'
    },
    {
      title: '工具设置',
      description: '配置应用的启动校验和访问密码。启用启动校验后，每次打开应用需要进行身份认证。'
    },
    {
      title: '深色模式',
      description: '点击右上角三点菜单切换显示模式。支持跟随系统、浅色和深色三种模式。'
    }
  ]

  private faqItems: FaqItem[] = [
    {
      question: '日志导出目录有哪些限制？',
      answer: '日志导出已统一为 DOWNLOAD 模式。首次导出时系统会自动引导授权，后续所有导出默认使用该授权目录。'
    },
    {
      question: '导出目录不可写时会怎样？',
      answer: '当所选目录不可写时，系统会自动回退到默认导出目录。你可以在“日志管理 -> 导出详情”中查看实际落盘目录与提示信息。'
    },
    {
      question: '审计诊断中不同事件类型如何触发？',
      answer: '常见触发建议：\n网络连接：仅系统上报的连接审计事件会出现，普通网页访问不一定触发。\n网络流量：通常需要系统侧开启流量审计上报。\n权限变更：需执行权限授予或撤销等系统权限操作。\n账户事件：部分设备可能受系统策略限制。\n其他类型：先触发对应系统安全操作，再刷新日志查看。'
    },
    {
      question: '审计事件显示订阅失败怎么办？',
      answer: '该类型订阅失败通常为系统限制或事件不支持。若为账户类且错误码 401，多为系统策略限制，不是应用权限缺失。'
    },
    { question: '如何启用启动校验？', answer: '进入"工具设置"页面，打开"启动时身份校验"开关，选择认证方式（PIN 码或生物识别）即可。' },
    { question: '防火墙规则不生效怎么办？', answer: '请确认防火墙主开关已启用，并检查规则的优先级设置。设备需要具备企业管理权限才能正常使用防火墙功能。' },
    { question: '忘记工具访问密码怎么办？', answer: '当前版本需要重置应用数据来清除密码。进入系统设置 → 应用管理 → 安全管理中心 → 清除数据。' },
    { question: '外设策略修改后不生效？', answer: '部分外设策略修改后需要重启设备才能生效。请确认设备已获取相应的企业管理权限。' },
    { question: '身份策略保存后系统设置未同步怎么办？', answer: '系统设置页面可能不会实时刷新策略展示。请先关闭系统设置，再重新打开查看最新策略；若仍异常，可重启设备后复核。' },
    { question: '可以在鸿蒙盾内直接修改系统 PIN 码吗？', answer: '当前版本不支持。公开系统接口主要提供认证与策略下发能力，不提供在应用内直接修改系统 PIN 码的能力，请在系统设置中修改。' }
  ]

  build() {
    Scroll() {
      Column({ space: 20 }) {
        // 页面标题区
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
          Text('结果弹框原型')
            .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

          Text('参考 ElementUI MessageBox 的极简通知样式，提供成功态和失败态预览。')
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
            .lineHeight(20)

          Row({ space: 12 }) {
            Button('预览成功态')
              .type(ButtonType.Normal)
              .height(36)
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(Color.White)
              .backgroundColor(AppColors.BRAND_PRIMARY)
              .borderRadius(AppStyles.RADIUS_SM)
              .padding({ left: 16, right: 16 })
              .onClick(() => {
                this.successPreviewDialogController.open()
              })

            Button('预览失败态')
              .type(ButtonType.Normal)
              .height(36)
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .backgroundColor(AppColors.getColors(this.currentTheme).BG_COMPONENT)
              .borderRadius(AppStyles.RADIUS_SM)
              .border({
                width: 1,
                color: AppColors.getColors(this.currentTheme).BORDER
              })
              .padding({ left: 16, right: 16 })
              .onClick(() => {
                this.failurePreviewDialogController.open()
              })
          }
        }
        .width('100%')
        .padding(20)
        .borderRadius(AppStyles.RADIUS_LG)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .alignItems(HorizontalAlign.Start)
        .border({
          width: 1,
          color: this.hoveredCardIndex === 3 ? AppColors.BRAND_PRIMARY : AppColors.getColors(this.currentTheme).BORDER
        })
        .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredCardIndex === 3, true))
        .translate({ y: HoverUtils.getTranslateY(this.hoveredCardIndex === 3, 4) })
        .onHover((isHover: boolean) => {
          HoverUtils.animate(() => {
            this.hoveredCardIndex = isHover ? 3 : -1
          })
        })

        // 使用指南卡片
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

        // 常见问题卡片
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

        // 联系反馈卡片
        Column({ space: 8 }) {
          Text('联系与反馈')
            .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

          Text('如遇到问题或有功能建议，欢迎通过以下方式联系我们：')
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

