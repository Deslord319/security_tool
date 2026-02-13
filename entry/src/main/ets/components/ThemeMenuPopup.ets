import { ThemeMode, ThemeOption } from '../theme/ThemeColors'
import { ThemeManager, STORAGE_KEY_THEME, STORAGE_KEY_OPTION } from '../theme/ThemeManager'
import { AppColors, AppStyles } from '../constants/AppConstants'

@Component
export struct ThemeMenuPopup {
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  @StorageLink(STORAGE_KEY_OPTION) currentOption: ThemeOption = ThemeOption.SYSTEM
  @Link showMenu: boolean
  onNavigate?: (route: string) => void

  build() {
    Column() {
      // 显示模式分组标签
      Text('显示模式')
        .fontSize(11)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 4 })

      // 跟随系统
      this.MenuItem('跟随系统', '🖥', ThemeOption.SYSTEM)

      // 浅色模式
      this.MenuItem('浅色模式', '☀', ThemeOption.LIGHT)

      // 深色模式
      this.MenuItem('深色模式', '🌙', ThemeOption.DARK)

      // 分隔线
      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
        .margin({ top: 4, bottom: 4 })

      // 设置
      this.ActionMenuItem('设置', '⚙', 'tool-settings')

      // 帮助和反馈
      this.ActionMenuItem('帮助和反馈', '?', '')

      // 关于
      this.ActionMenuItem('关于', 'ⓘ', '')
    }
    .width(200)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .shadow({
      radius: 16,
      color: this.currentTheme === ThemeMode.DARK ? 'rgba(0,0,0,0.4)' : 'rgba(0,0,0,0.15)',
      offsetX: 0,
      offsetY: 4
    })
    .padding({ top: 4, bottom: 8 })
  }

  @Builder
  MenuItem(label: string, icon: string, option: ThemeOption) {
    Row() {
      Text(icon)
        .fontSize(16)
        .width(24)
        .textAlign(TextAlign.Center)

      Text(label)
        .fontSize(14)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        .layoutWeight(1)
        .margin({ left: 8 })

      // 勾选标记
      if (this.currentOption === option) {
        Text('✓')
          .fontSize(14)
          .fontColor(AppColors.BRAND_PRIMARY)
      }
    }
    .width('100%')
    .height(44)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      ThemeManager.getInstance().setOption(option)
    })
  }

  @Builder
  ActionMenuItem(label: string, icon: string, route: string) {
    Row() {
      Text(icon)
        .fontSize(16)
        .width(24)
        .textAlign(TextAlign.Center)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)

      Text(label)
        .fontSize(14)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        .layoutWeight(1)
        .margin({ left: 8 })
    }
    .width('100%')
    .height(44)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      this.showMenu = false
      if (route && this.onNavigate) {
        this.onNavigate(route)
      }
    })
  }
}
