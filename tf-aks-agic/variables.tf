variable "company_tags" {
  description = "Tags used by company for resource identification in Azure."
  type        = map(any)
  default = {
    Environment = "Development"
    CostCenter  = "N/A"
    ServiceTeir = "N/A"
    Owner       = "anybody"
    Application = "anything"
  }
}

variable "phil_pub_ip" {
  description = "Phillip Dudley (dudleyp) <Phillip.Dudley@company.com>"
  type        = string
  default     = ""
}

variable "aad_pod_identity_rbac_version" {
  description = "The version of AAD Pod Identity for RBAC to use."
  type        = string
  default     = "v1.7.4"
}

variable "kube_deploy" {
  description = "Use Terraform to deploy basic app?"
  type        = bool
  default     = false
}
