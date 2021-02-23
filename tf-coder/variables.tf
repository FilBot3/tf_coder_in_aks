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

variable "coder_pgsql_user" {
  description = "The user for PGSQL."
  type        = string
  default     = ""
  sensitive   = true
}
variable "coder_pgsql_user_password" {
  description = "The user password for PGSQL."
  type        = string
  default     = ""
  sensitive   = true
}

variable "coder_pgsql_host" {
  description = "The PGSQL Host that Coder will need to sync data."
  type        = string
  default     = ""
  sensitive   = false
}

variable "coder_pgsql_database" {
  description = "The PGSQL database that Coder will need to sync data."
  type        = string
  default     = ""
  sensitive   = false
}

variable "coder_ingress_type" {
  description = "Which type of Ingress is Coder Enterprise using?"
  type        = string
  default     = "nginx"
  # This can have two values, either nginx or agic. Using nginx will use the
  # default Ingress Controller that Coder expects. Using agic will tell Coder
  # Enterprise we're using an Application Gateway Ingress Controller.
}
