terraform {
  # You will need to have Terraform v0.14.4 or newer installed to use the features
  # used in this Terraform Module.
  required_version = ">= 0.14.4"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.41.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "1.2.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.0.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.0.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "3.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "1.13.3"
    }
  }
  #  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}
provider "azuread" {}
provider "random" {}
provider "local" {}
provider "null" {}
provider "time" {}
provider "tls" {}

locals {
  # These are hardcoded Variables for a Terraform Module. These are typically
  # used to reduce complexity from the Resoruces and keep it within a single
  # name.
  common_tags = map(
    "Company", "company"
  )
}

provider "helm" {
  debug = true

  kubernetes {
    config_path = "${path.module}/../tf-aks-agic/kube_admin_config.yaml"
  }
}

resource "helm_release" "coder_com" {
  name       = "coder"
  repository = "https://helm.coder.com"
  chart      = "coder"
  version    = var.coder_com_version
  namespace  = var.coder_com_namespace

  values = [
    file("${path.module}/helm_overrides/${terraform.workspace}/values.yaml")
  ]

  set {
    name  = "postrgresql.passwordSecret"
    value = var.coder_pgsql_admin_password
  }
}
