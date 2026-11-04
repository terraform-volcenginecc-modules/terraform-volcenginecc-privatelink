terraform {
  required_version = ">= 1.5.7, <= 1.11.8"

  required_providers {
    volcenginecc = {
      source  = "volcengine/volcenginecc"
      version = ">= 0.0.60, <= 0.0.73"
      configuration_aliases = [
        volcenginecc.service,
        volcenginecc.consumer,
      ]
    }
  }
}
