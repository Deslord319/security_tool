# 日志管理模块系统审计事件材料归档

## 1. 背景

当前日志详情弹窗直接展示系统审计事件的原始 JSON，可读性较差。

本轮讨论先不进入方案设计，只整理现阶段已经掌握的系统审计事件材料，作为后续设计输入。

需要特别说明的是，当前日志中的 `ACCOUNT` 事件实际存在两条来源链路：

- 系统审计源触发的 `ACCOUNT` 事件
- 业务代码主动写入的 `ACCOUNT` 运行时日志

其中，业务代码主动写入这条链路目前虽然存在，但后续准备废除，因此**不纳入当前讨论范围**。

本轮只讨论系统审计事件触发的数据源。

## 2. 目的

形成当前阶段的材料归档，明确：

- 目前哪些系统审计事件已经有原型
- 原型是什么样子
- 能从这些原型中抽取出哪些字段

## 3. 当前已确认的系统审计事件原型

### 3.1 ACCOUNT 事件

已拿到系统审计源原型。

原型示例核心内容：

```json
{
  "type": 0,
  "subType": 0,
  "caller": {
    "userName": "111",
    "userId": 100
  },
  "bootTime": "81308595782",
  "wallTime": "1776062376163368595",
  "outcome": "Success",
  "sourceInfo": "",
  "targetInfo": "",
  "extra": ""
}
```

对应外层信息包括：

- `eventId: 268435712`
- `timestamp: 20260413143936`
- `userId: 100`

从这条原型中，当前已确认可抽取字段：

- 用户名：`caller.userName`
- 用户 ID：`caller.userId`
- 结果：`outcome`
- 事件时间：外层 `timestamp`
- 事件 ID：外层 `eventId`

说明：

- 当前只记录这条系统审计源 `ACCOUNT` 原型
- 不记录业务主动写库那条 `ACCOUNT` 链路的字段口径

### 3.2 PERMISSION 事件

已拿到系统审计源原型。

原型示例核心内容：

```json
{
  "bootTime": "...",
  "caller": "",
  "extra": {
    "pid": 8938,
    "uid": 20020149,
    "bundleName": "cn.wps.office.hap",
    "tokenId": 537076660,
    "pname": "cn.wps.office.hap",
    "startTime": "...",
    "timestamp": "...",
    "existingPermissions": [
      {
        "PermissionName": "ohos.permission.MICROPHONE",
        "PermissionState": "PERMISSION_DENIED"
      }
    ],
    "newPermission": {
      "PermissionName": "ohos.permission.READ_WRITE_DOWNLOAD_DIRECTORY",
      "PermissionState": "STATE_CHANGE_GRANTED"
    }
  },
  "objectInfo": "",
  "outcome": "",
  "sourceInfo": "",
  "subType": 0,
  "targetInfo": "",
  "type": 0,
  "wallTime": "..."
}
```

对应外层信息包括：

- `eventId: 184549376`
- `userId: 100`

从这条原型中，当前已确认可抽取字段：

- 应用包名：`extra.bundleName`
- 进程名候选：`extra.pname`
- PID：`extra.pid`
- UID：`extra.uid`
- 新权限名称：`extra.newPermission.PermissionName`
- 新权限状态：`extra.newPermission.PermissionState`
- 已有权限列表：`extra.existingPermissions`
- 事件时间：外层时间字段或 `extra.timestamp`
- 事件 ID：外层 `eventId`

### 3.3 FILE 事件

已有系统审计源历史原型材料。

从现有材料中，`FILE` 事件当前已确认可抽取字段：

- 操作类型：如 `file_open`、`file_write`
- 文件路径：`file_path`
- 进程名：`cmdline` / `processName`
- PID：`pid`
- UID：`uid`
- 结果：`outcome`
- 事件时间
- 事件 ID

## 4. 当前阶段汇总结论

当前已经具备原型材料的系统审计事件类型有：

- `ACCOUNT`
- `PERMISSION`
- `FILE`

其中：

- `ACCOUNT` 已确认存在账号身份字段，如用户名、用户 ID、结果
- `PERMISSION` 已确认存在应用、权限变更、权限列表等字段
- `FILE` 已确认存在操作类型、文件路径、进程、结果等字段

本文件仅作为当前阶段的材料归档，不展开后续方案设计。
