output "services" {
  description = "服务 ID、名称及域名。"
  value       = module.privatelink.services
}
output "endpoints" {
  description = "消费方 Endpoint ID、域名及连接状态。"
  value       = module.privatelink.endpoints
}
