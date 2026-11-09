# BASIC PrivateLink Example

## 1. Overview

This example creates a minimal PrivateLink path between two VPCs in one account. The provider publishes an existing single-zone CLB through an Endpoint Service, and the consumer creates an Endpoint in an existing VPC and subnet. An account allowlist and automatic acceptance establish the connection. Supply the CLB, healthy backend, consumer network, and security group. Use complete for multiple zones, manual approval, and private DNS.

## 2. Usage

Create a local `terraform.tfvars` in `examples/basic` and provide every input listed in section 6. Supply credentials through a Provider-supported runtime configuration.

```shell
terraform init
terraform plan
terraform apply
terraform plan
terraform destroy
```

After Apply, confirm that the service and Endpoint are available, the connection is `Connected`, and the Endpoint output domain resolves and serves traffic from the consumer VPC. The second Plan checks idempotence. Review the deletion scope before Destroy. Existing CLBs, VPCs, subnets, security groups, and application backends are retained.

## 3. Requirements

| Name | Version |
|---|---|
| `terraform` | `>= 1.5.7, <= 1.11.8`; project baseline is `= 1.5.7` |
| `volcengine/volcenginecc` | `= 0.0.73` |

## 4. Providers

| Name | Source |
|---|---|
| `volcenginecc.service` | `volcengine/volcenginecc`; manages the Endpoint Service |
| `volcenginecc.consumer` | `volcengine/volcenginecc`; manages the consumer Endpoint |

Both aliases use the same region and account identity in this example.

## 5. Resources

| Name | Description |
|---|---|
| `module.privatelink` | Uses `terraform-volcenginecc-modules/privatelink/volcenginecc` to create an automatically accepted Endpoint Service and a single-zone Endpoint. |

This example declares no other Resources or Data Sources directly.

## 6. Inputs

| Name | Description |
|---|---|
| `region` | Region containing both service and consumer resources. |
| `zone_id` | Zone supported by both the backend CLB and consumer subnet. |
| `backend_id` | Existing service-side CLB ID. The caller maintains its listener and healthy backend. |
| `account_id` | Current numeric account ID, used as the only Endpoint Service account allowlist entry. |
| `consumer_vpc_id` | Existing consumer VPC ID. |
| `consumer_subnet_id` | Consumer subnet ID belonging to `consumer_vpc_id` and `zone_id`. |
| `security_group_ids` | Consumer security group IDs restricted to business clients, business ports, and PrivateLink health checks. |

All inputs are required and have no defaults.

## 7. Outputs

| Name | Description |
|---|---|
| `services` | Endpoint Service ID, name, domain, status, and native DNS configuration. |
| `endpoints` | Consumer Endpoint ID, domain, status, and connection status. |

## 8. Example

This directory contains the basic example for a single-account, single-zone, automatically accepted connection using the Endpoint domain directly. Use complete when manual approval, multiple zones, or a custom private domain is required.

## 9. Notes

- Supply credentials through a Provider-supported runtime or authentication configuration. Do not store them in source or variable files.
- Run `terraform plan` again after Apply. Idempotence requires the result to show no changes.
- In addition to business ports, allow IPv4 ingress ICMP from `100.64.0.0/10` in the Endpoint security group. For IPv6, allow ingress ICMPv6 from `fd00:64::/32`. Check DNS only after health stabilizes.
- The account allowlist permits the account to request a connection but does not grant IAM permissions. Callers maintain security group rules, backend authentication, and least-privilege access.
- This example supports a CLB backend. Do not substitute an NLB ID for `backend_id`.
- Destroy removes only the Endpoint and Endpoint Service managed by `module.privatelink`. Caller-owned dependencies remain.
