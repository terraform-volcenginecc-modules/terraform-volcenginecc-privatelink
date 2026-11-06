# terraform-volcenginecc-privatelink

A Terraform/OpenTofu module using the volcenginecc Provider to publish PrivateLink Endpoint Services, create consumer Endpoints, and manage explicit connection approvals.

## 1. Overview

Expose a provider's service privately to consumers for SaaS access, communication across VPCs, and platform service delivery. An Endpoint Service references existing backends; consumer Interface Endpoints run in their own VPCs. Account allowlists and connection acceptance control access.

On 2026-11-04, basic and complete passed same-account tests across two VPCs with Terraform 1.5.7 and Registry Provider 0.0.73: default/zone-domain resolution, the consumer CNAME, HTTP by hostname, a second Plan (No changes), and standard Destroy. All temporary resources were removed. Tests used isolated example copies pointing to the local module; Registry module consumption remains unverified. Cross-account access, native TXT-based DNS, and full IAM permission tests remain incomplete. The module does not manage VPCs, subnets, backends, listeners, security group rules, or IAM policies; callers maintain them. Provider documentation confirms CLB, ALB, and RDSMySQL backends. **NLB support is unconfirmed**; if NLB is required, verify Provider support first.

```text
Current account: service VPC                  Current account: consumer VPC
Healthy backend → CLB/ALB → Endpoint Service ← private connection ← Endpoint ← client
                           allowlist + manual approval                ↑
                                                              PrivateZone CNAME
```

## 2. Usage

Full configurations are in examples/basic and examples/complete. Supply the required inputs from their variables.tf files. The public address follows this module's name: `terraform-volcenginecc-modules/privatelink/volcenginecc`. The specification's `terraform-volcenginecc-modules/vpc/volcenginecc` address belongs to the VPC module and does not accept PrivateLink inputs. This draft has not been published, so Registry init is not yet guaranteed to succeed; no release version is claimed. Use this configuration after Registry publication and provide the existing dependencies first:

