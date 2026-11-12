# terraform-volcenginecc-privatelink

基于 volcenginecc Provider 的 Terraform/OpenTofu 模块，用于发布 PrivateLink Endpoint Service、创建消费方 Endpoint，并管理显式连接审批。

## 1. 概述（Overview）

让服务提供方通过私网向消费方暴露服务，适用于 SaaS 私网接入、跨 VPC 服务访问和平台能力开放。服务方 Endpoint Service 关联已有后端；消费方 Interface Endpoint 部署在自己的 VPC 中；服务方通过账号白名单与连接接纳控制访问。

2026-11-04 使用 Terraform 1.5.7、线上 Provider 0.0.73 完成 basic/complete 同账号跨 VPC 测试：默认/可用区域名解析、消费方 CNAME、域名 HTTP、二次 Plan No changes 和标准 Destroy 均通过。全部临时资源已清理。测试使用 source 指向本地模块的隔离示例副本，Registry Module 消费仍未验证。跨账号、原生 TXT DNS 与完整 IAM 权限验证尚未完成。模块不管理 VPC、子网、后端、监听器、安全组规则或 IAM 策略。它们由调用方维护。目标 Provider 文档确认服务资源类型为 CLB、ALB、RDSMySQL；**未确认 NLB 支持**。若 NLB 为必需依赖，本方案须先完成 Provider 支持验证。

```text
当前账号：服务 VPC                          当前账号：消费 VPC
健康后端 → CLB/ALB → Endpoint Service ← 私网连接 ← Endpoint ← 业务客户端
                    白名单 + 手动审批                 ↑
                                              PrivateZone CNAME
```

## 2. 用法（Usage）

完整配置位于 examples/basic 和 examples/complete，填写对应 variables.tf 的必填输入。公开调用地址按本模块名称使用 `terraform-volcenginecc-modules/privatelink/volcenginecc`；规范中的 `terraform-volcenginecc-modules/vpc/volcenginecc` 对应 VPC 模块，其参数不适用于 PrivateLink。当前为未发布 draft，因此 Registry init 暂不能保证成功；不声明虚构版本。以下配置在 Registry 发布后使用，需调用方先提供已有依赖：

```hcl
provider "volcenginecc" {
  region = "cn-beijing"
}

module "privatelink" {
  source  = "terraform-volcenginecc-modules/privatelink/volcenginecc"
  version = "~> 1.0"
  providers = {
    volcenginecc.service  = volcenginecc
    volcenginecc.consumer = volcenginecc
  }

  services = {
    saas = {
      resource_type       = "CLB"
      resources           = [{ resource_id = var.backend_id, zone_ids = [var.zone_id] }]
      permit_account_ids  = [var.account_id]
      auto_accept_enabled = true
    }
  }
  endpoints = {
    client = {
      service_key        = "saas"
      vpc_id             = var.consumer_vpc_id
      security_group_ids = var.security_group_ids
      zones              = [{ zone_id = var.zone_id, subnet_id = var.consumer_subnet_id }]
    }
  }
}
```

在调用方 root 中声明并赋值 `backend_id`、`zone_id`、`account_id`、`consumer_vpc_id`、`consumer_subnet_id`（均为 string）和 `security_group_ids`（list(string)）。这些值必须对应真实、匹配且已授权的资源。凭据通过 Provider 环境变量传入。

调用时将模块的两个别名映射至同一个已配置 Provider：`volcenginecc.service` 管理服务及连接审批，`volcenginecc.consumer` 管理 Endpoint。两个示例的服务与消费 VPC 均属于同一账号。Provider、region、凭据、IAM 权限和 backend 由调用方 root 配置。

资源以 `map(object(...))` 的逻辑 key 标识：

- `services`：提供后端类型、resource_id/zone_ids、明确的 permit_account_ids；默认关闭自动接纳。
- `endpoints`：提供消费方 VPC、安全组及可用区/子网；使用 service_key 关联模块服务，或通过 service_id/service_name 接入外部服务，三者互斥。
- `connections`：显式选择需要批准的 service_key/endpoint_key，仅用于本模块管理的手动审批服务；默认为空。

可以只管理服务或只接入已有服务。外部服务的账号授权、可用区、IP 协议和原生 DNS 前置条件由其所有者确认。模块不查询外部 Data Source，不轮询状态。

## 3. 示例（Examples）

