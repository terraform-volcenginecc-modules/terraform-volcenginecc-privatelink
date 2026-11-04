resource "volcenginecc_privatelink_endpoint_service" "this" {
  provider = volcenginecc.service
  for_each = var.services

  service_type          = "Interface"
  service_resource_type = each.value.resource_type
  resources             = each.value.resources
  permit_account_ids    = each.value.permit_account_ids
  auto_accept_enabled   = each.value.auto_accept_enabled
  description           = each.value.description
  project_name          = each.value.project_name
  payer                 = each.value.payer
  ip_address_versions   = each.value.ip_address_versions
  tags                  = length(each.value.tags) == 0 ? null : each.value.tags
  private_dns_enabled   = each.value.private_dns != null
  private_dns_name      = try(each.value.private_dns.name, null)
  private_dns_type      = try(each.value.private_dns.type, null)
  # 仅在请求验证时发送 write-only 字段，避免默认写入 false。
  enable_verify_private_dns = try(each.value.private_dns.verify, false) ? true : null
}

resource "volcenginecc_privatelink_vpc_endpoint" "this" {
  provider = volcenginecc.consumer
  for_each = var.endpoints

  vpc_id              = each.value.vpc_id
  security_group_ids  = each.value.security_group_ids
  zones               = each.value.zones
  service_id          = each.value.service_key == null ? each.value.service_id : try(volcenginecc_privatelink_endpoint_service.this[each.value.service_key].service_id, null)
  service_name        = each.value.service_name
  endpoint_name       = each.value.name
  description         = each.value.description
  project_name        = each.value.project_name
  private_dns_enabled = each.value.private_dns_enabled
  # API 文档要求仅 IPv4 时不发送此字段。
  ip_address_versions = contains(each.value.ip_address_versions, "ipv6") ? each.value.ip_address_versions : null
  tags                = length(each.value.tags) == 0 ? null : each.value.tags

  lifecycle {
    precondition {
      condition     = each.value.service_key == null ? true : contains(keys(var.services), each.value.service_key)
      error_message = "Endpoint 的 service_key 必须引用 services 中存在的 key。"
    }
    precondition {
      condition = each.value.service_key == null ? true : try(
        length(setsubtract(each.value.ip_address_versions, var.services[each.value.service_key].ip_address_versions)) == 0 &&
        (!each.value.private_dns_enabled || var.services[each.value.service_key].private_dns != null),
        false
      )
      error_message = "Endpoint 协议必须由服务支持；原生私网 DNS 需要服务配置 private_dns。"
    }
    precondition {
      condition = each.value.service_key == null ? true : try(
        var.services[each.value.service_key].resource_type == "RDSMySQL" ||
        alltrue([for z in each.value.zones : contains(flatten([for r in var.services[each.value.service_key].resources : r.zone_ids]), z.zone_id)]),
        false
      )
      error_message = "Endpoint 可用区必须由服务方后端提供。RDSMySQL 的区域支持须另行云端确认。"
    }
  }
}

resource "volcenginecc_privatelink_vpc_endpoint_connection" "this" {
  provider = volcenginecc.service
  for_each = var.connections

  service_id         = try(volcenginecc_privatelink_endpoint_service.this[each.value.service_key].service_id, null)
  endpoint_id        = try(volcenginecc_privatelink_vpc_endpoint.this[each.value.endpoint_key].endpoint_id, null)
  bps                = each.value.bps
  resources_allocate = each.value.resources_allocate

  lifecycle {
    precondition {
      condition = try(
        var.endpoints[each.value.endpoint_key].service_key == each.value.service_key &&
        !var.services[each.value.service_key].auto_accept_enabled,
        false
      )
      error_message = "审批必须引用存在且匹配的服务和 Endpoint，并且服务必须禁用 auto_accept_enabled。"
    }
    precondition {
      condition = each.value.resources_allocate == null ? true : try(
        alltrue([for a in each.value.resources_allocate :
          contains([for z in var.endpoints[each.value.endpoint_key].zones : z.zone_id], a.zone_id) &&
          anytrue([for r in var.services[each.value.service_key].resources : r.resource_id == a.resource_id && contains(r.zone_ids, a.zone_id)])
        ]),
        false
      )
      error_message = "连接分配必须匹配 Endpoint 可用区及该服务已登记的后端资源。"
    }
  }
}