```hcl
provider "volcenginecc" {
  region = "cn-beijing"
}

module "privatelink" {
  source = "terraform-volcenginecc-modules/privatelink/volcenginecc"
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

Declare and assign `backend_id`, `zone_id`, `account_id`, `consumer_vpc_id`, and `consumer_subnet_id` as strings, and `security_group_ids` as list(string), in the caller's root configuration. Values must identify real, matching, authorized resources. Supply credentials through Provider environment variables.

Map both module aliases to the same configured Provider: `volcenginecc.service` manages services and approvals; `volcenginecc.consumer` manages Endpoints. Both examples use one account for the service and consumer VPCs. Configure the Provider, region, credentials, IAM permissions, and Terraform backend in the caller's root.

Resources use stable logical keys in `map(object(...))` inputs:

- `services`: backend type, resource_id/zone_ids, and explicit permit_account_ids; automatic acceptance is disabled by default.
- `endpoints`: consumer VPC, security groups, and zones/subnets; associate a module service with service_key or an external service with service_id/service_name. Exactly one selector is required.
- `connections`: explicit service_key/endpoint_key approvals for manually accepted services owned by this module; empty by default.

You may manage only services or connect only to existing services. The external service owner must confirm account permissions, zones, IP protocols, and native DNS prerequisites. The module does not query external Data Sources or poll status.

## 3. Examples

| Example | Scenario | Resources and boundaries |
|---|---|---|
| basic | Minimal SaaS private access across VPCs in one account | Endpoint Service, Endpoint, explicit account permission, automatic acceptance; uses the Endpoint output domain |
| complete | Same-account service and consumer VPCs, manual approval, private DNS | Multiple zones, one deployment identity, explicit approval switch, current-account allowlist, consumer PrivateZone/CNAME; optional native DNS |

The scenarios follow the requested AWS VPC Endpoints and Alibaba Cloud PrivateLink references. Their Endpoint Policy and NLB fields are not mapped to unsupported Volcengine fields. No confirmed specialized demo was found; only basic/complete example directories are provided.

## 4. Requirements

| Requirement | Version / prerequisite |
|---|---|
| Verified engines | **Terraform 1.5.7 and OpenTofu 1.11.8**; see the static validation instructions |
| required_version | >= 1.5.7, <= 1.11.8; accommodates both engine version numbers, without claiming every version in the range was tested |
| Minimum VolcengineCC version | 0.0.60 |
| Current pinned validation version | 0.0.73, downloaded from the published Registry |
| Module Provider constraint | >= 0.0.60, <= 0.0.73; broaden only after validating newer versions |
| External dependencies | Service VPC and healthy backends, consumer VPC/subnets/security groups, enabled PrivateLink and sufficient quotas |
| DNS | complete requires PrivateZone permissions; native public DNS requires public TXT ownership verification |

The repository follows the Terraformcc Module Repository specification and provides matching English and Simplified Chinese documentation.

## 5. Providers

| Provider alias | Source and version constraint | Ownership |
|---|---|---|
| volcenginecc.service | volcengine/volcenginecc >= 0.0.60, <= 0.0.73 | Endpoint Services and connection approvals permitted by the service account |
| volcenginecc.consumer | volcengine/volcenginecc >= 0.0.60, <= 0.0.73 | Endpoints; complete's PrivateZone and record are managed by the example root |

The account allowlist permits connection requests; it does not grant IAM role permissions or automatically accept requests. Consumer identity must match an allowed account. Security groups should restrict business sources and ports; the module supplies no unrestricted network default.

The caller must also allow PrivateLink health checks in the Endpoint security group: IPv4 ingress ICMP from `100.64.0.0/10` (`port_start = -1`, `port_end = -1`); for IPv6, ingress ICMPv6 from `fd00:64::/32`. The [official troubleshooting guide](https://www.volcengine.com/docs/6980/155955) recommends waiting three minutes after initial connection before assessing health. Endpoint DNS returns healthy zone addresses; a Connected Endpoint may return NXDOMAIN when every zone is unhealthy, even if direct IP traffic works. These rules are maintained by the caller; the module does not add them.

## 6. Resources

| Capability | Resource | Implementation |
|---|---|---|
| core | [volcenginecc_privatelink_endpoint_service](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/privatelink_endpoint_service) | services; Interface type, backend bindings, account allowlist, acceptance mode |
| core | [volcenginecc_privatelink_vpc_endpoint](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/privatelink_vpc_endpoint) | endpoints; VPC, security groups, zones, external/module service association |
| core | [volcenginecc_privatelink_vpc_endpoint_connection](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/privatelink_vpc_endpoint_connection) | connections; explicit provider approval and optional bandwidth |
| complete/recommended | [volcenginecc_privatezone_private_zone](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/privatezone_private_zone) | complete root; bound only to the consumer VPC |
| complete/recommended | [volcenginecc_privatezone_record](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/privatezone_record) | complete root; CNAME targets the Endpoint domain |
| complete/recommended | Native service private_dns fields | public type, TXT verification, consumer enablement; additional cloud validation required |
| deferred | NLB, AWS-style Endpoint Policy, shared cross-account DNS Zone | Unconfirmed support or outside current ownership; no fabricated implementation |

The target versions' `terraform providers schema -json` confirms that most fields of the first two resources are Optional+Computed; connection service_id/endpoint_id are Required; service names, Endpoint domains/statuses, and connection zones are Computed-only. Validation checks actual fields in both minimum and current versions. Additional lifecycle notes reference a local Provider checkout without a release Tag. Static Schema omits some replacement/write-only metadata, so final behavior requires cloud validation and version-specific source checks.

## 7. Inputs

| Input | Type | Default | Required content and principal constraints |
|---|---|---|---|
| services | map(object) | {} | resource_type, resources, permit_account_ids; nonempty allowlist without `*`; supports tags, payer, project, IP protocols, private_dns |
| endpoints | map(object) | {} | vpc_id, 1–5 security groups, 1–10 unique zones; exactly one service_key/id/name; IPv6 requires dual stack |
| connections | map(object) | {} | service_key, endpoint_key; service auto_accept must be disabled; integer bps 100–20000; one owner per Endpoint |

Exact object shapes, defaults, and checks are in variables.tf. resources defines resource_id/zone_ids, and tags defines key/value explicitly. zones defines four attributes; unspecified IPs use null. Service and Endpoint tags are configured separately. Resources sharing a Provider alias use one service account and one consumer account; instantiate the module separately for multiple consumer accounts.

## 8. Outputs

| Output | Content |
|---|---|
| services | Logical key → ID, name, domain, status, native DNS TXT verification information |
| endpoints | Logical key → ID, domain, native DNS name, status, connection status |
| connections | Logical key → approval resource ID, connection status, read-only zone details |

Outputs contain no credentials. Service and Endpoint IDs come from their respective business ID fields, without assuming they equal Terraform's internal id.

## 9. Notes

**Ownership and approval.** Each service, Endpoint, and connection has one Terraform owner. Do not combine automatic acceptance with module-managed approval; import connections already accepted through the console. In complete, start with approve_connection=false, verify the request account, then enable it. With explicit approval, endpoints.connection_status is read from the approval resource. The 2026-11-04 standard Destroy observed Rejected after revocation and deletion of the service after the Endpoint. Removing only a connections key and accepting again have not been tested separately; revocation is not Endpoint deletion.

**Replacement.** Local Provider metadata marks service payer, project_name, service_resource_type, and service_type as create-only; Endpoint vpc_id, project_name, service_id/service_name are create-only; connection service_id, endpoint_id, and resource allocations are create-only. Changes may replace resources and interrupt traffic. Renaming logical keys changes addresses; use Terraform moved blocks for pure renames instead of delete/create. ID/domain references order DNS records, approvals, Endpoints, and services during destruction. No create_before_destroy bypasses uniqueness constraints.

**Import.** Use service_id for services, endpoint_id for Endpoints, and `service_id|endpoint_id` for connections. Quote full addresses containing map keys. Existing VPCs/backends are passed by ID and need not be imported into this module. Real import and subsequent drift checks have not been validated.

**Readback and second Plan.** Optional+Computed Set null/empty values, cleared tags, and allocated IPs may cause drift. basic allocates IPv4 in the cloud; complete supplies explicit IPv4. Connection resources_allocate is an optional write-only field omitted by default; native DNS verify is sent only when true and is also write-only. Do not hide allowlist, security group, or approval drift with ignore_changes. No changes must be proven after Apply.

**DNS.** complete creates a private Zone in the consumer account and manages the full vpcs binding set plus CNAME; it does not share a Zone across accounts. Native DNS exposes only the documented public type; public TXT verification precedes consumer enablement. Wildcards, private native DNS type, and external authoritative DNS record management are not implemented.

**Validation.** Terraform 1.5.7 and OpenTofu 1.11.8 passed static validation with Provider 0.0.60/0.0.73. For the module, run `terraform fmt -check -recursive`, `terraform init`, and `terraform validate`; use the corresponding `tofu` commands for OpenTofu. Before applying an example, supply its existing dependencies and run init/plan. The real basic/complete tests used Terraform 1.5.7 and Provider 0.0.73 with isolated example copies pointing to the local module. Both passed Apply, DNS/HTTP, a second Plan (No changes), and standard Destroy. Registry module consumption, OpenTofu cloud lifecycle, cross-account access, native TXT DNS, and the full update/import matrix remain unverified.

**License.** MIT; see LICENSE.
