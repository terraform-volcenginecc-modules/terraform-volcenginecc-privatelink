output "services" {
  description = "按稳定逻辑 key 输出服务 ID、名称、域名和 DNS 所有权验证信息。"
  value = {
    for key, service in volcenginecc_privatelink_endpoint_service.this : key => {
      id                             = service.service_id
      name                           = service.service_name
      domain                         = service.service_domain
      status                         = service.status
      private_dns_name_configuration = service.private_dns_name_configuration
    }
  }
}

locals {
  approved_endpoint_statuses = {
    for key, connection in var.connections :
    connection.endpoint_key => volcenginecc_privatelink_vpc_endpoint_connection.this[key].connection_status
  }
}

output "endpoints" {
  description = "按稳定逻辑 key 输出 Endpoint ID、域名和连接状态，供 DNS 和下游组合。"
  value = {
    for key, endpoint in volcenginecc_privatelink_vpc_endpoint.this : key => {
      id                = endpoint.endpoint_id
      domain            = endpoint.endpoint_domain
      private_dns_name  = endpoint.private_dns_name
      status            = endpoint.status
      connection_status = contains(keys(local.approved_endpoint_statuses), key) ? local.approved_endpoint_statuses[key] : endpoint.connection_status
    }
  }
}

output "connections" {
  description = "服务方审批连接 ID、状态及可用区信息。"
  value = {
    for key, connection in volcenginecc_privatelink_vpc_endpoint_connection.this : key => {
      id     = connection.id
      status = connection.connection_status
      zones  = connection.zones
    }
  }
}
