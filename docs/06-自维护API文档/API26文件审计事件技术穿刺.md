# API26 文件审计事件技术穿刺

## 1. 背景与目标

本次调研聚焦 API 26 `securityAudit.NotifyEvent` 文件相关事件，目标是确认这些事件在 2in1 设备上的触发条件，以及触发后审计日志中能看到的关键字段。

本次只记录调研结论，不更新模块设计文档；本次不验证 `DLP_FILE_ACCESS`。

测试目录限定在用户目录下：

```text
/data/service/el2/100/hmdfs/account/files/Docs/Download/security_audit_probe_20260626/
/data/service/el2/100/hmdfs/account/files/Docs/Download/security_audit_probe_ui_20260626/
```

应用侧归一化展示路径为：

```text
/storage/Users/currentUser/Download/...
```

## 2. 通用日志字段

审计回调的 `content.extra` 是字符串化 JSON。文件审计事件常见字段如下：

| 字段 | 含义 |
|---|---|
| `eventId` | `securityAudit.NotifyEvent` 事件值。 |
| `event_name` | 底层审计事件名，例如 `file_create`、`file_close`。 |
| `file_path` | 单路径事件的目标路径。 |
| `file_oldpath` | 双路径事件的源路径，例如复制源路径。 |
| `file_newpath` | 双路径事件的目标路径，例如复制目标路径。 |
| `file_mode` | 文件当前权限模式。 |
| `file_newmode` | 权限变更后的新模式。 |
| `file_owneruid` / `file_ownergid` | 文件原属主 / 属组。 |
| `file_newuid` / `file_newgid` | 属主 / 属组变更后的新值。 |
| `file_xattrname` | 扩展属性名称。 |
| `file_size` | 文件大小。 |
| `caller` / `pcomm` / `pid` / `uid` | 触发事件的进程与用户信息。 |
| `timestamp` | 事件发生时间。 |

应用映射后的典型日志形态：

```text
AUDIT_MAPPED eventId=469766404, eventType=1, rawEventName=file_create,
filePath=/storage/Users/currentUser/Download/security_audit_probe_20260626/01_create.txt
```

## 3. FILE_CREATE

### API 文档信息

| 项目 | 内容 |
|---|---|
| 枚举名 | `securityAudit.NotifyEvent.FILE_CREATE` |
| API26 事件值 | `0x1C001104` / `469766404` |
| 官方说明 | 文件创建事件。 |

### 触发条件

```text
mkdir -p .../security_audit_probe_20260626
touch .../security_audit_probe_20260626/01_create.txt
```

### 日志详情

已捕获目标事件。

```text
eventId=469766404
event_name=file_create
file_path=/data/service/el2/100/hmdfs/account/files/Docs/Download/security_audit_probe_20260626/01_create.txt
file_mode=644
file_owneruid=0
file_ownergid=1006
pcomm=/bin/sh
uid=0
```

应用归一化路径：

```text
/storage/Users/currentUser/Download/security_audit_probe_20260626/01_create.txt
```

### 结论

`FILE_CREATE` 可稳定触发。创建动作通常还会伴随旧 `FILE(0x1C000007)` 和 `FILE_CLOSE`。

## 4. FILE_OPEN

### API 文档信息

| 项目 | 内容 |
|---|---|
| 枚举名 | `securityAudit.NotifyEvent.FILE_OPEN` |
| API26 事件值 | `0x1C001105` / `469766405` |
| 官方说明 | 文件打开事件。 |

### 触发条件

尝试过两类触发：

```text
cat .../01_create.txt > /dev/null
文件管理器 UI 打开 ui_open.txt / ui_rename_source.txt
```

### 日志详情

未捕获目标事件。

已观察到的相关日志为 `FILE_CLOSE`：

```text
eventId=469766406
event_name=file_close
file_path=/data/service/el2/100/hmdfs/account/files/Docs/Download/security_audit_probe_ui_20260626
caller=com.huawei.hmos.filemanager
```

### 结论

当前 shell 读取和文件管理器打开文件都未捕获 `FILE_OPEN`。

## 5. FILE_CLOSE

### API 文档信息

| 项目 | 内容 |
|---|---|
| 枚举名 | `securityAudit.NotifyEvent.FILE_CLOSE` |
| API26 事件值 | `0x1C001106` / `469766406` |
| 官方说明 | 文件关闭事件。 |

### 触发条件

```text
touch .../01_create.txt
cat .../01_create.txt > /dev/null
文件管理器 UI 打开目录或文件
```

### 日志详情

已捕获目标事件。

```text
eventId=469766406
event_name=file_close
file_path=/data/service/el2/100/hmdfs/account/files/Docs/Download/security_audit_probe_20260626/01_create.txt
file_mode=644
file_size=<实际文件大小>
file_owneruid=0
file_ownergid=1006
```

