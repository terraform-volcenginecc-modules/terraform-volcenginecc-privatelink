variable "region" {
  description = "服务与消费方的同一地域。"
  type        = string
}
variable "zone_id" {
  description = "后端 CLB 与消费方子网共同支持的可用区。"
  type        = string
}
variable "backend_id" {
  description = "已有服务方 CLB ID；其 VPC、监听器和健康后端由调用方准备。"
  type        = string
}
variable "account_id" {
  description = "当前账号 ID，作为显式服务白名单；此示例使用同一账号的两个 VPC。"
  type        = string
}
variable "consumer_vpc_id" {
  description = "已有消费方 VPC ID。"
  type        = string
}
variable "consumer_subnet_id" {
  description = "消费方子网 ID，必须位于 consumer_vpc_id 和 zone_id。"
  type        = string
}
variable "security_group_ids" {
  description = "已有消费方安全组，仅允许业务客户端访问目标端口。"
  type        = set(string)
}
