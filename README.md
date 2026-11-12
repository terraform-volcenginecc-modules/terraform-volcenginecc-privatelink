# terraform-volcenginecc-privatelink

Publishes Volcengine PrivateLink services, creates consumer Endpoints, and manages explicit connection approvals.

## 1. Overview

This module publishes existing CLB, ALB, or RDS MySQL backends through an Endpoint Service, creates Interface Endpoints in consumer VPCs, and optionally lets the service owner approve connections. Account allowlists, Endpoint security groups, and optional private DNS restrict access. Callers manage VPCs, subnets, backends, listeners, security group rules, and IAM permissions.

```text
Current account: service VPC                  Current account: consumer VPC
Healthy backend → CLB/ALB → Endpoint Service ← private connection ← Endpoint ← client
                           allowlist + manual approval                ↑
                                                              PrivateZone CNAME
```

## 2. Usage

Prepare the service backend, consumer VPC/subnets/security groups, PrivateLink access, and quotas before calling the module. The following configuration uses one account for both roles. For cross-account use, configure and pass separate Provider aliases.

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

Inject credentials through Provider-supported environment variables or caller authentication settings; do not store them in the module. Before running `examples/basic` or `examples/complete`, supply the inputs declared in that directory's `variables.tf`, then run `terraform init`, `terraform plan`, and `terraform apply` from that directory.

## 3. Examples

- basic: Uses an existing single-zone CLB and consumer VPC/subnet/security group to create an automatically accepted Endpoint Service and Endpoint. Clients access the service through the Endpoint output domain.
- complete: Adds multi-zone backends and Endpoint zones, an explicit approval switch, tags, and project settings. The example root also creates a PrivateZone bound only to the consumer VPC and a CNAME. Keep `approve_connection = false` on the first apply, verify the request, then set it to `true`.

## 4. Requirements

| Name | Version |
|---|---|
| `terraform` | `>= 1.5.7, <= 1.11.8`; project baseline is `= 1.5.7` |
| `volcengine/volcenginecc` | `>= 0.0.60, <= 0.0.73`; examples pin `= 0.0.73` |

## 5. Providers

| Name | Source |
|---|---|
| `volcenginecc.service` | `volcengine/volcenginecc`; manages Endpoint Services and connection approvals |
| `volcenginecc.consumer` | `volcengine/volcenginecc`; manages consumer Endpoints |

The account allowlist permits a specified account to request a connection; it does not grant IAM permissions or replace manual approval. Configure the appropriate region, identity, and least-privilege permissions for both aliases.

## 6. Resources

| Mode | Type | Name |
|---|---|---|
| Create | Resource | [`volcenginecc_privatelink_endpoint_service.this`](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/privatelink_endpoint_service) |
| Create | Resource | [`volcenginecc_privatelink_vpc_endpoint.this`](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/privatelink_vpc_endpoint) |
| Create | Resource | [`volcenginecc_privatelink_vpc_endpoint_connection.this`](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/privatelink_vpc_endpoint_connection) |

The root module does not create VPCs, subnets, load balancers, security group rules, or DNS Zones. The `volcenginecc_privatezone_private_zone` and `volcenginecc_privatezone_record` resources in complete belong to the example root.

## 7. Inputs

| Name | Type | Default | Required in create mode | Description |
|---|---|---|---|---|
| `services` | `map(object(...))` | `{}` | No | Endpoint Service collection. Each item requires a backend type, backend resources, and an explicit numeric account allowlist. |
| `endpoints` | `map(object(...))` | `{}` | No | Endpoint collection. Each item provides the consumer network and selects exactly one of `service_key`, `service_id`, or `service_name`. |
| `connections` | `map(object(...))` | `{}` | No | Explicit approval collection. It can reference only matching module-managed services and Endpoints with automatic acceptance disabled. |

Complete `services` item shape:

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

`resource_type` supports `CLB`, `ALB`, and `RDSMySQL`. `resources` must be nonempty and unique; CLB/ALB backends require nonempty, unique zones. `permit_account_ids` accepts explicit numeric account IDs only. `payer` is `Endpoint` or `EndpointService`. IP versions must contain `ipv4` and may include `ipv6`. Native DNS currently supports only non-wildcard `public` names; publish the TXT ownership record in public authoritative DNS before verification.

Complete `endpoints` item shape:

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

Each Endpoint requires a VPC, 1–5 security groups, and 1–10 unique zones. Exactly one of `service_key`, `service_id`, and `service_name` must be set. An explicit IPv6 address requires dual stack; the cloud validates whether explicit addresses belong to their subnets. With `service_key`, the referenced service must support the Endpoint protocols and zones. Native private DNS requires the service to configure `private_dns`.

Complete `connections` item shape:

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

When set, `bps` must be an integer from 100 through 20000. One connection key may own each Endpoint. When set, `resources_allocate` must contain valid, unique zones that match both the service backends and Endpoint zones. This field is write-only, so inspect the second plan carefully.

## 8. Outputs

| Name | Type | Description |
|---|---|---|
| `services` | `map(object)` | Maps logical keys to service `id`, `name`, `domain`, `status`, and `private_dns_name_configuration`. |
| `endpoints` | `map(object)` | Maps logical keys to Endpoint `id`, `domain`, `private_dns_name`, `status`, and `connection_status`. |
| `connections` | `map(object)` | Maps logical keys to approval resource `id`, connection `status`, and read-only `zones`. |

Outputs contain no credentials. An output is an empty map when its corresponding input collection is empty.

## 9. Notes

- Each service, Endpoint, and connection relationship must have one Terraform owner. Do not configure `connections` for automatically accepted services. Import connections accepted outside Terraform before managing them here.
- Changes to a service's `payer`, `project_name`, or `resource_type`; an Endpoint's `vpc_id`, `project_name`, or service reference; and a connection's service, Endpoint, or resource allocation may replace resources and interrupt access. Use `moved` blocks when only renaming logical keys.
- Import IDs: use `service_id` for services, `endpoint_id` for Endpoints, and `service_id|endpoint_id` for connections. Existing VPCs and backends are referenced by ID and are not imported into this module.
- Restrict Endpoint security groups to required client sources and business ports. Allow health checks from `100.64.0.0/10` with ingress ICMP for IPv4, or from `fd00:64::/32` with ingress ICMPv6 for IPv6. Wait for health to stabilize before checking Endpoint DNS.
- `resources_allocate` and DNS verification requests contain write-only fields that may produce Provider readback differences. Provider `0.0.73` may also read connection bandwidth differently from its configured value. After apply, run a normal `terraform plan` and inspect idempotence; do not hide approval, allowlist, or security group differences with `ignore_changes`.
- Native DNS exposes only the Provider-confirmed `public` type. Private native DNS types, wildcard names, and external authoritative DNS records are outside this module. NLB backends are not currently supported.
- During destroy, Terraform references remove connection approvals and records that depend on Endpoint domains before deleting Endpoints and Endpoint Services. VPCs, subnets, backends, security groups, and DNS resources outside the complete example remain with their owners.
