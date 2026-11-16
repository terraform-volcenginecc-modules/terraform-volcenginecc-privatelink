provider "volcenginecc" {
  region = var.region
}

module "privatelink" {
  source  = "terraform-volcenginecc-modules/privatelink/volcenginecc"
  version = "~> 1.0"
  providers = {
    volcenginecc.service  = volcenginecc
    volcenginecc.consumer = volcenginecc
  }

  services = {
    saas = {
      resource_type = var.backend_type
      resources = [
        for backend in sort(distinct(values(var.backends))) : {
          resource_id = backend
          zone_ids    = [for zone, id in var.backends : zone if id == backend]
        }
      ]
      permit_account_ids  = [var.consumer_account_id]
      auto_accept_enabled = false
      payer               = var.payer
      project_name        = var.service_project_name
      description         = var.service_description
      tags                = var.tags
      private_dns         = var.native_private_dns
    }
  }
  endpoints = {
    client = {
      service_key        = "saas"
      vpc_id             = var.consumer_vpc_id
      security_group_ids = var.security_group_ids
      zones = [
        for zone, subnet in var.consumer_subnets : {
          zone_id            = zone
          subnet_id          = subnet.id
          private_ip_address = subnet.private_ip_address
        }
      ]
      name                = "saas-private-client"
      project_name        = var.consumer_project_name
      private_dns_enabled = var.enable_native_private_dns
      tags                = var.tags
    }
  }
  # 第一次 apply 保持 false；核对申请账号及 Endpoint 后显式改为 true。
  connections = var.approve_connection ? {
    client = {
      service_key  = "saas"
      endpoint_key = "client"
      bps          = var.connection_bps
    }
  } : {}
}

# 在当前账号内创建 PrivateZone，仅绑定消费方 VPC。
resource "volcenginecc_privatezone_private_zone" "client" {
  zone_name      = var.dns_zone_name
  vpcs           = [{ vpc_id = var.consumer_vpc_id, region = var.region }]
  project_name   = var.consumer_project_name
  line_mode      = 0
  recursion_mode = false
  tags           = var.tags
}

resource "volcenginecc_privatezone_record" "service" {
  zid            = tonumber(volcenginecc_privatezone_private_zone.client.zid)
  host           = var.dns_record_host
  type           = "CNAME"
  value          = "${trimsuffix(module.privatelink.endpoints["client"].domain, ".")}."
  ttl            = var.dns_ttl
  line           = "default"
  enable         = true
  weight_enabled = false
}
