variable "region" {
  description = "服务与消费方的共同地域。"
  type        = string
}
variable "backend_type" {
  description = "服务方已有负载均衡类型，本示例限 CLB/ALB。"
  type        = string
  default     = "CLB"
  validation {
    condition     = contains(["CLB", "ALB"], var.backend_type)
    error_message = "此示例仅使用文档确认的 CLB/ALB 后端，不支持 NLB。"
  }
}
variable "backends" {
  description = "按可用区 ID 映射已有服务后端 ID；多区示例需要至少两区。"
  type        = map(string)
  validation {
    condition     = length(var.backends) >= 2
    error_message = "complete 示例需要至少两个可用区的后端。"
  }
}
variable "consumer_account_id" {
  description = "当前部署身份的数字账号 ID；服务与消费方使用同一账号，服务白名单只允许该账号。"
  type        = string
}
variable "consumer_vpc_id" {
  description = "当前账号已有消费方 VPC。"
  type        = string
}
variable "consumer_subnets" {
  description = "按可用区 ID 映射子网与显式 IPv4 地址；地址须属于对应子网，避免自动分配地址的回读漂移。"
  type        = map(object({ id = string, private_ip_address = string }))
  validation {
    condition     = length(var.consumer_subnets) >= 2
    error_message = "complete 示例需要至少两个可用区的子网。"
  }
}
variable "security_group_ids" {
  description = "当前账号已有消费方安全组；放通目标业务客户端和端口，并允许 100.64.0.0/10 入方向 ICMP 健康检查。"
  type        = set(string)
}
variable "approve_connection" {
  description = "服务方显式审批开关；先创建申请并核对身份，再设置 true 创建连接审批资源。"
  type        = bool
  default     = false
}
variable "connection_bps" {
  description = "审批连接带宽 Mbps，null 使用云端默认值。"
  type        = number
  default     = null
}
variable "payer" {
  description = "Endpoint 或 EndpointService；修改会替换服务。"
  type        = string
  default     = "Endpoint"
}
variable "service_project_name" {
  description = "当前账号内服务方项目名；修改会替换服务。"
  type        = string
  default     = "default"
}
variable "consumer_project_name" {
  description = "当前账号内消费方项目名；修改会替换 Endpoint。"
  type        = string
  default     = "default"
}
variable "service_description" {
  description = "可更新的服务描述。"
  type        = string
  default     = "SaaS private service with manual approval"
}
variable "tags" {
  description = "显式 key/value 标签集合。"
  type        = list(object({ key = string, value = string }))
  default     = [{ key = "scenario", value = "saas-private-access" }]
}
variable "dns_zone_name" {
  description = "当前账号内消费方专用私网 DNS Zone 域名；不要与现有或原生 DNS Zone 重复。"
  type        = string
}
variable "dns_record_host" {
  description = "CNAME 子域名前缀，禁止根域名和通配符。"
  type        = string
  default     = "api"
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]*$", var.dns_record_host))
    error_message = "使用字母或数字开头的非泛域名单级前缀；根域名不能使用 CNAME。"
  }
}
variable "dns_ttl" {
  description = "CNAME TTL 秒，采用 60–86400 范围。"
  type        = number
  default     = 300
  validation {
    condition     = var.dns_ttl >= 60 && var.dns_ttl <= 86400 && floor(var.dns_ttl) == var.dns_ttl
    error_message = "TTL 必须为 60–86400 的整数。"
  }
}
variable "native_private_dns" {
  description = "可选服务原生 DNS；public 域名需公开 TXT 所有权验证。默认使用消费方 PrivateZone CNAME。"
  type        = object({ name = string, type = optional(string, "public"), verify = optional(bool, false) })
  default     = null
}
variable "enable_native_private_dns" {
  description = "消费者是否启用服务原生私网 DNS；开启前服务域名须验证成功，且不能与本示例 Zone 冲突。"
  type        = bool
  default     = false
}
