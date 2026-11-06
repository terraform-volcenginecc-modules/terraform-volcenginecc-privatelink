# basic

SaaS private access across two VPCs in the same account. A service provider publishes an Endpoint Service using an existing CLB, and the consumer creates an Interface Endpoint. The allowlist permits only the current account, and this minimal example enables automatic acceptance. Clients use the output Endpoint domain; complete demonstrates custom private DNS and manual approval.

In addition to business port rules, the caller must allow IPv4 ingress ICMP from `100.64.0.0/10` in the Endpoint security group (`port_start = -1`, `port_end = -1`); IPv6 requires ingress ICMPv6 from `fd00:64::/32`. Wait three minutes after initial connection before checking zone health and DNS. DNS excludes unhealthy zones and may return NXDOMAIN when all zones are unhealthy; Connected alone does not prove domain resolution works.

Prerequisites: an existing service VPC/CLB/listener/healthy backend, a consumer VPC/subnet/security group, and enabled PrivateLink with sufficient quotas. Callers maintain security group rules and backend access controls; no public entry point is created.

The public module source is `terraform-volcenginecc-modules/privatelink/volcenginecc`. This draft is unpublished, so the init below requires Registry publication. Static validation tests the current source in isolated copies; it does not prove Registry consumption.

Use Terraform 1.5.7 or OpenTofu 1.11.8. Supply all inputs from variables.tf in a local terraform.tfvars. Pass AK/SK unchanged through `VOLCENGINE_ACCESS_KEY` and `VOLCENGINE_SECRET_KEY`. Run these commands, replacing terraform with tofu for OpenTofu:

```bash
terraform init
terraform plan
terraform apply
terraform plan -detailed-exitcode
terraform destroy
```

The service and Endpoint must become available, with the connection Connected. The second Plan should exit 0. After Destroy, query the cloud to confirm both service and Endpoint are absent; external dependencies retain their original ownership.

On 2026-11-04, Terraform 1.5.7 and online Provider 0.0.73 tested the current local module in an isolated example copy. Apply, default/zone-domain resolution, HTTP by hostname, the second Plan (No changes), and standard Destroy passed; all temporary resources were removed. Registry module consumption remains unverified. OpenTofu validation is static only; no real cloud lifecycle was run with it. CLB is a documented backend type and cannot be replaced directly with an NLB ID. Same-account multi-zone access, manual approval, and private DNS are described in examples/complete.
