import { AppColors, AppStyles } from '../constants/AppConstants'
import { HelpFeedbackStrings, FaqItemString, GuideItemString } from '../constants/modules/HelpFeedbackStrings'
import { BackNavButton } from '../components/BackNavButton'
import { SectionCard } from '../components/SettingsSectionCard'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'

@Component
export struct HelpFeedbackPage {
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  onBack: () => void = () => {}
  @State expandedGuide: number = -1
  @State expandedFaq: number = -1

  private guideItems: GuideItemString[] = HelpFeedbackStrings.guideItems
  private faqItems: FaqItemString[] = HelpFeedbackStrings.faqItems

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
            Text(HelpFeedbackStrings.pageTitle)
              .fontSize(AppStyles.FONT_SIZE_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

            Text(HelpFeedbackStrings.pageSubtitle)
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        SectionCard({
          title: HelpFeedbackStrings.guideSectionTitle,
          content: () => {
            this.guideSectionContent()
          }
        })

        SectionCard({
          title: HelpFeedbackStrings.faqSectionTitle,
          content: () => {
            this.faqSectionContent()
          }
        })

        SectionCard({
          title: HelpFeedbackStrings.contactSectionTitle,
          content: () => {
            this.contactSectionContent()
          }
        })
      }
      .padding(AppStyles.PADDING_LG)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }

  @Builder
  private guideSectionContent() {
    Column({ space: 12 }) {
      ForEach(this.guideItems, (item: GuideItemString, index: number) => {
        Column({ space: 0 }) {
          Row() {
            Text(item.title)
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
              .layoutWeight(1)

            Text(this.expandedGuide === index ? HelpFeedbackStrings.collapseLabel : HelpFeedbackStrings.expandLabel)
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
  }

  @Builder
  private faqSectionContent() {
    Column({ space: 12 }) {
      ForEach(this.faqItems, (item: FaqItemString, index: number) => {
        Column({ space: 0 }) {
          Row() {
            Text(item.question)
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
              .layoutWeight(1)

            Text(this.expandedFaq === index ? HelpFeedbackStrings.collapseLabel : HelpFeedbackStrings.expandLabel)
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
  }

  @Builder
  private contactSectionContent() {
    Column({ space: 8 }) {
      Text(HelpFeedbackStrings.contactDescription)
        .fontSize(AppStyles.FONT_SIZE_SMALL)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .lineHeight(20)

      Row({ space: 8 }) {
        Text(HelpFeedbackStrings.feedbackEmailLabel)
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)

        Text(HelpFeedbackStrings.feedbackEmail)
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontColor(AppColors.BRAND_PRIMARY)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(20)
  }
}
