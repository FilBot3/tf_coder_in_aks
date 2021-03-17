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
  sensitive   = true
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

variable "coder_pgsql_admin" {
  description = "The PGSQL DB Admin user for Azure."
  type        = string
  default     = ""
}

variable "coder_pgsql_admin_password" {
  description = "The PGSQL DB Admin Password for Azure."
  type        = string
  default     = ""
  sensitive   = true
}

variable "aks_admin_group" {
  description = "The Azure AD Group used to administer AKS"
  type        = string
  default     = "akscsuatclusteradmin"
  sensitive   = false
}

variable "coder_rg_name" {
  description = "The Azure Resource Group name to hold Coder."
  type        = string
  default     = "Dudleyp-Coder-RG"
  sensitive   = false
}

variable "coder_rg_location" {
  description = "The Azure Resource Group location to hold Coder."
  type        = string
  default     = "centralus"
  sensitive   = false
}

