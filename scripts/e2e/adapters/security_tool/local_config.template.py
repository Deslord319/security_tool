# SecurityTool E2E 本地运行时配置模板。
# 复制为 `local_config.py` 后填写真实密码；该文件不会提交到仓库。
#
# 约定：
# - TOOL_PASSWORD 既用于启动认证/锁屏解锁，也用于应用内工具密码
# - 只有这一套密码配置，不再区分启动认证密码和工具密码
# - 除非明确验证跳过认证流程，否则保持 SKIP_STARTUP_AUTH = False

TOOL_PASSWORD = ""
SKIP_STARTUP_AUTH = False
