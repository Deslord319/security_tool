import { describe, expect, it } from '@ohos/hypium'
import {
  ActionButtonStyles,
  AppColors,
  AppInfo,
  AppStyles,
  InteractiveItemStyles,
  NAV_ITEMS
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
      expect(NAV_ITEMS.length).assertEqual(7)
      expect(NAV_ITEMS[0].id).assertEqual(RouteIds.DASHBOARD)
      expect(NAV_ITEMS[0].label).assertEqual(ModuleText.DASHBOARD)
      expect(NAV_ITEMS[4].id).assertEqual(RouteIds.PERMISSION_MANAGE)
      expect(NAV_ITEMS[4].label).assertEqual(ModuleText.PERMISSION_MANAGE)
      expect(NAV_ITEMS[5].id).assertEqual(RouteIds.IDENTITY)
      expect(NAV_ITEMS[6].id).assertEqual(RouteIds.TOOL_SETTINGS)
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
      expect(ActionButtonStyles.getPrimaryBackground(ThemeMode.DARK, false)).assertEqual('rgba(94,161,255,0.24)')
      expect(ActionButtonStyles.getPrimaryBackground(ThemeMode.LIGHT, true)).assertEqual('rgba(10,132,255,0.14)')
      expect(ActionButtonStyles.getDangerBackground(ThemeMode.DARK, true)).assertEqual('rgba(255,59,48,0.32)')
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
      expect(AppColors.BRAND_PRIMARY).assertEqual('#0A84FF')
      expect(AppColors.GRADIENT_PERMISSION_END).assertEqual('#4CD4B0')
      expect(AppColors.GRADIENT_HELP_END).assertEqual('#FFB4A8')
      expect(AppColors.FIREWALL_CONFLICT_BORDER).assertEqual('#FFD591')
      expect(AppColors.MODAL_SHADOW_DARK).assertEqual('rgba(0,0,0,0.32)')
      expect(AppColors.INTERACTIVE_SECONDARY_BG_DARK).assertEqual('rgba(255,255,255,0.08)')
      expect(AppColors.SCROLL_BAR_DARK).assertEqual('#6B7280')
      expect(AppColors.getColors(ThemeMode.LIGHT).TEXT_PRIMARY.length > 0).assertTrue()
      expect(AppColors.getColors(ThemeMode.DARK).TEXT_PRIMARY.length > 0).assertTrue()
    })

    it('should expose shared time constants', 0, () => {
      expect(TimeConstants.SECOND_IN_MS).assertEqual(1000)
      expect(TimeConstants.MINUTE_IN_MS).assertEqual(60 * 1000)
      expect(TimeConstants.HOUR_IN_MS).assertEqual(60 * 60 * 1000)
      expect(TimeConstants.DAY_IN_MS).assertEqual(24 * 60 * 60 * 1000)
    })
  })
}
