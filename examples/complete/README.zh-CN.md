# COMPLETE PrivateLink 示例

模块 source 为 `terraform-volcenginecc-modules/privatelink/volcenginecc`，模块版本约束为 `version = "~> 1.0"`（>= 1.0.0、< 2.0.0），与 Provider 版本要求分别配置。Registry 安装要求该范围内已有已发布模块版本。

## 1. 概述

本示例在同一账号的服务方和消费方 VPC 之间建立多可用区 PrivateLink：已有 CLB/ALB 后端通过 Endpoint Service 发布，消费方创建多可用区 Endpoint，服务方分阶段审批连接；示例 root 还创建仅绑定消费 VPC 的 PrivateZone 和 CNAME。调用方需准备后端、VPC、子网、安全组及空闲私网 IP。basic 示例不包含手动审批和自定义私网 DNS。

## 2. 用法

在 `examples/complete` 目录创建本地 `terraform.tfvars`，填写第 6 节列出的必填输入。首次部署保持 `approve_connection = false`：

```shell
terraform init
terraform plan
terraform apply
terraform plan
terraform apply
terraform plan
terraform destroy
```

首次 Apply 后核对消费账号、VPC、Endpoint ID 和 `PendingAcceptance` 状态。随后将 `approve_connection` 改为 `true`，使用第二个 Plan 和 Apply 创建审批资源。连接达到 `Connected` 且各区健康后，从消费方 VPC 检查 Endpoint 域名、PrivateZone 域名和业务端口。最终 Plan 用于检查幂等性；Destroy 前核对删除范围。

## 3. 依赖要求

| 名称 | 版本 |
|---|---|
| `terraform` | `>= 1.5.7, <= 1.11.8`；项目基线为 `= 1.5.7` |
| `volcengine/volcenginecc` | `= 0.0.73` |

## 4. Providers

| 名称 | 来源 |
|---|---|
| `volcenginecc` | `volcengine/volcenginecc`；同时传给 Module 的 `service`、`consumer` alias，并管理 PrivateZone 资源 |

本示例使用同一账号身份管理服务方、消费方、审批和 DNS。

## 5. 资源

| 名称 | 说明 |
|---|---|
| `module.privatelink` | 通过 `terraform-volcenginecc-modules/privatelink/volcenginecc` 创建 Endpoint Service、多可用区 Endpoint 和可选审批资源。 |
| `volcenginecc_privatezone_private_zone.client` | 创建仅绑定消费方 VPC 的 PrivateZone。 |
| `volcenginecc_privatezone_record.service` | 创建 CNAME，将业务域名指向 Endpoint 输出域名。 |

## 6. 输入

| 名称 | 说明 |
|---|---|
| `region` | 服务方、消费方和 PrivateZone 资源所在地域；无默认值。 |
| `backend_type` | 后端类型，支持 `CLB` 或 `ALB`；默认 `CLB`。 |
| `backends` | 可用区 ID 到后端 ID 的映射，至少包含两个可用区；无默认值。 |
| `consumer_account_id` | 当前部署身份的数字账号 ID，用作唯一账号白名单；无默认值。 |
| `consumer_vpc_id` | 已有消费方 VPC ID；无默认值。 |
| `consumer_subnets` | 可用区 ID 到 `{ id, private_ip_address }` 的映射，至少两区；IP 必须属于对应子网且未占用；无默认值。 |
| `security_group_ids` | 消费方安全组 ID 集合，放行业务来源、业务端口和健康检查；无默认值。 |
| `approve_connection` | 是否创建显式连接审批；默认 `false`，核对申请后改为 `true`。 |
| `connection_bps` | 审批连接带宽 Mbps；默认 `null`，使用云端默认值。 |
| `payer` | 付费方，`Endpoint` 或 `EndpointService`；默认 `Endpoint`。 |
| `service_project_name` | Endpoint Service 所属项目；默认 `default`。 |
| `consumer_project_name` | Endpoint 和 PrivateZone 所属项目；默认 `default`。 |
| `service_description` | Endpoint Service 描述；默认 `SaaS private service with manual approval`。 |
| `tags` | 服务、Endpoint 和 PrivateZone 使用的 key/value 标签列表；默认包含 `scenario=saas-private-access`。 |
| `dns_zone_name` | 消费方专用 PrivateZone 域名；不得与现有 Zone 或原生 DNS 名称冲突；无默认值。 |
| `dns_record_host` | CNAME 单级主机名；默认 `api`。 |
| `dns_ttl` | CNAME TTL，范围 60–86400 秒；默认 `300`。 |
| `native_private_dns` | 可选原生 DNS 对象 `{ name, type, verify }`；默认 `null`，当前类型仅支持 `public`。 |
| `enable_native_private_dns` | 是否在 Endpoint 启用已验证的原生私网 DNS；默认 `false`。 |

## 7. 输出

| 名称 | 说明 |
|---|---|
| `services` | Endpoint Service ID、名称、域名、状态及原生 DNS 验证信息。 |
| `endpoints` | 消费方 Endpoint ID、域名、状态和连接状态。 |
| `connections` | `approve_connection = true` 时输出审批资源 ID、状态和可用区信息；否则为空 map。 |
| `private_dns_name` | 消费方 VPC 内使用的完整业务域名。 |
| `private_dns_zone_id` | 示例创建的 PrivateZone ID。 |

## 8. 示例

本目录即为 complete 示例，适合同账号、多可用区、手动审批和消费方自定义私网 DNS 场景。相比 basic，它增加连接审批、PrivateZone/CNAME、项目、标签和原生 DNS 可选配置。

## 9. 说明

- 凭据通过 Provider 支持的运行环境或认证配置传入，不写入源文件或参数文件。
- Apply 后再次执行 `terraform plan`；除下述已知问题外，结果无变化才满足幂等要求。
- **已知问题（`Volcengine::PrivateLink::VpcEndpointConnection`）**：手动审批连接显式设置 `bps = 100` 时，首次 Apply 可以成功；随后执行二次 plan，Provider 可能将云端回读值显示为 `10000`，并计划更新回配置值 `100`。该差异属于连接带宽的回读或单位一致性问题。明确带宽为硬性要求时，应核对云端实际带宽并审查每次 plan；不要求显式带宽时保持 `connection_bps = null`，使用云端默认值。
- PrivateZone 在首次 Apply 时创建，但连接接纳前业务不可访问。Zone 只绑定消费方 VPC；同名 Zone 应由单一 State 管理。
- Endpoint 安全组除业务端口外，还需允许 IPv4 入方向 ICMP 来源 `100.64.0.0/10`；IPv6 场景允许 ICMPv6 来源 `fd00:64::/32`。目标不健康时，域名可能返回 NXDOMAIN。
- 原生 DNS 当前仅支持 `public` 类型；先在公开权威 DNS 中添加 TXT 所有权记录，云端状态为 `Verified` 后再设置 `enable_native_private_dns = true`。验证请求为 write-only，需审查后续 plan。
- 如需撤销审批但保留 Endpoint，将 `approve_connection` 设回 `false` 并 Apply。连接断开后再重新审批。
- Destroy 删除 Module 管理的服务、Endpoint、审批以及本示例的 PrivateZone/CNAME；调用方已有 VPC、子网、后端和安全组继续保留。
