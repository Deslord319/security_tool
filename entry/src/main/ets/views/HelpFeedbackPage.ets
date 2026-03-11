import { AppColors, AppStyles } from '../constants/AppConstants'
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
  @State expandedGuide: number = -1
  @State expandedFaq: number = -1
  @State hoveredCardIndex: number = -1

  private guideItems: GuideItem[] = [
    {
      title: '\u9632\u706B\u5899\u7BA1\u7406',
      description: '\u5728\u9632\u706B\u5899\u9875\u9762\u4E2D\u53EF\u4EE5\u542F\u7528/\u5173\u95ED\u9632\u706B\u5899\uFF0C\u67E5\u770B\u548C\u7BA1\u7406\u9632\u706B\u5899\u89C4\u5219\u3002\u652F\u6301\u6309\u57DF\u540D\u3001IP \u5730\u5740\u914D\u7F6E\u767D\u540D\u5355\u548C\u9ED1\u540D\u5355\u89C4\u5219\u3002'
    },
    {
      title: '\u5916\u8BBE\u7BA1\u7406',
      description: '\u5916\u8BBE\u7BA1\u7406\u9875\u9762\u63D0\u4F9B USB\u3001\u84DD\u7259\u3001Wi-Fi \u7B49\u5916\u8BBE\u7684\u7EDF\u4E00\u7BA1\u63A7\u3002\u53EF\u4EE5\u6309\u9700\u542F\u7528\u6216\u7981\u7528\u5404\u7C7B\u5916\u8BBE\u63A5\u53E3\u3002'
    },
    {
      title: '\u8EAB\u4EFD\u9274\u522B',
      description: '\u914D\u7F6E\u8BBE\u5907\u53E3\u4EE4\u590D\u6742\u5EA6\u4E0E\u57DF\u8D26\u53F7\u6709\u6548\u671F\u7B56\u7565\u3002\u53E3\u4EE4\u6709\u6548\u671F\u4EC5\u4F5C\u7528\u4E8E\u57DF\u8D26\u53F7\uFF0C\u4E0D\u4F5C\u7528\u4E8E\u672C\u5730 PIN\u3002'
    },
    {
      title: '\u5DE5\u5177\u8BBE\u7F6E',
      description: '\u914D\u7F6E\u5E94\u7528\u7684\u542F\u52A8\u6821\u9A8C\u548C\u8BBF\u95EE\u5BC6\u7801\u3002\u542F\u7528\u542F\u52A8\u6821\u9A8C\u540E\uFF0C\u6BCF\u6B21\u6253\u5F00\u5E94\u7528\u9700\u8981\u8FDB\u884C\u8EAB\u4EFD\u8BA4\u8BC1\u3002'
    },
    {
      title: '\u6DF1\u8272\u6A21\u5F0F',
      description: '\u70B9\u51FB\u53F3\u4E0A\u89D2\u4E09\u70B9\u83DC\u5355\u5207\u6362\u663E\u793A\u6A21\u5F0F\u3002\u652F\u6301\u8DDF\u968F\u7CFB\u7EDF\u3001\u6D45\u8272\u548C\u6DF1\u8272\u4E09\u79CD\u6A21\u5F0F\u3002'
    }
  ]

  private faqItems: FaqItem[] = [
    {
      question: '\u65e5\u5fd7\u5bfc\u51fa\u76ee\u5f55\u6709\u54ea\u4e9b\u9650\u5236\uff1f',
      answer: '\u65e5\u5fd7\u5bfc\u51fa\u4ec5\u652f\u6301\u4e0b\u8f7d\u76ee\u5f55\u3001\u6587\u6863\u76ee\u5f55\u548c\u684c\u9762\u76ee\u5f55\u3002\u5bfc\u51fa\u6587\u4ef6\u4f1a\u56fa\u5b9a\u4fdd\u5b58\u5230\u6240\u9009\u76ee\u5f55\u4e0b\u7684 securityLog \u5b50\u76ee\u5f55\u3002'
    },
    {
      question: '\u5bfc\u51fa\u76ee\u5f55\u4e0d\u53ef\u5199\u65f6\u4f1a\u600e\u6837\uff1f',
      answer: '\u5f53\u6240\u9009\u76ee\u5f55\u4e0d\u53ef\u5199\u65f6\uff0c\u7cfb\u7edf\u4f1a\u81ea\u52a8\u56de\u9000\u5230\u9ed8\u8ba4\u5bfc\u51fa\u76ee\u5f55\u3002\u4f60\u53ef\u4ee5\u5728\u201c\u65e5\u5fd7\u7ba1\u7406 -> \u5bfc\u51fa\u8be6\u60c5\u201d\u4e2d\u67e5\u770b\u5b9e\u9645\u843d\u76d8\u76ee\u5f55\u4e0e\u63d0\u793a\u4fe1\u606f\u3002'
    },
    {
      question: '\u5ba1\u8ba1\u8bca\u65ad\u4e2d\u4e0d\u540c\u4e8b\u4ef6\u7c7b\u578b\u5982\u4f55\u89e6\u53d1\uff1f',
      answer: '\u5e38\u89c1\u89e6\u53d1\u5efa\u8bae\uff1a\n\u7f51\u7edc\u8fde\u63a5\uff1a\u4ec5\u7cfb\u7edf\u4e0a\u62a5\u7684\u8fde\u63a5\u5ba1\u8ba1\u4e8b\u4ef6\u4f1a\u51fa\u73b0\uff0c\u666e\u901a\u7f51\u9875\u8bbf\u95ee\u4e0d\u4e00\u5b9a\u89e6\u53d1\u3002\n\u7f51\u7edc\u6d41\u91cf\uff1a\u901a\u5e38\u9700\u8981\u7cfb\u7edf\u4fa7\u5f00\u542f\u6d41\u91cf\u5ba1\u8ba1\u4e0a\u62a5\u3002\n\u6743\u9650\u53d8\u66f4\uff1a\u9700\u6267\u884c\u6743\u9650\u6388\u4e88\u6216\u64a4\u9500\u7b49\u7cfb\u7edf\u6743\u9650\u64cd\u4f5c\u3002\n\u8d26\u6237\u4e8b\u4ef6\uff1a\u90e8\u5206\u8bbe\u5907\u53ef\u80fd\u53d7\u7cfb\u7edf\u7b56\u7565\u9650\u5236\u3002\n\u5176\u4ed6\u7c7b\u578b\uff1a\u5148\u89e6\u53d1\u5bf9\u5e94\u7cfb\u7edf\u5b89\u5168\u64cd\u4f5c\uff0c\u518d\u5237\u65b0\u65e5\u5fd7\u67e5\u770b\u3002'
    },
    {
      question: '\u5ba1\u8ba1\u4e8b\u4ef6\u663e\u793a\u8ba2\u9605\u5931\u8d25\u600e\u4e48\u529e\uff1f',
      answer: '\u8be5\u7c7b\u578b\u8ba2\u9605\u5931\u8d25\u901a\u5e38\u4e3a\u7cfb\u7edf\u9650\u5236\u6216\u4e8b\u4ef6\u4e0d\u652f\u6301\u3002\u82e5\u4e3a\u8d26\u6237\u7c7b\u4e14\u9519\u8bef\u7801 401\uff0c\u591a\u4e3a\u7cfb\u7edf\u7b56\u7565\u9650\u5236\uff0c\u4e0d\u662f\u5e94\u7528\u6743\u9650\u7f3a\u5931\u3002'
    },
    { question: '如何启用启动校验？', answer: '进入"工具设置"页面，打开"启动时身份校验"开关，选择认证方式（PIN 码或生物识别）即可。' },
    { question: '防火墙规则不生效怎么办？', answer: '请确认防火墙主开关已启用，并检查规则的优先级设置。设备需要具备企业管理权限才能正常使用防火墙功能。' },
    { question: '忘记工具访问密码怎么办？', answer: '当前版本需要重置应用数据来清除密码。进入系统设置 → 应用管理 → 安全管理中心 → 清除数据。' },
    { question: '外设策略修改后不生效？', answer: '部分外设策略修改后需要重启设备才能生效。请确认设备已获取相应的企业管理权限。' },
    { question: '身份策略保存后系统设置未同步怎么办？', answer: '系统设置页面可能不会实时刷新策略展示。请先关闭系统设置，再重新打开查看最新策略；若仍异常，可重启设备后复核。' },
    { question: '口令有效期配置是否对 PIN 码生效？', answer: '当前“口令有效期配置”通过域账号策略接口下发，仅对域账号生效，不作用于本地 PIN 码。' },
    { question: '可以在鸿蒙盾内直接修改系统 PIN 码吗？', answer: '当前版本不支持。公开系统接口主要提供认证与策略下发能力，不提供在应用内直接修改系统 PIN 码的能力，请在系统设置中修改。' }
  ]

  build() {
    Scroll() {
      Column({ space: 20 }) {
        // 页面标题区
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
        .width('100%')
        .alignItems(HorizontalAlign.Start)

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
                Text(this.expandedGuide === index ? '\u25B2' : '\u25BC')
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
                Text(this.expandedFaq === index ? '\u25B2' : '\u25BC')
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
            Text('support@example.com')
              .fontSize(AppStyles.FONT_SIZE_SMALL)
              .fontColor(AppColors.BRAND_PRIMARY)
          }

          Row({ space: 8 }) {
            Text('项目地址')
              .fontSize(AppStyles.FONT_SIZE_SMALL)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
            Text('github.com/example/security-tool')
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

