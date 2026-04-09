import { describe, expect, it } from '@ohos/hypium'
import {
  ActionButtonStyles,
  AppColors,
  AppInfo,
  AppStyles,
  InteractiveItemStyles,
  NAV_ITEMS
} from '../../main/ets/constants/AppConstants'
import { CommonStrings } from '../../main/ets/constants/CommonStrings'
import { RouteIds } from '../../main/ets/constants/RouteIds'
import { ThemeMode } from '../../main/ets/theme/ThemeColors'

export default function appConstantsTest() {
  describe('AppConstants', () => {
    it('should expose stable app metadata and navigation items', 0, () => {
      expect(AppInfo.APP_NAME).assertEqual(CommonStrings.appName)
      expect(AppInfo.BUNDLE_NAME).assertEqual('com.huawei.securitytool')
      expect(NAV_ITEMS.length).assertEqual(6)
      expect(NAV_ITEMS[0].id).assertEqual(RouteIds.DASHBOARD)
      expect(NAV_ITEMS[5].id).assertEqual(RouteIds.TOOL_SETTINGS)
    })

    it('should expose layout constants used by shell pages', 0, () => {
      expect(AppStyles.SIDEBAR_WIDTH).assertEqual(200)
      expect(AppStyles.FONT_SIZE_TITLE).assertEqual(24)
      expect(AppStyles.SPACING_CARD).assertEqual(20)
      expect(AppStyles.RADIUS_LG).assertEqual(12)
      expect(AppStyles.DIVIDER_HEIGHT).assertEqual(1)
    })

    it('should map action button colors for light and dark themes', 0, () => {
      expect(ActionButtonStyles.getPrimaryBackground(ThemeMode.DARK, false)).assertEqual('rgba(94,161,255,0.24)')
      expect(ActionButtonStyles.getPrimaryBackground(ThemeMode.LIGHT, true)).assertEqual('rgba(10,132,255,0.14)')
      expect(ActionButtonStyles.getDangerBackground(ThemeMode.DARK, true)).assertEqual('rgba(255,59,48,0.32)')
      expect(ActionButtonStyles.getDangerForeground(ThemeMode.LIGHT)).assertEqual(AppColors.getColors(ThemeMode.LIGHT).TEXT_PRIMARY)
    })

    it('should map interactive item styles by theme and state', 0, () => {
      expect(InteractiveItemStyles.getMenuItemBackground(ThemeMode.LIGHT, false)).assertEqual('rgba(0,0,0,0)')
      expect(InteractiveItemStyles.getMenuItemBackground(ThemeMode.DARK, true)).assertEqual('rgba(84,84,88,0.78)')
      expect(InteractiveItemStyles.getSidebarItemBackground(ThemeMode.LIGHT, true, false)).assertEqual(AppColors.BRAND_PRIMARY)
      expect(InteractiveItemStyles.getSidebarIconTileBackground(ThemeMode.DARK, false)).assertEqual('rgba(10,132,255,0.14)')
      expect(InteractiveItemStyles.getThemeModeIconColor(ThemeMode.LIGHT)).assertEqual(AppColors.THEME_MODE_ICON_COLOR_LIGHT)
    })

    it('should expose expected palette constants and theme colors', 0, () => {
      expect(AppColors.BRAND_PRIMARY).assertEqual('#0A84FF')
      expect(AppColors.GRADIENT_HELP_END).assertEqual('#FFB4A8')
      expect(AppColors.FIREWALL_CONFLICT_BORDER).assertEqual('#FFD591')
      expect(AppColors.getColors(ThemeMode.LIGHT).TEXT_PRIMARY.length > 0).assertTrue()
      expect(AppColors.getColors(ThemeMode.DARK).TEXT_PRIMARY.length > 0).assertTrue()
    })
  })
}
