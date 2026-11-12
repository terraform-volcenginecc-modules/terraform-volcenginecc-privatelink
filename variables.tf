variable "services" {
  description = "服务方 Endpoint Service，key 为稳定逻辑名称；VPC 和后端由调用方管理。"
  type = map(object({
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
  }))
  default = {}

  validation {
    condition = alltrue([
      for s in values(var.services) :
      contains(["CLB", "ALB", "RDSMySQL"], s.resource_type) &&
      length(s.resources) > 0 &&
      length(distinct([for r in s.resources : r.resource_id])) == length(s.resources) &&
      alltrue([for r in s.resources :
        length(trimspace(r.resource_id)) > 0 &&
        (s.resource_type == "RDSMySQL" || length(r.zone_ids) > 0) &&
        length(r.zone_ids) == length(distinct(r.zone_ids)) &&
        alltrue([for zone in r.zone_ids : length(trimspace(zone)) > 0])
      ])
    ])
    error_message = "resource_type 必须为 CLB、ALB 或 RDSMySQL，resources 不得为空，后端 ID 不得为空或重复，CLB/ALB 必须提供非空且不重复的可用区。NLB 尚无支持证据。"
  }
  validation {
    condition = alltrue([
      for s in values(var.services) :
      length(s.permit_account_ids) > 0 &&
      alltrue([for id in s.permit_account_ids : can(regex("^[0-9]+$", id))])
    ])
    error_message = "permit_account_ids 必须包含明确的数字账号 ID；禁止通配授权。"
  }
  validation {
    condition = alltrue([
      for s in values(var.services) :
      contains(["Endpoint", "EndpointService"], s.payer) &&
      contains(s.ip_address_versions, "ipv4") &&
      length(setsubtract(s.ip_address_versions, ["ipv4", "ipv6"])) == 0
    ])
    error_message = "payer 必须为 Endpoint 或 EndpointService；IP 协议必须包含 ipv4，且仅允许 ipv4/ipv6。"
  }
  validation {
    condition = alltrue([
      for s in values(var.services) :
      s.private_dns == null ? true : (
        s.private_dns.type == "public" &&
        try(length(s.private_dns.name) <= 253, false) &&
        can(regex("^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\\.)+[a-zA-Z]{2,63}$", s.private_dns.name))
      )
    ])
    error_message = "服务原生 DNS 仅提供文档确认的 public 类型，name 必须为非泛域名，每个标签长 1–63 且不得为空或以连字符开头/结尾，总长不超过 253；验证前须配置公开 TXT 所有权记录。"
  }
  validation {
    condition = alltrue([
      for s in values(var.services) :
      length(distinct([for t in s.tags : t.key])) == length(s.tags) &&
      alltrue([for t in s.tags : length(trimspace(t.key)) > 0])
    ])
    error_message = "服务标签 key 不得为空或重复，标签必须显式包含 key/value。"
  }
}

variable "endpoints" {
  description = "消费方 Endpoint；service_key 关联本模块服务，或单独提供外部 service_id/service_name，三选一。"
  type = map(object({
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
  }))
  default = {}

  validation {
    condition = alltrue([
      for e in values(var.endpoints) :
      length([for s in [e.service_key, e.service_id, e.service_name] : s if s != null]) == 1 &&
      alltrue([for s in [e.service_key, e.service_id, e.service_name] : s == null ? true : length(trimspace(s)) > 0])
    ])
    error_message = "每个 Endpoint 必须且只能设置 service_key、service_id、service_name 中的一项，且不得为空字符串。"
  }
  validation {
    condition = alltrue([
      for e in values(var.endpoints) :
      length(trimspace(e.vpc_id)) > 0 &&
      length(e.security_group_ids) >= 1 && length(e.security_group_ids) <= 5 &&
      alltrue([for id in e.security_group_ids : length(trimspace(id)) > 0]) &&
      length(e.zones) >= 1 && length(e.zones) <= 10 &&
      length(distinct([for z in e.zones : z.zone_id])) == length(e.zones) &&
      alltrue([for z in e.zones : length(trimspace(z.zone_id)) > 0 && length(trimspace(z.subnet_id)) > 0])
    ])
    error_message = "Endpoint 必须提供 VPC、1–5 个安全组和 1–10 个不重复的可用区，每区提供 subnet_id。"
  }
  validation {
    condition = alltrue([
      for e in values(var.endpoints) :
      contains(e.ip_address_versions, "ipv4") &&
      length(setsubtract(e.ip_address_versions, ["ipv4", "ipv6"])) == 0 &&
      alltrue([for z in e.zones :
        (z.private_ip_address == null ? true : can(cidrnetmask("${z.private_ip_address}/32"))) &&
        (z.private_ipv_6_address == null ? true : (
          contains(e.ip_address_versions, "ipv6") && can(cidrhost("${z.private_ipv_6_address}/128", 0)) && can(regex(":", z.private_ipv_6_address))
        ))
      ])
    ])
    error_message = "必须包含 ipv4；指定地址必须有效，IPv6 地址要求双栈。地址是否属于子网由云端校验。"
  }
  validation {
    condition = alltrue([
      for e in values(var.endpoints) :
      (e.name == null ? true : can(regex("^[\\p{L}\\p{N}][\\p{L}\\p{N}._-]{0,127}$", e.name))) &&
      length(distinct([for t in e.tags : t.key])) == length(e.tags) &&
      alltrue([for t in e.tags : length(trimspace(t.key)) > 0])
    ])
    error_message = "Endpoint name 长度为 1–128，起始为字母或数字，后续允许字母、数字、点、下划线及连字符；标签 key 不得为空或重复。"
  }
}

variable "connections" {
  description = "服务方显式批准的连接；仅管理本模块中处于手动审批模式的服务与 Endpoint。移除 key 表示撤销该连接，须云端确认语义。"
  type = map(object({
    service_key  = string
    endpoint_key = string
    bps          = optional(number)
    resources_allocate = optional(list(object({
      resource_id = string
      zone_id     = string
    })))
  }))
  default = {}

  validation {
    condition = alltrue([
      for c in values(var.connections) :
      c.bps == null ? true : c.bps >= 100 && c.bps <= 20000 && floor(c.bps) == c.bps
    ])
    error_message = "连接带宽 bps 必须为 100–20000 Mbps 的整数。"
  }
  validation {
    condition     = length(distinct([for c in values(var.connections) : c.endpoint_key])) == length(var.connections)
    error_message = "同一 Endpoint 的连接只能有一个 Terraform 所有者。"
  }
  validation {
    condition = alltrue([
      for c in values(var.connections) :
      c.resources_allocate == null ? true : (
        length(c.resources_allocate) > 0 &&
        length(distinct([for r in c.resources_allocate : r.zone_id])) == length(c.resources_allocate) &&
        alltrue([for r in c.resources_allocate : length(trimspace(r.resource_id)) > 0 && length(trimspace(r.zone_id)) > 0])
      )
    ])
    error_message = "显式资源分配必须非空，提供 resource_id/zone_id，且每区唯一；此字段为 write-only，有二次 Plan 风险。"
  }
}
