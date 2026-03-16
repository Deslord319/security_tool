# SecurityTool 产品设计图（领导汇报版）

## 图 1：分层架构（一图看懂）

```mermaid
flowchart TB
  subgraph L1[入口层]
    U["用户"]
    S["启动鉴权"]
    H["安全管理中心主页"]
    U --> S --> H
  end

  subgraph L2[业务层（四大能力域）]
    M1["网络安全<br/>防火墙与规则"]
    M2["终端管控<br/>外设策略与身份策略"]
    M3["安全审计<br/>日志采集/筛选/导出"]
    M4["工具安全<br/>启动认证与密码管理"]
  end

  subgraph L3[服务层]
    C1["FirewallService"]
    C2["PeripheralService / IdentityService"]
    C3["LogRuntime + LogAudit + LogStorage"]
    C4["AuthService + SecureStorageService"]
  end

  subgraph L4[系统能力层（HarmonyOS）]
    K1["NetworkKit"]
    K2["MDMKit + restrictions"]
    K3["DeviceSecurityKit + ArkData + FileKit"]
    K4["UserAuthenticationKit + AssetStoreKit"]
  end

  H --> M1
  H --> M2
  H --> M3
  H --> M4

  M1 --> C1 --> K1
  M2 --> C2 --> K2
  M3 --> C3 --> K3
  M4 --> C4 --> K4

  A["企业管理员激活"] -.前置条件.-> M2

  classDef entry fill:#F5F5F5,stroke:#666,color:#222;
  classDef module fill:#EAF3FF,stroke:#2F74FF,color:#1A2B4D;
  classDef svc fill:#EEF9F0,stroke:#2E8B57,color:#173D2C;
  classDef kit fill:#FFF4E8,stroke:#D97706,color:#5A3305;

  class U,S,H,A entry;
  class M1,M2,M3,M4 module;
  class C1,C2,C3,C4 svc;
  class K1,K2,K3,K4 kit;
```

## 图 2：安全运营闭环（汇报重点）

```mermaid
flowchart LR
  P1["策略配置<br/>防火墙/外设/身份"] --> P2["系统执行<br/>MDM/NetworkKit 生效"]
  P2 --> P3["审计采集<br/>安全事件实时入库"]
  P3 --> P4["统计与导出<br/>筛选、报表、留痕"]
  P4 --> P5["策略优化<br/>按风险持续调整"]
```

## 汇报话术（30 秒）

SecurityTool 是一个面向 2in1 设备的企业安全管理中台，采用“一个入口、四大能力域”的架构：网络安全、终端管控、安全审计、工具安全。产品核心价值不是单点功能，而是完整闭环: 策略可下发、执行可验证、事件可审计、结果可复盘。对高风险能力，系统通过企业管理员激活机制做前置保护，确保安全策略可控且可追溯。

## 领导关注点（可直接放 PPT）

1. 结构简洁: 入口统一、能力分层、职责清晰。
2. 闭环完整: 从策略到审计到优化形成持续运营链路。
3. 风险可控: 关键策略受管理员激活机制保护，降低误操作与越权风险。
