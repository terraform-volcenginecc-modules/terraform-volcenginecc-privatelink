# BASIC PrivateLink 示例

模块 source 为 `terraform-volcenginecc-modules/privatelink/volcenginecc`，模块版本约束为 `version = "~> 1.0"`（>= 1.0.0、< 2.0.0），与 Provider 版本要求分别配置。Registry 安装要求该范围内已有已发布模块版本。

## 1. 概述

本示例在同一账号的两个 VPC 之间建立最小 PrivateLink 链路：服务方使用已有单可用区 CLB 发布 Endpoint Service，消费方在已有 VPC 和子网中创建 Endpoint，并通过账号白名单和自动接纳建立连接。调用方需准备 CLB、健康后端、消费方网络和安全组；多可用区、手动审批和私网 DNS 见 complete 示例。

## 2. 用法

在 `examples/basic` 目录创建本地 `terraform.tfvars`，填写第 6 节列出的全部输入。凭据通过 Provider 支持的运行环境传入。

```shell
terraform init
terraform plan
terraform apply
terraform plan
terraform destroy
```

Apply 后确认服务和 Endpoint 状态可用、连接为 `Connected`，并从消费方 VPC 解析和访问 Endpoint 输出域名。第二次 Plan 用于检查幂等性。Destroy 前核对范围；已有 CLB、VPC、子网、安全组和业务后端不会被本示例删除。

## 3. 依赖要求

| 名称 | 版本 |
|---|---|
| `terraform` | `>= 1.5.7, <= 1.11.8`；项目基线为 `= 1.5.7` |
| `volcengine/volcenginecc` | `= 0.0.73` |

## 4. Providers

| 名称 | 来源 |
|---|---|
| `volcenginecc.service` | `volcengine/volcenginecc`；管理 Endpoint Service |
| `volcenginecc.consumer` | `volcengine/volcenginecc`；管理消费方 Endpoint |

两个 alias 在本示例中使用相同地域和账号身份。

## 5. 资源

| 名称 | 说明 |
|---|---|
| `module.privatelink` | 通过 `terraform-volcenginecc-modules/privatelink/volcenginecc` 创建自动接纳的 Endpoint Service 和单可用区 Endpoint。 |

本示例不直接创建其他 Resource 或 Data Source。

## 6. 输入

| 名称 | 说明 |
|---|---|
| `region` | 服务方和消费方资源所在地域。 |
| `zone_id` | 后端 CLB 与消费方子网共同支持的可用区。 |
| `backend_id` | 已有服务方 CLB ID；其监听器和健康后端由调用方维护。 |
| `account_id` | 当前数字账号 ID，用作 Endpoint Service 的唯一账号白名单。 |
| `consumer_vpc_id` | 已有消费方 VPC ID。 |
| `consumer_subnet_id` | 消费方子网 ID，必须属于 `consumer_vpc_id` 和 `zone_id`。 |
| `security_group_ids` | 消费方安全组 ID 集合，应只放行业务来源、业务端口和 PrivateLink 健康检查。 |

所有输入均无默认值。

## 7. 输出

| 名称 | 说明 |
|---|---|
| `services` | Endpoint Service 的 ID、名称、域名、状态及原生 DNS 配置信息。 |
| `endpoints` | 消费方 Endpoint 的 ID、域名、状态和连接状态。 |

## 8. 示例

本目录即为 basic 示例，适合单账号、单可用区、自动接纳且直接使用 Endpoint 域名的最小接入场景。需要手动审批、多可用区或自定义私网域名时使用 complete 示例。

## 9. 说明

- 凭据通过 Provider 支持的运行环境或认证配置传入，不写入源文件或参数文件。
- Apply 后再次执行 `terraform plan`；结果无变化才满足幂等要求。
- Endpoint 安全组除业务端口外，还需允许 IPv4 入方向 ICMP 来源 `100.64.0.0/10`；IPv6 场景允许 ICMPv6 来源 `fd00:64::/32`。健康状态稳定后再检查 DNS。
- 账号白名单允许当前账号发起连接，但不授予 IAM 权限。安全组规则、后端鉴权和最小权限由调用方维护。
- 本示例支持 CLB 后端，不支持以 NLB ID 替代 `backend_id`。
- Destroy 只删除 `module.privatelink` 管理的 Endpoint 和 Endpoint Service，调用方已有依赖继续保留。
