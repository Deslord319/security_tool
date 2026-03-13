# Bridge Action 执行计划

本文档列出 HarmonyOS MCP bridge 需要支持的标准化 UI 动作，以及每个动作的目标、必要参数和推荐执行步骤。

这些动作不是业务 case，本质上属于 `flow executor -> bridge backend` 之间的中间语义层。

## `add_bluetooth_whitelist`

- 目标：向蓝牙白名单中新增一条记录
- 必填参数：无
- 推荐 MCP 工具：`find_element`、`input_text`、`click_element`、`wait_element`
- 推荐步骤：
  - 填写蓝牙白名单表单
  - 提交对话框
  - 等待新条目出现或成功提示出现

## `add_firewall_rule`

- 目标：在规则详情页新增一条防火墙规则
- 必填参数：无
- 推荐 MCP 工具：`find_element`、`click_element`、`input_text`、`wait_element`
- 推荐步骤：
  - 打开新增规则对话框
  - 按规则类型填写必填字段
  - 提交对话框
  - 等待对话框消失或成功提示出现

## `add_usb_blacklist`

- 目标：向 USB 黑名单中新增一条记录
- 必填参数：无
- 推荐 MCP 工具：`find_element`、`input_text`、`click_element`、`wait_element`
- 推荐步骤：
  - 填写黑名单表单
  - 提交对话框
  - 等待新条目出现或成功提示出现

## `add_usb_whitelist`

- 目标：向 USB 白名单中新增一条记录
- 必填参数：无
- 推荐 MCP 工具：`find_element`、`input_text`、`click_element`、`wait_element`
- 推荐步骤：
  - 填写 USB 白名单表单
  - 提交对话框
  - 等待新条目文本或成功提示出现

## `capture_screenshot`

- 目标：为当前 UI 状态生成一张截图证据
- 必填参数：`name`
- 推荐 MCP 工具：`screenshot`
- 推荐步骤：
  - 生成稳定的截图文件名
  - 通过 HarmonyOS 截图工具保存图片
  - 将截图路径作为 evidence 返回

## `change_any_policy`

- 目标：执行一次策略变更，以触发日志事件
- 必填参数：无
- 推荐 MCP 工具：`find_element`、`click_element`、`input_text`
- 推荐步骤：
  - 导航到任意一个可修改策略的页面
  - 做一次小范围策略修改
  - 如果需要，执行保存

## `delete_firewall_rule`

- 目标：从当前规则列表中删除一条防火墙规则
- 必填参数：无
- 推荐 MCP 工具：`find_element`、`click_element`、`wait_until_gone`
- 推荐步骤：
  - 定位目标规则
  - 从规则行或详情弹框触发删除
  - 如果出现确认框，则确认删除
  - 等待目标规则消失

## `export_logs`

- 目标：执行日志导出流程
- 必填参数：无
- 推荐 MCP 工具：`find_element`、`click_element`、`wait_element`
- 推荐步骤：
  - 打开导出对话框
  - 如有需要，选择导出格式
  - 确认导出
  - 等待导出完成提示

## `find_firewall_rule`

- 目标：在当前规则列表中查找一条防火墙规则
- 必填参数：无
- 推荐 MCP 工具：`find_element`、`scroll_until_text`
- 推荐步骤：
  - 在当前列表中查找目标规则文本
  - 如未命中，滚动直到目标文本进入可视区域

## `navigate_page`

- 目标：通过左侧导航栏打开目标页面
- 必填参数：`page_id`
- 推荐 MCP 工具：`find_element`、`click_element`、`wait_element`
- 推荐步骤：
  - 从 adapter 页面注册表解析目标页面标题
  - 通过文本或稳定 locator 定位导航项
  - 点击目标导航项
  - 等待页面标题或页面锚点出现

## `open_bluetooth_whitelist_dialog`

- 目标：打开蓝牙白名单新增对话框
- 必填参数：无
- 推荐 MCP 工具：`find_element`、`click_element`、`wait_element`
- 推荐步骤：
  - 定位蓝牙白名单入口
  - 打开新增对话框
  - 等待对话框内容出现

## `open_browser_url`

- 目标：在系统浏览器中打开一个 URL
- 必填参数：`url`
- 推荐 MCP 工具：`run_app`、`find_element`、`input_text`、`press_key`
- 推荐步骤：
  - 将浏览器切到前台
  - 聚焦地址栏
  - 输入目标 URL
  - 按下回车或等价确认键