文件管理器 UI 场景中也会出现目录关闭日志：

```text
eventId=469766406
event_name=file_close
caller=com.huawei.hmos.filemanager
file_path=/data/service/el2/100/hmdfs/account/files/Docs/Download/security_audit_probe_ui_20260626
```

### 结论

`FILE_CLOSE` 可稳定触发，且日志量较高。

## 6. FILE_DELETE

### API 文档信息

| 项目 | 内容 |
|---|---|
| 枚举名 | `securityAudit.NotifyEvent.FILE_DELETE` |
| API26 事件值 | `0x1C001107` / `469766407` |
| 官方说明 | 文件删除事件。 |

### 触发条件

尝试过两类触发：

```text
rm .../rename_target.txt
文件管理器 UI 选中文件后点击删除
```

### 日志详情

未捕获目标事件。

文件管理器 UI 删除后，目录文件数量从 5 个变为 4 个，说明文件实际删除成功；但 hilog 中只观察到目录 `FILE_CLOSE`：

```text
eventId=469766406
event_name=file_close
file_path=/data/service/el2/100/hmdfs/account/files/Docs/Download/security_audit_probe_ui_20260626
caller=com.huawei.hmos.filemanager
```

### 结论

当前 shell 删除和文件管理器 UI 删除都未捕获 `FILE_DELETE`。

## 7. FILE_RENAME

### API 文档信息

| 项目 | 内容 |
|---|---|
| 枚举名 | `securityAudit.NotifyEvent.FILE_RENAME` |
| API26 事件值 | `0x1C001108` / `469766408` |
| 官方说明 | 文件重命名事件。 |

### 触发条件

```text
mv .../rename_source.txt .../rename_target.txt
```

文件管理器 UI 重命名入口本轮未稳定完成。

### 日志详情

未捕获目标事件。

shell `mv` 后文件名实际变化，但未观察到：

```text
eventId=469766408
event_name=file_rename
```

### 结论

当前仅能确认 shell `mv` 未捕获 `FILE_RENAME`；UI 重命名仍需补测。

## 8. FILE_COPY

### API 文档信息

| 项目 | 内容 |
|---|---|
| 枚举名 | `securityAudit.NotifyEvent.FILE_COPY` |
| API26 事件值 | `0x1C001109` / `469766409` |
| 官方说明 | 文件复制事件。 |

### 触发条件

```text
cp .../01_create.txt .../02_copy.txt
```

### 日志详情

已捕获目标事件。

```text
eventId=469766409
event_name=file_copyfile
file_oldpath=/data/service/el2/100/hmdfs/account/files/Docs/Download/security_audit_probe_20260626/01_create.txt
file_newpath=/data/service/el2/100/hmdfs/account/files/Docs/Download/security_audit_probe_20260626/02_copy.txt
```

应用归一化展示路径取目标路径：

```text
/storage/Users/currentUser/Download/security_audit_probe_20260626/02_copy.txt
```

### 结论

`FILE_COPY` 可稳定触发。复制动作还会伴随目标文件 `FILE_CREATE` 和源文件 `FILE_CLOSE`。

## 9. FILE_SETOWNER

### API 文档信息

| 项目 | 内容 |
|---|---|
| 枚举名 | `securityAudit.NotifyEvent.FILE_SETOWNER` |
| API26 事件值 | `0x1C00110A` / `469766410` |
| 官方说明 | 文件属主或属组变更事件。 |

### 触发条件

```text
chown 20001006:file_manager .../03_renamed.txt
```

### 日志详情

已捕获目标事件。

```text
eventId=469766410
event_name=file_chown
file_path=/data/service/el2/100/hmdfs/account/files/Docs/Download/security_audit_probe_20260626/03_renamed.txt
file_newuid=20001006
file_newgid=1006
file_mode=600
```

### 结论

`FILE_SETOWNER` 可稳定触发。

## 10. FILE_SETMODE

### API 文档信息

| 项目 | 内容 |
|---|---|
| 枚举名 | `securityAudit.NotifyEvent.FILE_SETMODE` |
| API26 事件值 | `0x1C00110B` / `469766411` |
| 官方说明 | 文件权限模式变更事件。 |

### 触发条件

```text
chmod 600 .../03_renamed.txt
```

### 日志详情

已捕获目标事件。

```text
eventId=469766411
event_name=file_chmod
file_path=/data/service/el2/100/hmdfs/account/files/Docs/Download/security_audit_probe_20260626/03_renamed.txt
file_newmode=600
```

### 结论

`FILE_SETMODE` 可稳定触发。

## 11. FILE_SETEXTATTR

### API 文档信息

