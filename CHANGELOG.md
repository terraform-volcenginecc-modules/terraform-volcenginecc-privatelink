# Changelog

## Unreleased

- 初始化 PrivateLink draft 模块，按稳定 key 管理 Endpoint Service、消费方 Endpoint 和手动审批连接。
- 增加 basic 和 complete 示例，覆盖明确账号授权、多可用区、跨账号 Provider 与消费方私网 DNS。
- 完成 Terraform 1.5.7/OpenTofu 1.11.8 静态验证，以及 Terraform 1.5.7/Provider 0.0.73 同账号 basic/complete 真实生命周期验证。
- 补充 Endpoint 健康检查的安全组前置规则；域名解析、CNAME、业务访问、No changes 和标准清理验证通过。
- 说明 NLB/Endpoint Policy 能力边界、回读约束及尚未验证的扩展分支。
- 提供与 VPC 模块仓库一致的标准文件结构和双语文档。
