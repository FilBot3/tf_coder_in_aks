variable "coder_com_version" {
  # Get the list of available versions of the Helm Chart from the CHANGELOG from
  # Coder.com: @see https://coder.com/docs/changelog
  description = "The version of Coder.com Enterprise to install with Helm."
  type        = string
  default     = "1.15.2"
}

variable "coder_com_namespace" {
  description = "The namespace in Kubernetes to install the Helm chart."
  type        = string
  default     = "coder-poc"
}

variable "coder_pgsql_admin_password" {
  description = ""
  type        = string
  default     = ""
  sensitive   = true
}
