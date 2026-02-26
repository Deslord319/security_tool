import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'

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
  @State expandedFaq: number = -1

  private guideItems: GuideItem[] = [
    { title: '防火墙管理', description: '在防火墙页面中可以启用/关闭防火墙，查看和管理防火墙规则。支持按域名、IP 地址配置白名单和黑名单规则。' },
    { title: '外设管理', description: '外设管理页面提供 USB、蓝牙、Wi-Fi 等外设的统一管控。可以按需启用或禁用各类外设接口。' },
    { title: '身份鉴别', description: '配置设备的身份认证策略，包括密码复杂度要求、锁屏超时时间等安全策略。' },
    { title: '工具设置', description: '配置应用的启动校验和访问密码。启用启动校验后，每次打开应用需要进行身份认证。' },
    { title: '深色模式', description: '点击右上角三点菜单或左下角主题按钮切换显示模式。支持跟随系统、浅色和深色三种模式。' }
  ]

  private faqItems: FaqItem[] = [
    { question: '如何启用启动校验？', answer: '进入"工具设置"页面，打开"启动时身份校验"开关，选择认证方式（PIN 码或生物识别）即可。' },
    { question: '防火墙规则不生效怎么办？', answer: '请确认防火墙主开关已启用，并检查规则的优先级设置。设备需要具备企业管理权限才能正常使用防火墙功能。' },
    { question: '忘记工具访问密码怎么办？', answer: '当前版本需要重置应用数据来清除密码。进入系统设置 → 应用管理 → 安全管理中心 → 清除数据。' },
    { question: '外设策略修改后不生效？', answer: '部分外设策略修改后需要重启设备才能生效。请确认设备已获取相应的企业管理权限。' }
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

          ForEach(this.guideItems, (item: GuideItem) => {
            Column({ space: 4 }) {
              Text(item.title)
                .fontSize(AppStyles.FONT_SIZE_BODY)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
              Text(item.description)
                .fontSize(AppStyles.FONT_SIZE_SMALL)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
                .lineHeight(20)
            }
            .width('100%')
            .padding(12)
            .borderRadius(AppStyles.RADIUS_MD)
            .backgroundColor(AppColors.getColors(this.currentTheme).BG_COMPONENT)
            .alignItems(HorizontalAlign.Start)
          })
        }
        .width('100%')
        .padding(20)
        .borderRadius(AppStyles.RADIUS_LG)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .alignItems(HorizontalAlign.Start)

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
      }
      .padding(AppStyles.PADDING_LG)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }
}