| 示例 | 场景 | 资源与边界 |
|---|---|---|
| basic | 同账号跨 VPC 的最小 SaaS 私网接入 | Endpoint Service、Endpoint、明确账号授权、自动接纳；使用 Endpoint 输出域名 |
| complete | 同账号服务与消费 VPC、手动审批、私网 DNS | 多可用区、单一部署身份、显式审批开关、当前账号白名单、消费方 PrivateZone/CNAME；原生 DNS 可选 |

按用户建议参考 AWS VPC Endpoints 子模块与阿里云 PrivateLink 的场景组织，不将其 Endpoint Policy 或 NLB 字段映射成火山引擎字段。未找到已确认的专项 demo，保留 basic/complete，不新增专项示例目录。

## 4. 版本要求（Requirements）

| 要求 | 版本/前置条件 |
|---|---|
| 已验证引擎 | **Terraform 1.5.7、OpenTofu 1.11.8**；静态检查见验证说明 |
| required_version | >= 1.5.7, <= 1.11.8；此范围用于兼容两个引擎的版本号，不代表范围内所有版本均已验证 |
| VolcengineCC 最低支持版本 | 0.0.60 |
| 当前固定验证版本 | 0.0.73，来自已发布 Registry 版本 |
| 模块 Provider 约束 | >= 0.0.60, <= 0.0.73；后续版本完成验证后再放宽 |
| 外部依赖 | 服务方 VPC 与健康后端、消费方 VPC/子网/安全组、PrivateLink 开通/配额 |
| DNS | complete 需 PrivateZone 权限；原生 public DNS 需公开 TXT 所有权验证 |

仓库遵循《【IaC】Terraformcc Module 仓库建设》规范，提供内容一致的英文与简体中文文档。

## 5. Providers

| Provider alias | 来源与版本约束 | 资源所有权 |
|---|---|---|
| volcenginecc.service | volcengine/volcenginecc >= 0.0.60, <= 0.0.73 | Endpoint Service、服务账号允许的连接审批 |
| volcenginecc.consumer | volcengine/volcenginecc >= 0.0.60, <= 0.0.73 | Endpoint；complete 的 PrivateZone 和记录由示例 root 管理 |

账号白名单只允许指定账号建立请求，不授予 IAM 角色权限，也不自动接纳请求。消费身份必须与白名单账号匹配。安全组应限定业务来源和端口，模块没有开放网段默认值。