| 项目 | 内容 |
|---|---|
| 枚举名 | `securityAudit.NotifyEvent.FILE_SETEXTATTR` |
| API26 事件值 | `0x1C00110C` / `469766412` |
| 官方说明 | 设置文件扩展属性事件。 |

### 触发条件

```text
setfattr -n user.security_audit_probe -v api26 .../03_renamed.txt
```

### 日志详情

已捕获目标事件。

```text
eventId=469766412
event_name=file_setxattr
file_path=/data/service/el2/100/hmdfs/account/files/Docs/Download/security_audit_probe_20260626/03_renamed.txt
file_xattrname=user.security_audit_probe
```

### 结论

`FILE_SETEXTATTR` 可稳定触发。

## 12. FILE_DELETEEXTATTR

### API 文档信息

| 项目 | 内容 |
|---|---|
| 枚举名 | `securityAudit.NotifyEvent.FILE_DELETEEXTATTR` |
| API26 事件值 | `0x1C00110D` / `469766413` |
| 官方说明 | 删除文件扩展属性事件。 |

### 触发条件

```text
setfattr -x user.security_audit_probe .../03_renamed.txt
```

### 日志详情

已捕获目标事件。

```text
eventId=469766413
event_name=file_removexattr
file_path=/data/service/el2/100/hmdfs/account/files/Docs/Download/security_audit_probe_20260626/03_renamed.txt
file_xattrname=user.security_audit_probe
```

### 结论

`FILE_DELETEEXTATTR` 可稳定触发。

## 13. FILE_WRITE

### API 文档信息

| 项目 | 内容 |
|---|---|
| 枚举名 | `securityAudit.NotifyEvent.FILE_WRITE` |
| API26 事件值 | `0x1C00110E` / `469766414` |
| 官方说明 | 文件写入事件。 |

### 触发条件

```text
echo ... >> .../01_create.txt
dd ... conv=notrunc
```

### 日志详情

未捕获目标事件。

文件大小实际变化，但未观察到：

```text
eventId=469766414
event_name=file_write
```

`dd` 复测只捕获到辅助源文件的 `FILE_CREATE` / `FILE_CLOSE`。

### 结论

当前 shell 写入方式未捕获 `FILE_WRITE`。

## 14. FILE_SHARE

### API 文档信息

| 项目 | 内容 |
|---|---|
| 枚举名 | `securityAudit.NotifyEvent.FILE_SHARE` |
| API26 事件值 | `0x0F000002` / `251658242` |
| 官方说明 | 文件分享事件。 |

### 触发条件

文件管理器 UI 选中文件后点击分享：

```text
ui_rename_source.txt -> 分享 -> 系统分享面板
ui_rename_source.txt -> 分享 -> 加密分享
```

### 日志详情

未捕获目标事件。

UI 已出现系统分享面板：

```text
分享卡片: ui_rename_source.txt, 10 B
分享目标: 华为分享 / 蓝牙 / 电子邮件 / 加密分享
```

进入“加密分享设置”并出现华为账号登录弹窗后，仍未观察到：

```text
eventId=251658242
event_name=file_share
```

### 结论

当前只打开分享面板或进入分享目标入口，未捕获 `FILE_SHARE`。

## 15. DATA_DRAG

### API 文档信息

| 项目 | 内容 |
|---|---|
| 枚举名 | `securityAudit.NotifyEvent.DATA_DRAG` |
| API26 事件值 | `0x0F000003` / `251658243` |
| 官方说明 | 数据拖拽事件。 |

### 触发条件

```text
文件管理器中对 ui_drag_source.txt 执行 uitest uiInput drag 拖拽手势
```

### 日志详情

未捕获目标事件。

拖拽手势执行后未观察到：

```text
eventId=251658243
event_name=data_drag
```

期间只捕获到测试目录自身的 `FILE_CLOSE`：

```text
eventId=469766406
event_name=file_close
file_path=/data/service/el2/100/hmdfs/account/files/Docs/Download/security_audit_probe_ui_20260626
caller=com.huawei.hmos.filemanager
```

### 结论

当前单窗口文件拖拽未捕获 `DATA_DRAG`。

## 16. 结果汇总

| 事件 | 是否找到目标日志 |
|---|---|
| `FILE_CREATE` | 是 |
| `FILE_OPEN` | 否 |
| `FILE_CLOSE` | 是 |
| `FILE_DELETE` | 否 |
| `FILE_RENAME` | 否 |
| `FILE_COPY` | 是 |
| `FILE_SETOWNER` | 是 |
| `FILE_SETMODE` | 是 |
| `FILE_SETEXTATTR` | 是 |
| `FILE_DELETEEXTATTR` | 是 |
| `FILE_WRITE` | 否 |
| `FILE_SHARE` | 否 |
| `DATA_DRAG` | 否 |
