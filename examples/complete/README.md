# COMPLETE PrivateLink Example

Module source: `terraform-volcenginecc-modules/privatelink/volcenginecc`; module version: `version = "~> 1.0"` (>= 1.0.0, < 2.0.0). Provider version requirements are separate. Registry installation requires a published module release in this range.

## 1. Overview

This example builds multi-zone PrivateLink access between service and consumer VPCs in one account. Existing CLB/ALB backends are published through an Endpoint Service, the consumer creates a multi-zone Endpoint, and the service owner approves the connection in stages. The example root also creates a PrivateZone and CNAME bound only to the consumer VPC. Supply backends, VPCs, subnets, security groups, and unused private IPs. basic omits manual approval and custom private DNS.

## 2. Usage

Create a local `terraform.tfvars` in `examples/complete` and provide the required inputs listed in section 6. Keep `approve_connection = false` for the first deployment:

```shell
terraform init
terraform plan
terraform apply
terraform plan
terraform apply
terraform plan
terraform destroy
```

After the first Apply, verify the consumer account, VPC, Endpoint ID, and `PendingAcceptance` status. Then set `approve_connection` to `true` and use the second Plan and Apply to create the approval resource. After the connection is `Connected` and all zones are healthy, check the Endpoint domain, PrivateZone name, and business port from the consumer VPC. The final Plan checks idempotence. Review the deletion scope before Destroy.

## 3. Requirements

| Name | Version |
|---|---|
| `terraform` | `>= 1.5.7, <= 1.11.8`; project baseline is `= 1.5.7` |
| `volcengine/volcenginecc` | `= 0.0.73` |

## 4. Providers

| Name | Source |
|---|---|
| `volcenginecc` | `volcengine/volcenginecc`; passed to the module's `service` and `consumer` aliases and used for PrivateZone resources |

This example uses one account identity for service, consumer, approval, and DNS resources.

## 5. Resources

| Name | Description |
|---|---|
| `module.privatelink` | Uses `terraform-volcenginecc-modules/privatelink/volcenginecc` to create the Endpoint Service, multi-zone Endpoint, and optional approval resource. |
| `volcenginecc_privatezone_private_zone.client` | Creates a PrivateZone bound only to the consumer VPC. |
| `volcenginecc_privatezone_record.service` | Creates a CNAME from the business name to the Endpoint output domain. |

## 6. Inputs

| Name | Description |
|---|---|
| `region` | Region for the service, consumer, and PrivateZone resources. No default. |
| `backend_type` | Backend type, `CLB` or `ALB`. Defaults to `CLB`. |
| `backends` | Map of zone ID to backend ID with at least two zones. No default. |
| `consumer_account_id` | Numeric deployment account ID used as the only account allowlist entry. No default. |
| `consumer_vpc_id` | Existing consumer VPC ID. No default. |
| `consumer_subnets` | Map of zone ID to `{ id, private_ip_address }` with at least two zones. Each IP must be unused and belong to its subnet. No default. |
| `security_group_ids` | Consumer security group IDs allowing business clients, business ports, and health checks. No default. |
| `approve_connection` | Whether to create explicit connection approval. Defaults to `false`; set to `true` after reviewing the request. |
| `connection_bps` | Approved connection bandwidth in Mbps. Defaults to `null`, which uses the cloud default. |
| `payer` | Payer, `Endpoint` or `EndpointService`. Defaults to `Endpoint`. |
| `service_project_name` | Project containing the Endpoint Service. Defaults to `default`. |
| `consumer_project_name` | Project containing the Endpoint and PrivateZone. Defaults to `default`. |
| `service_description` | Endpoint Service description. Defaults to `SaaS private service with manual approval`. |
| `tags` | Key/value tags used by the service, Endpoint, and PrivateZone. Defaults to `scenario=saas-private-access`. |
| `dns_zone_name` | Dedicated consumer PrivateZone name. It must not conflict with an existing Zone or native DNS name. No default. |
| `dns_record_host` | Single-label CNAME host. Defaults to `api`. |
| `dns_ttl` | CNAME TTL from 60 through 86400 seconds. Defaults to `300`. |
| `native_private_dns` | Optional native DNS object `{ name, type, verify }`. Defaults to `null`; only `public` is supported. |
| `enable_native_private_dns` | Enables verified native private DNS on the Endpoint. Defaults to `false`. |

## 7. Outputs

| Name | Description |
|---|---|
| `services` | Endpoint Service ID, name, domain, status, and native DNS verification information. |
| `endpoints` | Consumer Endpoint ID, domain, status, and connection status. |
| `connections` | Approval resource ID, status, and zone information when `approve_connection = true`; otherwise an empty map. |
| `private_dns_name` | Fully qualified business name used inside the consumer VPC. |
| `private_dns_zone_id` | ID of the PrivateZone created by this example. |

## 8. Example

This directory contains the complete example for same-account, multi-zone access with manual approval and a custom consumer private domain. Compared with basic, it adds connection approval, PrivateZone/CNAME resources, projects, tags, and optional native DNS.

## 9. Notes

- Supply credentials through a Provider-supported runtime or authentication configuration. Do not store them in source or variable files.
- Run `terraform plan` again after Apply. Except for the known issue below, idempotence requires the result to show no changes.
- **Known issue (`Volcengine::PrivateLink::VpcEndpointConnection`)**: When a manually approved connection explicitly sets `bps = 100`, the first Apply can succeed, but the second plan may show a cloud readback value of `10000` and propose updating it to the configured value `100`. This is a connection-bandwidth readback or unit-consistency issue. If explicit bandwidth is required, verify the effective cloud value and review every plan. Otherwise, keep `connection_bps = null` to use the cloud default.
- The first Apply creates the PrivateZone, but traffic remains unavailable until the connection is accepted. The Zone is bound only to the consumer VPC; one State should own any same-name Zone.
- In addition to business ports, allow IPv4 ingress ICMP from `100.64.0.0/10` in the Endpoint security group. For IPv6, allow ICMPv6 from `fd00:64::/32`. DNS may return NXDOMAIN while targets are unhealthy.
- Native DNS currently supports only `public`. Add the TXT ownership record to public authoritative DNS and wait for `Verified` before setting `enable_native_private_dns = true`. The verification request is write-only, so review subsequent plans.
- To revoke approval while retaining the Endpoint, set `approve_connection` back to `false` and Apply. Reapprove only after the connection is disconnected.
- Destroy removes the module-managed service, Endpoint, approval, and this example's PrivateZone/CNAME. Caller-owned VPCs, subnets, backends, and security groups remain.
