import { describe, expect, it } from '@ohos/hypium'
import {
  ActionButtonStyles,
  AppColors,
  AppInfo,
  AppStyles,
  InteractiveItemStyles,
  getNavItems
} from '../../main/ets/constants/AppConstants'
import { RouteIds } from '../../main/ets/constants/RouteIds'
import { AppText, ModuleText } from '../../main/ets/constants/StringCatalog'
import { TimeConstants } from '../../main/ets/constants/TimeConstants'
import { ThemeMode } from '../../main/ets/theme/ThemeColors'

export default function appConstantsTest() {
  describe('AppConstants', () => {
    it('should expose stable app metadata and navigation items', 0, () => {
      expect(AppText.NAME.length > 0).assertTrue()
      expect(AppInfo.BUNDLE_NAME).assertEqual('com.huawei.securitytool')
      expect(getNavItems().length).assertEqual(7)
      expect(getNavItems()[0].id).assertEqual(RouteIds.DASHBOARD)
      expect(getNavItems()[0].label).assertEqual(ModuleText.DASHBOARD)
      expect(getNavItems()[4].id).assertEqual(RouteIds.PERMISSION_MANAGE)
      expect(getNavItems()[4].label).assertEqual(ModuleText.PERMISSION_MANAGE)
      expect(getNavItems()[5].id).assertEqual(RouteIds.IDENTITY)
      expect(getNavItems()[6].id).assertEqual(RouteIds.TOOL_SETTINGS)
    })

    it('should expose layout constants used by shell pages', 0, () => {
      expect(AppStyles.SIDEBAR_WIDTH).assertEqual(200)
      expect(AppStyles.FONT_SIZE_TITLE).assertEqual(24)
      expect(AppStyles.RADIUS_LG).assertEqual(12)
      expect(AppStyles.DIVIDER_HEIGHT).assertEqual(1)
      expect(AppStyles.MODAL_LOADING_INDICATOR_SIZE).assertEqual(44)
      expect(AppStyles.LOADING_DIALOG_WIDTH).assertEqual(280)
    })

    it('should map action button colors for light and dark themes', 0, () => {
      expect((ActionButtonStyles.getPrimaryBackground(ThemeMode.DARK, false) as Resource).id).assertEqual($r('app.color.app_action_primary_bg_dark').id)
      expect((ActionButtonStyles.getPrimaryBackground(ThemeMode.LIGHT, true) as Resource).id).assertEqual($r('app.color.app_action_primary_hover_light').id)
      expect((ActionButtonStyles.getDangerBackground(ThemeMode.DARK, true) as Resource).id).assertEqual($r('app.color.app_action_danger_hover_dark').id)
      expect(ActionButtonStyles.getDangerForeground(ThemeMode.LIGHT)).assertEqual(AppColors.DANGER)
    })

    it('should map interactive item styles by theme and state', 0, () => {
      expect(InteractiveItemStyles.getMenuItemBackground(ThemeMode.LIGHT, false)).assertEqual(AppColors.TRANSPARENT)
      expect(InteractiveItemStyles.getMenuItemBackground(ThemeMode.DARK, true)).assertEqual(AppColors.INTERACTIVE_BUTTON_HOVER_DARK)
      expect(InteractiveItemStyles.getSidebarItemBackground(ThemeMode.LIGHT, true, false)).assertEqual(AppColors.BRAND_PRIMARY)
      expect(InteractiveItemStyles.getSidebarIconTileBackground(ThemeMode.DARK, false)).assertEqual(AppColors.SIDEBAR_ICON_TILE_BG_DARK)
      expect(InteractiveItemStyles.getThemeModeIconColor(ThemeMode.LIGHT)).assertEqual(AppColors.THEME_MODE_ICON_COLOR_LIGHT)
    })

    it('should expose expected palette constants and theme colors', 0, () => {
      // 颜色值唯一来源为 color.json；此处断言常量与主题色集合持有资源引用
      // $r() 每次返回新对象，按资源 id 断言同一资源
      expect((AppColors.BRAND_PRIMARY as Resource).id).assertEqual($r('app.color.app_brand_primary').id)
      expect((AppColors.GRADIENT_PERMISSION_END as Resource).id).assertEqual($r('app.color.app_gradient_permission_end').id)
      expect((AppColors.FIREWALL_CONFLICT_BORDER as Resource).id).assertEqual($r('app.color.app_firewall_conflict_border').id)
      expect((AppColors.MODAL_SHADOW_DARK as Resource).id).assertEqual($r('app.color.app_modal_shadow_dark').id)
      expect((AppColors.INTERACTIVE_SECONDARY_BG_DARK as Resource).id).assertEqual($r('app.color.app_interactive_secondary_bg_dark').id)
      expect((AppColors.SCROLL_BAR_DARK as Resource).id).assertEqual($r('app.color.app_scroll_bar_dark').id)
      expect((AppColors.getColors(ThemeMode.LIGHT).TEXT_PRIMARY as Resource).id).assertEqual($r('app.color.theme_light_text_primary').id)
      expect((AppColors.getColors(ThemeMode.DARK).TEXT_PRIMARY as Resource).id).assertEqual($r('app.color.theme_dark_text_primary').id)
    })

    it('should expose shared time constants', 0, () => {
      expect(TimeConstants.SECOND_IN_MS).assertEqual(1000)
      expect(TimeConstants.MINUTE_IN_MS).assertEqual(60 * 1000)
      expect(TimeConstants.HOUR_IN_MS).assertEqual(60 * 60 * 1000)
      expect(TimeConstants.DAY_IN_MS).assertEqual(24 * 60 * 60 * 1000)
    })
  })
}
