# terraform-volcenginecc-privatelink

用于发布火山引擎 PrivateLink 服务、创建消费方终端节点，并管理显式连接审批。

模块 source 为 `terraform-volcenginecc-modules/privatelink/volcenginecc`，模块版本约束为 `version = "~> 1.0"`（>= 1.0.0、< 2.0.0），与 Provider 版本要求分别配置。Registry 安装要求该范围内已有已发布模块版本。

## 1. 概述（Overview）

本模块将已有 CLB、ALB 或 RDS MySQL 后端发布为 Endpoint Service，在消费方 VPC 中创建 Interface Endpoint，并可由服务方显式接纳连接。账号白名单、Endpoint 安全组和可选私有 DNS 共同限定访问范围；VPC、子网、后端、监听器、安全组规则及 IAM 权限由调用方维护。

```text
当前账号：服务 VPC                          当前账号：消费 VPC
健康后端 → CLB/ALB → Endpoint Service ← 私网连接 ← Endpoint ← 业务客户端
                    白名单 + 手动审批                 ↑
                                              PrivateZone CNAME
```

## 2. 用法（Usage）

调用前需准备服务方后端、消费方 VPC/子网/安全组，并开通 PrivateLink 及所需配额。以下配置使用同一账号管理服务与消费方资源；跨账号时分别配置并传入两个 Provider alias。

