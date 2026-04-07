import { AppColors, AppStyles } from '../../../constants/AppConstants'
import { CommonStrings } from '../../../constants/CommonStrings'
import { HelpFeedbackStrings, FaqItemString, GuideItemString } from '../../../constants/modules/HelpFeedbackStrings'
import { SubPageHeader } from '../../../components/SubPageHeader'
import { SectionCard } from '../../../components/SettingsSectionCard'
import { ThemeMode } from '../../../theme/ThemeColors'

interface ExpandableInfoItem {
  title: string
  content: string
}

@ComponentV2
struct ExpandableInfoList {
  @Param items: ExpandableInfoItem[] = []
  @Param expandedIndex: number = -1
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Event onToggle: (index: number) => void = () => {}

  build() {
    Column({ space: 12 }) {
      ForEach(this.items, (item: ExpandableInfoItem, index: number) => {
        Column({ space: 0 }) {
          Row() {
            Text(item.title)
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
              .layoutWeight(1)

            Text(this.expandedIndex === index ? HelpFeedbackStrings.collapseLabel : HelpFeedbackStrings.expandLabel)
              .fontSize(10)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          }
          .width('100%')
          .padding(12)
          .onClick(() => {
            this.onToggle(index)
          })

          if (this.expandedIndex === index) {
            Text(item.content)
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
}

@ComponentV2
export struct HelpFeedbackPage {
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Event onBack: () => void = () => {}
  @Local expandedGuide: number = -1
  @Local expandedFaq: number = -1

  private guideItems: GuideItemString[] = HelpFeedbackStrings.guideItems
  private faqItems: FaqItemString[] = HelpFeedbackStrings.faqItems

  build() {
    Column() {
      SubPageHeader({
        title: CommonStrings.moduleHelpFeedback,
        subtitle: HelpFeedbackStrings.pageSubtitle,
        currentTheme: this.currentTheme,
        onBack: () => this.onBack()
      })

      Scroll() {
        Column({ space: 20 }) {
          SectionCard({
            title: HelpFeedbackStrings.guideSectionTitle,
            currentTheme: this.currentTheme,
            content: () => {
              this.guideSectionContent()
            }
          })

          SectionCard({
            title: HelpFeedbackStrings.faqSectionTitle,
            currentTheme: this.currentTheme,
            content: () => {
              this.faqSectionContent()
            }
          })

          SectionCard({
            title: HelpFeedbackStrings.contactSectionTitle,
            currentTheme: this.currentTheme,
            content: () => {
              this.contactSectionContent()
            }
          })
        }
        .width('100%')
        .padding({
          left: AppStyles.PADDING_LG,
          right: AppStyles.PADDING_LG,
          top: AppStyles.PADDING_MD,
          bottom: AppStyles.PADDING_LG
        })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }

  @Builder
  private guideSectionContent() {
    ExpandableInfoList({
      items: this.guideItems.map((item: GuideItemString): ExpandableInfoItem => ({
        title: item.title,
        content: item.description
      } as ExpandableInfoItem)),
      expandedIndex: this.expandedGuide,
      currentTheme: this.currentTheme,
      onToggle: (index: number) => {
        this.expandedGuide = this.expandedGuide === index ? -1 : index
      }
    })
  }

  @Builder
  private faqSectionContent() {
    ExpandableInfoList({
      items: this.faqItems.map((item: FaqItemString): ExpandableInfoItem => ({
        title: item.question,
        content: item.answer
      } as ExpandableInfoItem)),
      expandedIndex: this.expandedFaq,
      currentTheme: this.currentTheme,
      onToggle: (index: number) => {
        this.expandedFaq = this.expandedFaq === index ? -1 : index
      }
    })
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
