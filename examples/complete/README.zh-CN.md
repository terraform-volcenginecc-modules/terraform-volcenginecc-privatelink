# complete

服务提供方与消费方使用同一账号下的两个 VPC。服务提供方运行多可用区 CLB/ALB 和健康后端，创建 Endpoint Service，仅授权当前账号，并关闭自动接纳。消费方在自己的 VPC 内创建多可用区 Endpoint。服务提供方核对请求后，通过显式审批开关接纳连接。同一账号内创建 PrivateZone，仅绑定消费 VPC，以 CNAME 将业务域名指向 Endpoint 域名。

这覆盖同账号内的 SaaS 私网接入、跨 VPC 服务访问和平台能力开放。2026-11-04 补齐所需 Endpoint ICMP 健康规则后，同账号两 VPC 的两可用区、手动审批、DNS 和清理复测通过。只保留 basic 与 complete 两个目录；参考 AWS VPC Endpoints 和阿里云 PrivateLink 的场景组织，不借用其字段。

将 variables.tf 中必填输入写入本地 terraform.tfvars。`backends` 和 `consumer_subnets` 使用可用区 ID 作 key，至少两区；后端必须覆盖消费方可用区。消费子网提供空闲且属于该子网的显式 IPv4 地址。

单个 Provider 配置使用当前部署身份管理服务、Endpoint、审批和 DNS 资源。通过 `VOLCENGINE_ACCESS_KEY`、`VOLCENGINE_SECRET_KEY` 原样传入 AK/SK，不作解码。`consumer_account_id` 填写该身份的账号 ID，后端、VPC、子网与安全组均须属于该账号。账号白名单允许建立连接请求；管理这些资源所需的 IAM 权限由调用方维护。

公开 module source 为 `terraform-volcenginecc-modules/privatelink/volcenginecc`，当前 draft 尚未发布；init 需要 Registry 发布。静态脚本仅在隔离副本中改为当前源码，不证明 Registry 消费成功。OpenTofu 1.11.8 仅做静态验证，未执行真实云生命周期；使用时可将 terraform 命令替换为 tofu。后续真实云操作应具有对应部署授权：

1. 用 Terraform 1.5.7 执行 init/plan，保持 `approve_connection = false`，apply 后检查 Endpoint 申请及 PendingAcceptance 状态。DNS 此时已建立，但业务尚不能连通。
2. 服务方核对消费账号、VPC、Endpoint ID 和所申请服务，设置 `approve_connection = true`，再次 plan/apply，检查 Connected、业务端口连通及 VPC 内 DNS 解析。
3. 二次 plan 必须 No changes。修改 service_description、tags、connection_bps 或 dns_ttl 验证更新，再确认 No changes。
4. 将 approve_connection 设回 false，验证审批资源删除及连接撤销语义；删除动作可能拒绝/断开连接，并不删除 Endpoint。再次接纳是否允许须云端验证。
5. destroy 后检查 State 为空，并分别查询确认 Endpoint Service、Endpoint、审批关系、PrivateZone 和记录均已移除。外部 VPC、后端与安全组不在本示例清理范围内。

2026-11-04 使用 Terraform 1.5.7/线上 Provider 0.0.73 在隔离示例副本中验证本地模块：初始 Apply、手动审批、两区健康、默认/可用区域名及 CNAME 解析、域名 HTTP、二次 Plan No changes、标准 Destroy 均通过。CNAME 在消费 VPC 内返回两个指定 Endpoint IP，在服务 VPC 内返回预期 NXDOMAIN。独立观察连接先 Rejected、Endpoint 删除后服务才删除。所有临时资源已清理。Registry Module 消费仍未验证。步骤 3 的完整更新矩阵、步骤 4 的单独撤销再接纳以及原生 TXT 分支未验证。

默认使用消费方 PrivateZone CNAME，Zone 只对绑定消费 VPC 生效。若已有同名 Zone，请通过其他组合维护 DNS，避免两个 State 重复拥有同一域名。

调用方须在 Endpoint 安全组放通健康检查：IPv4 入方向 ICMP 来源 `100.64.0.0/10`（`port_start = -1`、`port_end = -1`），或 IPv6 入方向 ICMPv6 来源 `fd00:64::/32`，同时保留业务端口规则。首次接纳后三分钟再判断健康。即使 CNAME 已存在、连接已 Connected，目标不健康仍可能返回 NXDOMAIN；应从消费 VPC 核验每个可用区的 ServiceStatus 和 DNS。

服务原生 DNS 作为可选路径：配置 native_private_dns.name（当前仅 public 类型），先在公开权威 DNS 添加 services 输出的 TXT 验证记录，再开启 verify；云端确认 Verified 后才开启 enable_native_private_dns。验证是 write-only 请求，二次 Plan 存在回读风险。不要与本例 CNAME Zone 使用冲突的域名；私有类型与泛域名尚未实现。

访问策略由显式服务账号白名单、消费方安全组以及后端监听器/鉴权共同构成。Provider Schema 未提供 AWS 风格 Endpoint Policy；本例不创建安全组规则或 IAM 策略。NLB 后端未获目标版本文档支持，使用 NLB 是硬要求时需先补齐 Provider 能力证据。
