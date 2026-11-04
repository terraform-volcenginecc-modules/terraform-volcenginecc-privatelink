provider "volcenginecc" {
  alias  = "service"
  region = var.region
}

provider "volcenginecc" {
  alias  = "consumer"
  region = var.region
}

module "privatelink" {
  source = "terraform-volcenginecc-modules/privatelink/volcenginecc"
  providers = {
    volcenginecc.service  = volcenginecc.service
    volcenginecc.consumer = volcenginecc.consumer
  }

  services = {
    saas = {
      resource_type       = "CLB"
      resources           = [{ resource_id = var.backend_id, zone_ids = [var.zone_id] }]
      permit_account_ids  = [var.account_id]
      auto_accept_enabled = true
      description         = "SaaS private access"
    }
  }
  endpoints = {
    client = {
      service_key        = "saas"
      vpc_id             = var.consumer_vpc_id
      security_group_ids = var.security_group_ids
      zones              = [{ zone_id = var.zone_id, subnet_id = var.consumer_subnet_id }]
      name               = "saas-client"
    }
  }
}