```hcl
provider "volcenginecc" {
  alias  = "service"
  region = var.region
}

provider "volcenginecc" {
  alias  = "consumer"
  region = var.region
}

module "privatelink" {
  source  = "terraform-volcenginecc-modules/privatelink/volcenginecc"
  version = "~> 1.0"

  providers = {
    volcenginecc.service  = volcenginecc.service
    volcenginecc.consumer = volcenginecc.consumer
  }

  services = {
    saas = {
      resource_type       = "CLB"
      resources           = [{ resource_id = var.backend_id, zone_ids = [var.zone_id] }]
      permit_account_ids  = [var.consumer_account_id]
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

凭据通过 Provider 支持的环境变量或调用方认证配置注入，不写入 Module。运行 `examples/basic` 或 `examples/complete` 前，填写该目录 `variables.tf` 要求的输入，然后在对应目录执行 `terraform init`、`terraform plan` 和 `terraform apply`。

## 3. 示例（Examples）

- basic：使用已有单可用区 CLB、消费方 VPC/子网/安全组，创建自动接纳的 Endpoint Service 和 Endpoint；客户端通过 Endpoint 输出域名访问服务。
- complete：增加多可用区后端与 Endpoint、手动审批开关、标签和项目配置；示例 root 另外创建仅绑定消费方 VPC 的 PrivateZone 及 CNAME。首次部署保持 `approve_connection = false`，核对申请后改为 `true`。

## 4. 版本要求（Requirements）

| 名称 | 版本 |
|---|---|
| `terraform` | `>= 1.5.7, <= 1.11.8`；项目基线为 `= 1.5.7` |
| `volcengine/volcenginecc` | `>= 0.0.60, <= 0.0.73`；示例固定为 `= 0.0.73` |

## 5. Providers（Providers）

| 名称 | 来源 |
|---|---|
| `volcenginecc.service` | `volcengine/volcenginecc`；管理 Endpoint Service 和连接审批 |
| `volcenginecc.consumer` | `volcengine/volcenginecc`；管理消费方 Endpoint |

账号白名单只允许指定账号发起连接，不授予 IAM 权限，也不代替手动审批。调用方应为两个 alias 配置对应地域、身份与最小权限。

## 6. 资源（Resources）

| 模式 | 类型 | 名称 |
|---|---|---|
| 创建 | Resource | [`volcenginecc_privatelink_endpoint_service.this`](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/privatelink_endpoint_service) |
| 创建 | Resource | [`volcenginecc_privatelink_vpc_endpoint.this`](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/privatelink_vpc_endpoint) |
| 创建 | Resource | [`volcenginecc_privatelink_vpc_endpoint_connection.this`](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/privatelink_vpc_endpoint_connection) |

根 Module 不创建 VPC、子网、负载均衡、安全组规则或 DNS Zone。complete 示例中的 `volcenginecc_privatezone_private_zone` 和 `volcenginecc_privatezone_record` 归示例 root 所有。

## 7. 输入（Inputs）

| 名称 | 类型 | 默认值 | 创建模式下是否必填 | 说明 |
|---|---|---|---|---|
| `services` | `map(object(...))` | `{}` | 否 | Endpoint Service 集合；每个元素必须提供后端类型、后端资源和明确的数字账号白名单。 |
| `endpoints` | `map(object(...))` | `{}` | 否 | Endpoint 集合；每个元素提供消费方网络，并从 `service_key`、`service_id`、`service_name` 中选择一项。 |
| `connections` | `map(object(...))` | `{}` | 否 | 显式审批集合；仅引用本模块管理、关闭自动接纳且相互匹配的服务与 Endpoint。 |

`services` 的完整元素结构：

```hcl
object({
  resource_type       = string
  resources           = list(object({ resource_id = string, zone_ids = list(string) }))
  permit_account_ids  = set(string)
  auto_accept_enabled = optional(bool, false)
  description         = optional(string, "")
  project_name        = optional(string, "default")
  payer               = optional(string, "Endpoint")
  ip_address_versions = optional(set(string), ["ipv4"])
  tags                = optional(list(object({ key = string, value = string })), [])
  private_dns = optional(object({
    name   = string
    type   = optional(string, "public")
    verify = optional(bool, false)
  }))
})
```

`resource_type` 支持 `CLB`、`ALB`、`RDSMySQL`。`resources` 不得为空或重复；CLB/ALB 后端必须提供非空且不重复的可用区。`permit_account_ids` 只接受明确的数字账号 ID。`payer` 为 `Endpoint` 或 `EndpointService`。IP 协议必须包含 `ipv4`，可选 `ipv6`。原生 DNS 当前仅支持非泛域名 `public` 类型，验证前需在公开权威 DNS 中配置 TXT 所有权记录。

`endpoints` 的完整元素结构：

```hcl
object({
  vpc_id             = string
  security_group_ids = set(string)
  zones = list(object({
    zone_id               = string
    subnet_id             = string
    private_ip_address    = optional(string)
    private_ipv_6_address = optional(string)
  }))
  service_key         = optional(string)
  service_id          = optional(string)
  service_name        = optional(string)
  name                = optional(string)
  description         = optional(string, "")
  project_name        = optional(string, "default")
  private_dns_enabled = optional(bool, false)
  ip_address_versions = optional(set(string), ["ipv4"])
  tags                = optional(list(object({ key = string, value = string })), [])
})
```

每个 Endpoint 必须提供 VPC、1–5 个安全组和 1–10 个不重复的可用区。`service_key`、`service_id`、`service_name` 必须且只能设置一项。指定 IPv6 地址时必须启用双栈；显式 IP 是否属于对应子网由云端校验。使用 `service_key` 时，Endpoint 协议和可用区必须由被引用服务支持；开启原生私有 DNS 前，服务必须配置 `private_dns`。

`connections` 的完整元素结构：

```hcl
object({
  service_key  = string
  endpoint_key = string
  bps          = optional(number)
  resources_allocate = optional(list(object({
    resource_id = string
    zone_id     = string
  })))
})
```

`bps` 如设置，必须为 100–20000 的整数。一个 Endpoint 只能由一个连接 key 管理。`resources_allocate` 如设置，必须覆盖有效且不重复的可用区，并与服务后端和 Endpoint 可用区匹配；该字段为 write-only，使用后需重点检查二次 plan。

## 8. 输出（Outputs）

| 名称 | 类型 | 说明 |
|---|---|---|
| `services` | `map(object)` | 按逻辑 key 输出服务 `id`、`name`、`domain`、`status` 和 `private_dns_name_configuration`。 |
| `endpoints` | `map(object)` | 按逻辑 key 输出 Endpoint `id`、`domain`、`private_dns_name`、`status` 和 `connection_status`。 |
| `connections` | `map(object)` | 按逻辑 key 输出审批资源 `id`、连接 `status` 和只读 `zones`。 |

输出不包含凭据。未配置对应输入集合时，其输出为空 map。

## 9. 其他说明（Notes）

- 每个服务、Endpoint 和连接关系只能有一个 Terraform 所有者。自动接纳服务不要同时配置 `connections`；控制台已接纳的连接应先导入 State。
- 服务的 `payer`、`project_name`、`resource_type`，Endpoint 的 `vpc_id`、`project_name`、服务引用，以及连接的服务、Endpoint 和资源分配发生变化时，Provider 可能替换资源并中断连接。仅重命名逻辑 key 时使用 `moved` 块迁移地址。
- Import ID：服务使用 `service_id`，Endpoint 使用 `endpoint_id`，连接使用 `service_id|endpoint_id`。已有 VPC 和后端只通过 ID 引用，不导入本模块。
- Endpoint 安全组应只放行业务来源和端口，并允许健康检查：IPv4 入方向 ICMP 来源 `100.64.0.0/10`；IPv6 入方向 ICMPv6 来源 `fd00:64::/32`。首次连接后等待健康状态稳定，再检查 Endpoint DNS。
- `resources_allocate` 和 DNS 验证请求含 write-only 字段，Provider 回读可能产生差异。Provider `0.0.73` 的连接带宽回读也可能与配置值不同；应用后必须执行一次正常的 `terraform plan`，检查幂等性，不要用 `ignore_changes` 隐藏审批、白名单或安全组差异。
- 原生 DNS 仅暴露 Provider 已确认的 `public` 类型；私有类型、泛域名和外部权威 DNS 记录不由本模块管理。NLB 后端不在当前支持范围。
- 销毁时，Terraform 引用关系会先移除连接审批和依赖 Endpoint 域名的记录，再删除 Endpoint 和 Endpoint Service。VPC、子网、后端、安全组及 complete 示例之外的 DNS 资源继续由原所有者维护。
