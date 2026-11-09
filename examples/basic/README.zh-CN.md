# basic

同账号跨 VPC 的 SaaS 私网接入：服务提供方通过已有 CLB 发布 Endpoint Service，消费方创建 Interface Endpoint。账号白名单仅允许当前账号，此最小示例开启自动接纳。业务通过输出的 Endpoint 域名访问；自定义私网 DNS 和手动审批见 complete。

前置依赖：已部署的服务方 VPC/CLB/监听器/健康后端、消费方 VPC/子网、安全组，以及 PrivateLink 开通和配额。安全组规则及后端访问控制由调用方维护；不创建公网入口。

除业务端口规则外，调用方须在 Endpoint 安全组放通 IPv4 入方向 ICMP 来源 `100.64.0.0/10`（`port_start = -1`、`port_end = -1`）；IPv6 须放通入方向 ICMPv6 来源 `fd00:64::/32`。首次连接建立后三分钟再检查可用区健康与 DNS。DNS 排除不健康可用区，所有可用区不健康时可能返回 NXDOMAIN，Connected 本身不能证明域名解析成功。

module source 为 `terraform-volcenginecc-modules/privatelink/volcenginecc`。

使用 Terraform 1.5.7 或 OpenTofu 1.11.8，将 variables.tf 中所有输入填写到本地 terraform.tfvars，AK/SK 原样通过 `VOLCENGINE_ACCESS_KEY`、`VOLCENGINE_SECRET_KEY` 提供。然后执行（OpenTofu 将 terraform 替换为 tofu）：

```bash
terraform init
terraform plan
terraform apply
terraform plan -detailed-exitcode
terraform destroy
```

服务和 Endpoint 的状态必须在云端达到可用且连接为 Connected；二次 Plan 预期退出码为 0。销毁后查询确认服务和 Endpoint 均不存在，外部依赖继续由原所有者管理。

CLB 是当前文档确认的后端类型，不能直接替换为 NLB ID。同账号多可用区、手动审批及私网 DNS 场景见 examples/complete。
