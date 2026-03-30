/**
 * 通用尺寸常量
 * 
 * 统一管理系统中使用的尺寸、间距、圆角等数值常量
 * 
 * 注意：只包含实际被使用的常量，避免过度定义
 */

// ==================== 对话框尺寸 ====================
export class DialogDimensions {
  // 对话框容器
  static readonly DIALOG_MAX_WIDTH: number = 760
  static readonly DIALOG_MAX_HEIGHT: number = 580
  static readonly DIALOG_CONTENT_MAX_HEIGHT: number = 460
  static readonly DIALOG_PADDING: number = 18
  static readonly DIALOG_MARGIN: number = 16
  
  // 对话框内边距
  static readonly DIALOG_INNER_PADDING_TOP: number = 20
  static readonly DIALOG_INNER_PADDING_BOTTOM: number = 20
  
  // Loading 对话框
  static readonly LOADING_DIALOG_WIDTH: number = 280
  static readonly LOADING_DIALOG_PADDING: number = 24
  static readonly LOADING_ICON_SIZE: number = 44
  
  // 按钮尺寸
  static readonly BUTTON_HEIGHT_SM: number = 32
  static readonly BUTTON_HEIGHT_MD: number = 36
  static readonly BUTTON_HEIGHT_LG: number = 40
  
  // Select 高度
  static readonly SELECT_HEIGHT: number = 40
  
  // 序号宽度
  static readonly INDEX_NUMBER_WIDTH: number = 24
}

// ==================== 间距常量 ====================
export class SpacingDimensions {
  // 通用间距（4px 基线）
  static readonly SPACE_XS: number = 4
  static readonly SPACE_SM: number = 8
  static readonly SPACE_MD: number = 12
  static readonly SPACE_LG: number = 16
  static readonly SPACE_XL: number = 20
  static readonly SPACE_2XL: number = 24
  
  // 列表项间距
  static readonly LIST_ITEM_SPACE: number = 8
  static readonly LIST_ITEM_PADDING: number = 10
  
  // 表单间距
  static readonly FORM_ITEM_SPACE: number = 6
  static readonly FORM_LABEL_SPACE: number = 10
  
  // 表格相关
  static readonly TABLE_HEADER_PADDING_TOP: number = 14
}

// ==================== 圆角常量 ====================
export class RadiusDimensions {
  static readonly RADIUS_NONE: number = 0
  static readonly RADIUS_XS: number = 4
  static readonly RADIUS_SM: number = 6
  static readonly RADIUS_MD: number = 8
  static readonly RADIUS_LG: number = 10
  static readonly RADIUS_XL: number = 12
  static readonly RADIUS_2XL: number = 16
  static readonly RADIUS_FULL: number = 9999
}

// ==================== 字体大小常量 ====================
export class FontSizeDimensions {
  static readonly FONT_SIZE_XS: number = 11
  static readonly FONT_SIZE_SM: number = 12
  static readonly FONT_SIZE_MD: number = 13
  static readonly FONT_SIZE_BODY: number = 14
  static readonly FONT_SIZE_LG: number = 16
  static readonly FONT_SIZE_XL: number = 18
  static readonly FONT_SIZE_2XL: number = 20
  static readonly FONT_SIZE_TITLE: number = 24
}

// ==================== 阴影常量 ====================
export class ShadowDimensions {
  // 阴影半径
  static readonly SHADOW_RADIUS_SM: number = 8
  static readonly SHADOW_RADIUS_MD: number = 12
  static readonly SHADOW_RADIUS_LG: number = 18
  
  // 阴影偏移
  static readonly SHADOW_OFFSET_X: number = 0
  static readonly SHADOW_OFFSET_Y_SM: number = 2
  static readonly SHADOW_OFFSET_Y_MD: number = 4
  static readonly SHADOW_OFFSET_Y_LG: number = 8
  
  // 阴影颜色（透明度）
  static readonly SHADOW_DARK_OPACITY: string = '0.32'
  static readonly SHADOW_LIGHT_OPACITY: string = '0.14'
}

// ==================== 布局常量 ====================
export class LayoutDimensions {
  // 卡片尺寸
  static readonly CARD_MIN_HEIGHT: number = 100
  static readonly CARD_PADDING: number = 16
  
  // 表格相关
  static readonly TABLE_HEADER_PADDING_BOTTOM: number = 14
  static readonly TABLE_ROW_PADDING_TOP: number = 18
  static readonly TABLE_ROW_PADDING_BOTTOM: number = 18
  static readonly TABLE_CELL_PADDING_LEFT: number = 22
  static readonly TABLE_CELL_PADDING_RIGHT: number = 22
  
  // 侧边栏
  static readonly SIDEBAR_WIDTH: number = 200
  
  // 对话框最大宽度（旧版）
  static readonly DIALOG_MAX_WIDTH_LEGACY: number = 520
  
  // 菜单相关
  static readonly MENU_WIDTH_SM: number = 80
  static readonly MENU_WIDTH_MD: number = 236
  static readonly MENU_WIDTH_LG: number = 360
  static readonly MENU_ICON_SIZE: number = 20
  static readonly MENU_ICON_TILE_SIZE: number = 40
  static readonly MENU_ITEM_HEIGHT: number = 40
  static readonly MENU_ITEM_RADIUS: number = 8
  static readonly MENU_PADDING: number = 24
  static readonly MENU_MARGIN_SMALL: number = 8
  static readonly MENU_MARGIN_TOP: number = 2
  static readonly MENU_MARGIN_BOTTOM: number = 2
  static readonly MENU_PADDING_SMALL: number = 8
  
  // 图标尺寸
  static readonly ICON_SIZE_SM: number = 20
  static readonly ICON_SIZE_MD: number = 24
  static readonly ICON_SIZE_LG: number = 28
  static readonly ICON_TILE_SIZE_SM: number = 36
  static readonly ICON_TILE_SIZE_MD: number = 52
  static readonly ICON_TILE_SIZE_LG: number = 56
  static readonly ICON_TILE_RADIUS_SM: number = 10
  static readonly ICON_TILE_RADIUS_MD: number = 18
  static readonly ICON_TILE_RADIUS_LG: number = 28
  
  // 分隔线
  static readonly DIVIDER_HEIGHT: number = 1
}

// ==================== 图标尺寸常量 ====================
export class IconDimensions {
  static readonly ICON_SIZE_XS: number = 12
  static readonly ICON_SIZE_SM: number = 16
  static readonly ICON_SIZE_MD: number = 18
  static readonly ICON_SIZE_LG: number = 20
  static readonly ICON_SIZE_XL: number = 24
  static readonly ICON_SIZE_2XL: number = 30
  static readonly ICON_SIZE_3XL: number = 36
  static readonly ICON_SIZE_4XL: number = 44
}

// ==================== 边框常量 ====================
export class BorderDimensions {
  static readonly BORDER_WIDTH_NONE: number = 0
  static readonly BORDER_WIDTH_THIN: number = 0.5
  static readonly BORDER_WIDTH_NORMAL: number = 1
  static readonly BORDER_WIDTH_THICK: number = 2
  static readonly BORDER_WIDTH_BOLD: number = 3
}