调用方还须在 Endpoint 安全组放通 PrivateLink 健康检查：IPv4 入方向 ICMP 来源 `100.64.0.0/10`（`port_start = -1`、`port_end = -1`）；IPv6 则放通入方向 ICMPv6 来源 `fd00:64::/32`。[官方排障指南](https://www.volcengine.com/docs/6980/155955)建议首次连接建立后三分钟再判断健康状态。Endpoint DNS 返回健康可用区地址；所有可用区不健康时，即使 Endpoint 已 Connected、直接 IP 业务可达，域名仍可能返回 NXDOMAIN。规则由调用方维护，模块不会自动添加。

## 6. 资源（Resources）

| 能力分类 | Resource | 实现 |
|---|---|---|
| core | [volcenginecc_privatelink_endpoint_service](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/privatelink_endpoint_service) | services；Interface、后端绑定、账号白名单、接纳模式 |
| core | [volcenginecc_privatelink_vpc_endpoint](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/privatelink_vpc_endpoint) | endpoints；VPC、安全组、可用区、外部/模块服务关联 |
| core | [volcenginecc_privatelink_vpc_endpoint_connection](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/privatelink_vpc_endpoint_connection) | connections；服务方显式审批及可选带宽 |
| complete/recommended | [volcenginecc_privatezone_private_zone](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/privatezone_private_zone) | complete root；仅绑定消费 VPC |
| complete/recommended | [volcenginecc_privatezone_record](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/privatezone_record) | complete root；CNAME 指向 Endpoint 域名 |
| complete/recommended | 服务原生 private_dns 字段 | public 类型、TXT 验证及消费端开启；需额外云端门禁 |
| deferred | NLB、AWS 风格 Endpoint Policy、共享跨账号 DNS Zone | 缺少支持证据或不在当前所有权范围，未伪实现 |

目标版本的 `terraform providers schema -json` 确认：前两类资源字段多数为 Optional+Computed；连接 service_id/endpoint_id 为 Required；服务名称、Endpoint 域名/状态及连接可用区为 Computed-only。脚本同时验证最低和当前版本的实际字段。补充生命周期说明参考本地 Provider 源码，其 checkout 未标记为发布 Tag；静态 Schema 不包含全部 replacement/write-only 元数据，最终行为须通过真实云及版本源码再次核对。

## 7. 输入（Inputs）

| 输入 | 类型 | 默认值 | 必填内容与主要约束 |
|---|---|---|---|
| services | map(object) | {} | resource_type、resources、permit_account_ids；白名单非空且禁止 `*`；支持 tags、payer、项目、IP 协议、private_dns |
| endpoints | map(object) | {} | vpc_id、1–5 个安全组、1–10 个唯一可用区；service_key/id/name 三选一；IPv6 必须双栈 |
| connections | map(object) | {} | service_key、endpoint_key；服务必须关闭 auto_accept；bps 为 100–20000 整数；同一 Endpoint 唯一所有者 |

精确对象结构、默认值与校验见 variables.tf。resources 的 resource_id/zone_ids、tags 的 key/value 均完整定义；zones 显式定义四个属性，未指定 IP 使用 null。服务标签和 Endpoint 标签分别设置。多个资源使用同一个 Provider alias，即同一服务账号和同一消费账号；多消费账号需分别实例化并传入相应 Provider。

## 8. 输出（Outputs）

| 输出 | 内容 |
|---|---|
| services | 逻辑 key → ID、名称、域名、状态、原生 DNS TXT 验证信息 |
| endpoints | 逻辑 key → ID、域名、原生 DNS 名称、状态、连接状态 |
| connections | 逻辑 key → 审批资源 ID、连接状态、只读可用区详情 |

输出不包含凭据。服务 ID 与 Endpoint ID 从各自业务 ID 字段读取，不假设它们与 Terraform 内部 id 相等。

## 9. 其他说明（Notes）

**所有权与审批。** 每个服务、Endpoint、连接关系只有一个 Terraform 所有者。不要同时使用自动接纳和本模块连接审批；已经通过控制台接纳的连接应先 import。complete 先保持 approve_connection=false 创建申请，核对账号及请求后设置 true。显式审批时 endpoints.connection_status 从审批资源读取。2026-11-04 标准 destroy 已观察到撤销连接后变为 Rejected，Endpoint 删除后才删除服务。仅移除 connections key 及再次接纳的完整流程尚未单独验证，不能等同于删除 Endpoint。

**重建。** 根据本地 Provider 元数据，服务的 payer、project_name、service_resource_type、service_type 属于 create-only；Endpoint 的 vpc_id、project_name、service_id/service_name 属于 create-only；连接的 service_id、endpoint_id 和资源分配属于 create-only。修改可能引发替换和连通性中断。逻辑 key 改名改变资源地址；若只重命名，使用 Terraform moved 块迁移，不直接删除/新增。销毁顺序由 ID/域名引用关系连接 DNS 记录、审批、Endpoint 和服务；不设置 create_before_destroy 绕过唯一性约束。

**Import。** 服务使用 service_id、Endpoint 使用 endpoint_id，连接使用 `service_id|endpoint_id`；带 map key 的完整地址须正确加引号。已有 VPC/后端仅传 ID，无需 import 到本模块。当前版本真实 import 与无漂移行为尚未验收。

**回读与二次 Plan。** Optional+Computed Set 的 null、空集合、标签清空及自动分配 IP 可能导致回读漂移。basic 的 IPv4 地址由云端分配，complete 显式指定 IPv4。连接 resources_allocate 为 write-only，可选但默认不发送；原生 DNS verify 仅为 true 时发送，属于 write-only 请求。不能用 ignore_changes 隐藏白名单、安全组或审批漂移。实际 No changes 必须在 apply 后证明。

**DNS。** complete 在消费账号创建私网 Zone，完整管理 vpcs 绑定集合及 CNAME；不共享跨账号 Zone。原生 DNS 仅暴露文档确认的 public 类型；公开 TXT 验证先于消费端开启。泛域名、private 类型与外部权威 DNS 记录管理尚未实现。

**验证。** Terraform 1.5.7 与 OpenTofu 1.11.8 已通过 Provider 0.0.60/0.0.73 静态验证。模块可执行 `terraform fmt -check -recursive`、`terraform init`、`terraform validate`；OpenTofu 使用对应的 `tofu` 命令。运行示例前须提供已有依赖，再执行 init/plan。真实 basic/complete 测试使用 Terraform 1.5.7、Provider 0.0.73 及 source 指向本地模块的隔离示例副本，Apply、DNS/HTTP、二次 Plan No changes 和标准 Destroy 均通过。Registry Module 消费、OpenTofu 云生命周期、跨账号、原生 TXT DNS 以及完整更新/导入矩阵尚未验证。

**许可证。** MIT，见 LICENSE。
