output "services" {
  description = "服务 ID、名称和原生 DNS TXT 验证信息。"
  value       = module.privatelink.services
}
output "endpoints" {
  description = "消费方 Endpoint ID、域名和连接状态。"
  value       = module.privatelink.endpoints
}
output "connections" {
  description = "服务方审批资源和连接状态。"
  value       = module.privatelink.connections
}
output "private_dns_name" {
  description = "消费 VPC 内使用的业务域名。"
  value       = "${var.dns_record_host}.${var.dns_zone_name}"
}
output "private_dns_zone_id" {
  description = "消费方私网 DNS Zone ID。"
  value       = volcenginecc_privatezone_private_zone.client.zid
}