## `open_firewall_rules`

- 目标：打开某一类防火墙规则的详情页
- 必填参数：`rule_type`
- 推荐 MCP 工具：`find_element`、`click_element`、`wait_element`
- 推荐步骤：
  - 定位规则类型卡片或列表项
  - 点击该规则类型
  - 等待规则详情页标题或新增按钮出现

## `open_top_menu`

- 目标：打开顶部三点菜单
- 必填参数：无
- 推荐 MCP 工具：`find_element`、`click_element`、`wait_element`
- 推荐步骤：
  - 定位顶部菜单触发器
  - 点击触发器
  - 等待已知菜单项出现

## `open_usb_blacklist_dialog`

- 目标：打开 USB 黑名单新增对话框
- 必填参数：无
- 推荐 MCP 工具：`find_element`、`click_element`、`wait_element`
- 推荐步骤：
  - 定位 USB 黑名单入口
  - 打开新增对话框
  - 等待对话框可见

## `open_usb_whitelist_dialog`

- 目标：打开 USB 白名单新增对话框
- 必填参数：无
- 推荐 MCP 工具：`find_element`、`click_element`、`wait_element`
- 推荐步骤：
  - 定位 USB 白名单入口
  - 打开新增对话框
  - 等待对话框标题或确认按钮出现

## `save_tool_settings`

- 目标：保存工具设置表单
- 必填参数：无
- 推荐 MCP 工具：`find_element`、`click_element`、`wait_element`
- 推荐步骤：
  - 定位保存按钮
  - 点击保存
  - 等待保存成功提示

## `select_auth_method`

- 目标：在工具设置中选择认证方式
- 必填参数：`method`
- 推荐 MCP 工具：`find_element`、`click_element`、`wait_element`
- 推荐步骤：
  - 打开认证方式选择器
  - 选择目标方式
  - 等待当前选中值可见

## `select_usb_storage_policy`

- 目标：修改 USB 存储策略
- 必填参数：`policy`
- 推荐 MCP 工具：`find_element`、`click_element`、`wait_element`
- 推荐步骤：
  - 打开 USB 存储策略下拉控件
  - 选择目标选项
  - 等待控件上显示新的选中值

## `set_tool_password`

- 目标：提交工具密码表单
- 必填参数：无
- 推荐 MCP 工具：`find_element`、`input_text`、`click_element`、`wait_element`
- 推荐步骤：
  - 填写密码表单
  - 提交表单
  - 等待成功提示或校验提示

## `toggle_firewall`

- 目标：将防火墙开关切换到目标状态
- 必填参数：`target_state`
- 推荐 MCP 工具：`find_element`、`click_element`、`get_ui_tree`
- 推荐步骤：
  - 定位防火墙开关
  - 读取当前状态
  - 仅在状态不一致时点击
  - 再次读取最终状态并返回

## `toggle_peripheral_interface`

- 目标：在外设管理页切换某个接口状态
- 必填参数：`feature`、`target_state`
- 推荐 MCP 工具：`find_element`、`click_element`、`get_ui_tree`
- 推荐步骤：
  - 定位目标接口行
  - 读取当前开关状态
  - 仅在需要变更时点击
  - 读取变更后的结果状态

## `toggle_startup_auth`

- 目标：切换工具设置中的启动认证开关
- 必填参数：`target_state`
- 推荐 MCP 工具：`find_element`、`click_element`、`get_ui_tree`
- 推荐步骤：
  - 定位启动认证开关
  - 读取当前状态
  - 仅在需要变更时点击
  - 读取最终状态

## `update_domain_account_policy`

- 目标：修改身份鉴别中的域账号策略表单
- 必填参数：无
- 推荐 MCP 工具：`find_element`、`input_text`、`click_element`
- 推荐步骤：
  - 定位域账号策略控件
  - 更新相关字段
  - 返回字段级 evidence，供后续断言使用

## `update_password_policy`

- 目标：修改身份鉴别中的密码策略表单
- 必填参数：无
- 推荐 MCP 工具：`find_element`、`input_text`、`click_element`
- 推荐步骤：
  - 定位密码策略表单控件
  - 逐项更新配置字段
  - 返回字段级 evidence，供后续保存和断言使用
