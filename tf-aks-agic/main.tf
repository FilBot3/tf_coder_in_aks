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

data "http" "tf_controller_ip" {
  # This URL gets teh IP of the host calling it.
  # Using this will allow us to whitelist the Agent making the calls.
  url = "https://ifconfig.me"
}

data "azurerm_client_config" "current" {
  # Grab the azurerm_client_config that we're using to connect. This provides
  # some information about our connection.
}

data "azurerm_subscription" "current" {
  # Grab data about the subscription we're deploying into.
  # This allows you to whitelist this session.
}

data "azuread_group" "aks_admin_group" {
  # This is the Azure Active Directory Group that will be allowed to manage the
  # AKS Clsuter.
  display_name = "akscsuatclusteradmin"
}

resource "azurerm_resource_group" "coder" {
  # Azure Resource Manager Resource Group to house all of the Azure Resources
  # we create with Terraform.
  name     = "Dudleyp-Coder-RG"
  location = "centralus"

  tags = merge(local.common_tags, var.company_tags)
}

resource "azurerm_virtual_network" "coder_k8s" {
  # Used to separate our deployment from the public internet. This is like an
  # AWS VPC.
  name                = "Dudleyp-Coder-POC-VNET"
  resource_group_name = azurerm_resource_group.coder.name
  location            = azurerm_resource_group.coder.location
  address_space       = ["10.0.0.0/8"]

  tags = merge(local.common_tags, var.company_tags)
}

resource "azurerm_subnet" "coder_pods" {
  # Used for the Pods to run Coder. To access, anotehr Subnet will need to be
  # created with an Azure Application Gateway and a Public IP.
  name                 = "Dudleyp-Coder-POC-Subnet"
  resource_group_name  = azurerm_resource_group.coder.name
  virtual_network_name = azurerm_virtual_network.coder_k8s.name
  address_prefixes     = ["10.240.0.0/16"]

  enforce_private_link_endpoint_network_policies = true
  enforce_private_link_service_network_policies  = true

  service_endpoints = [
    "Microsoft.Sql"
  ]

  depends_on = [
    azurerm_virtual_network.coder_k8s
  ]
}

resource "azurerm_subnet" "coder_appgw" {
  # Used to hold the Application Gateway and its scaled up replicas if needed.
  name                 = "Dudleyp-Coder-POC-Appgw-Subnet"
  resource_group_name  = azurerm_resource_group.coder.name
  virtual_network_name = azurerm_virtual_network.coder_k8s.name
  address_prefixes     = ["10.241.0.0/16"]

  depends_on = [
    azurerm_virtual_network.coder_k8s
  ]
}

resource "azurerm_network_security_group" "coder" {
  # This Network Security Group whitelists some IPs, allows the Cert Manager
  # for Cert Bot which uses LetsEncrypt to update TLS Certs. Then the Gateway
  # Manager should allow the Application Gateway to communicate with the AKS
  # Cluster backend.
  name                = "coder-poc-nsg"
  location            = azurerm_resource_group.coder.location
  resource_group_name = azurerm_resource_group.coder.name

  security_rule {
    name              = "Whitelisted_IPs"
    priority          = 100
    direction         = "Inbound"
    access            = "Allow"
    protocol          = "Tcp"
    source_port_range = "*"
    source_address_prefixes = [
      "192.81.9.0/24",
      "4.7.69.64/26",
      "67.52.251.128/26",
      "67.52.251.64/26",
      var.phil_pub_ip
    ]
    destination_port_ranges    = [80, 443]
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Cert_Manager_Solver"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_ranges    = [80]
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Gateway_Manager"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "GatewayManager"
    destination_port_range     = "65200-65535"
    destination_address_prefix = "*"
  }

  tags = merge(local.common_tags, var.company_tags)
}

resource "azurerm_subnet_network_security_group_association" "coder_appgw" {
  # This associates the Network Security Group with the Subnet that it's
  # applied to.
  subnet_id                 = azurerm_subnet.coder_appgw.id
  network_security_group_id = azurerm_network_security_group.coder.id
}

resource "azurerm_postgresql_server" "coder" {
  name                = "coder-pgsql-server-01"
  location            = azurerm_resource_group.coder.location
  resource_group_name = azurerm_resource_group.coder.name

  sku_name = "GP_Gen5_4"

  storage_mb                   = 5120
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = true

  administrator_login          = var.coder_pgsql_admin
  administrator_login_password = var.coder_pgsql_admin_password
  version                      = "11"
  ssl_enforcement_enabled      = false # This will need to reviewed.
}

data "azurerm_postgresql_server" "coder" {
  name                = azurerm_postgresql_server.coder.name
  resource_group_name = azurerm_resource_group.coder.name
}

resource "azurerm_postgresql_database" "coder" {
  name                = "coder"
  resource_group_name = azurerm_resource_group.coder.name
  server_name         = azurerm_postgresql_server.coder.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}

resource "azurerm_private_endpoint" "coder_pgsql" {
  name                = "coder-poc-pgsql-endpoint"
  location            = azurerm_resource_group.coder.location
  resource_group_name = azurerm_resource_group.coder.name
  subnet_id           = azurerm_subnet.coder_pods.id

  private_service_connection {
    name                           = "coder-poc-pgsql-endpoint-private-service-connection"
    private_connection_resource_id = azurerm_postgresql_server.coder.id
    subresource_names              = ["postgresqlServer"]
    is_manual_connection           = false
  }
}

resource "azurerm_postgresql_virtual_network_rule" "coder" {
  name                                 = "coder-postgresql-vnet-rule"
  resource_group_name                  = azurerm_resource_group.coder.name
  server_name                          = azurerm_postgresql_server.coder.name
  subnet_id                            = azurerm_subnet.coder_pods.id
  ignore_missing_vnet_service_endpoint = false

  depends_on = [
    azurerm_private_endpoint.coder_pgsql
  ]
}

resource "random_id" "coder_log_analytics_wksp" {
  # Used to make our Log Analytics Workspace unique per deployment. This should
  # not cause a new resource to build each time we run this if we have our
  # state available.
  keepers = {
    group_name = azurerm_resource_group.coder.name
  }

  byte_length = 8
}

resource "azurerm_log_analytics_workspace" "coder" {
  # Used to store Log Analytics. Mostly going to contain Container logs.
  name                = "coder-law-poc-${random_id.coder_log_analytics_wksp.hex}"
  location            = azurerm_resource_group.coder.location
  resource_group_name = azurerm_resource_group.coder.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = merge(local.common_tags, var.company_tags)
}

resource "azurerm_log_analytics_solution" "coder" {
  # Pull in all the logs from the containers that are deployed.
  # Feeds into the Log Analytics Workspace.
  solution_name         = "ContainerInsights"
  location              = azurerm_resource_group.coder.location
  resource_group_name   = azurerm_resource_group.coder.name
  workspace_resource_id = azurerm_log_analytics_workspace.coder.id
  workspace_name        = azurerm_log_analytics_workspace.coder.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }

  depends_on = [
    azurerm_log_analytics_workspace.coder
  ]

  tags = merge(local.common_tags, var.company_tags)
}

resource "azurerm_container_registry" "coder" {
  # Azure Container Registery to hold any pulled containers or custom containers
  # generated for use with Coder.
  name                     = "coderpocacr"
  resource_group_name      = azurerm_resource_group.coder.name
  location                 = azurerm_resource_group.coder.location
  sku                      = "Premium"
  admin_enabled            = false
  georeplication_locations = ["South Central US"]

  tags = merge(local.common_tags, var.company_tags)
}

resource "azurerm_storage_account" "coder" {
  # This storage account is used to store persistent data for the Coder applicaiton.
  # However this may change a bit. Depends on what we're doing.
  name                      = "coderpocstorage"
  resource_group_name       = azurerm_resource_group.coder.name
  location                  = azurerm_resource_group.coder.location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  enable_https_traffic_only = true
  min_tls_version           = "TLS1_2"

  # There is also a way to limit what networks can access the storage account.
  # I need to play with those after I get the storage account built and see
  # how it behaves. Need to figure out how the default deny rule works.

  tags = merge(local.common_tags, var.company_tags)
}

resource "azurerm_storage_container" "coder_persistent" {
  name                  = "persistentdata"
  storage_account_name  = azurerm_storage_account.coder.name
  container_access_type = "private"
  metadata = {
    application = "Coder.com"
    owner       = "DevOps_Engineering"
    type        = "Peristent Data"
  }
}

resource "azurerm_key_vault" "coder" {
  name                       = "coderpockv"
  resource_group_name        = azurerm_resource_group.coder.name
  location                   = azurerm_resource_group.coder.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_enabled        = true
  soft_delete_retention_days = 7
  sku_name                   = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    certificate_permissions = [
      "Get",
      "List",
      "Update",
      "Create",
      "Import",
      "Delete",
      "Recover",
      "Backup",
      "Restore",
      "ManageContacts",
      "ManageIssuers",
      "GetIssuers",
      "ListIssuers",
      "SetIssuers",
      "DeleteIssuers",
      "Purge"
    ]

    key_permissions = [
      "Backup",
      "Create",
      "Decrypt",
      "Delete",
      "Encrypt",
      "Get",
      "Import",
      "List",
      "Purge",
      "Recover",
      "Restore",
      "Sign",
      "UnwrapKey",
      "Update",
      "Verify",
      "WrapKey"
    ]

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Recover",
      "Backup",
      "Restore",
      "Purge"
    ]
  }

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules = [
      "${chomp(data.http.tf_controller_ip.body)}/32"
    ]
  }

  tags = merge(local.common_tags, var.company_tags)
}

resource "tls_private_key" "coder" {
  # This generates an RSA Key Pair that will be used for SSH into the servers
  # if troubleshooting is needed. These will then be stored in Azure key Vault
  # for later access.
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_key_vault_secret" "coder_ssh_user" {
  # This will store the SSH Username when you need to access the kubelet workers
  name         = "aks-ssh-username"
  value        = "coderadm"
  key_vault_id = azurerm_key_vault.coder.id
  content_type = "SSH Username"

  tags = merge(local.common_tags, var.company_tags)
}

resource "azurerm_key_vault_secret" "coder_private_key" {
  # This will store the SSH Private key for the kubelet worker.
  name         = "aks-ssh-private-key"
  value        = tls_private_key.coder.private_key_pem
  key_vault_id = azurerm_key_vault.coder.id
  content_type = "SSH Private Key"

  tags = merge(local.common_tags, var.company_tags)
}

resource "azurerm_key_vault_secret" "coder_public_key" {
  # This will store the SSH Public Key for the kubelet worker.
  name         = "aks-ssh-public-key"
  value        = tls_private_key.coder.public_key_openssh
  key_vault_id = azurerm_key_vault.coder.id
  content_type = "SSH Public Key"

  tags = merge(local.common_tags, var.company_tags)
}

resource "azurerm_public_ip" "coder" {
  # This is the Public IP Address that will be used by Azure Application Gateway
  # so that external traffic can hit it and a DNS label be applied to the IP.
  name                = "coder-poc-public-ip"
  resource_group_name = azurerm_resource_group.coder.name
  location            = azurerm_resource_group.coder.location
  domain_name_label   = "coder-poc-public"
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = merge(local.common_tags, var.company_tags)
}

resource "azurerm_web_application_firewall_policy" "coder" {
  # This is what is considered the WAF. This will be applied inside of the Azure
  # Application Gateway to perform firewall functions. Here we'll apply the OWASP
  # rule set. Google OWASP for more information.
  name                = "Coder-POC-WAF-Policy"
  resource_group_name = azurerm_resource_group.coder.name
  location            = azurerm_resource_group.coder.location

  policy_settings {
    enabled                     = true
    mode                        = "Prevention"
    request_body_check          = true
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.1"
    }
  }
}

resource "azurerm_application_gateway" "coder" {
  # The Azure Application Gateway is used to perform Ingress Controller functions
  # that normally a Nginx Server would perform. The benefit is that the AppGW
  # is managed by Azure and can perform Layer 7 Firewall actions called, a
  # Web Application Firewall, or WAF.
  # The AKS instance will perform modifications to this AppGW when Pods are
  # applied to the AKS cluster. Then the routes will be built and TLS will be
  # setup.
  name                = "Coder-POC-AppGW"
  resource_group_name = azurerm_resource_group.coder.name
  location            = azurerm_resource_group.coder.location

  enable_http2 = true

  sku {
    # This forces us to use a WAF policy. We defined one earlier.
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }

  firewall_policy_id = azurerm_web_application_firewall_policy.coder.id

  gateway_ip_configuration {
    # This hooks the Application Gateway into the Subnet we defined for it.
    # Also gives the value a name within the AppGW.
    name      = "coder-poc-appgw-ip-conf"
    subnet_id = azurerm_subnet.coder_appgw.id
  }

  frontend_port {
    # Here we define and name a frontend port to refernce later in the AppGW
    # definition.
    name = "coder-poc-fep-80"
    port = 80
  }

  frontend_port {
    name = "coder-poc-fep-443"
    port = 443
  }

  frontend_ip_configuration {
    # This creates a named association of the Public IP from earlier and something
    # we can recall in the AppGW.
    name                 = "coder-poc-fe-ip-conf"
    public_ip_address_id = azurerm_public_ip.coder.id
  }

  backend_address_pool {
    # We're creating a blank address pool for now. This will be populated by AKS
    # when we create Kube Deployments and provide the proper annotations so that
    # AKS can tell what the AppGW to do.
    name = "coder-poc-be-pool"
  }

  backend_http_settings {
    # This defines how we will communicate with the Pods on the backend from the
    # Application Gateway. Port 80 is fine for now, but will need to be changed
    # to be 443 and more TLS Certificates uploaded.
    name                  = "coder-poc-be-http-settings"
    cookie_based_affinity = "Enabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 1
  }

  http_listener {
    # This is the Listener as it is called in the Azure Portal.
    # This is used to listen to a certain port with the Azure Application
    # Gateway. This uses values from earlier definitions in the resource.
    # These are simply just names to call out.
    # Since they're not resources, we can't use the resource reference.
    name                           = "coder-poc-80-listener"
    frontend_ip_configuration_name = "coder-poc-fe-ip-conf"
    frontend_port_name             = "coder-poc-fep-80"
    protocol                       = "Http"
  }

  request_routing_rule {
    # This is the Routing Rule as it is called in the Azure Portal.
    # This directs traffic from the listener to the backend pool.
    name                       = "coder-poc-route-rule-80"
    rule_type                  = "Basic"
    http_listener_name         = "coder-poc-80-listener"
    backend_address_pool_name  = "coder-poc-be-pool"
    backend_http_settings_name = "coder-poc-be-http-settings"
  }

  tags = merge(local.common_tags, var.company_tags)

  #  lifecycle {
  #    ignore_changes = [
  #      backend_address_pool,
  #      backend_http_settings,
  #      frontend_port,
  #      http_listener,
  #      probe,
  #      redirect_configuration,
  #      request_routing_rule,
  #      ssl_certificate,
  #      url_path_map,
  #      tags
  #    ]
  #  }

  depends_on = [
    azurerm_subnet.coder_appgw,
    azurerm_public_ip.coder
  ]
}

resource "azurerm_kubernetes_cluster" "coder" {
  # Azure Kubernetes Serivce. This will be the main work horse for the Coder
  # applicaiton. This will use a VMSS to scale the workers up and down.
  name                = "coder-poc"
  resource_group_name = azurerm_resource_group.coder.name
  location            = azurerm_resource_group.coder.location
  dns_prefix          = "dudleyp"
  kubernetes_version  = "1.19.7"

  # node_resource_group = azurerm_resource_group.coder.name

  default_node_pool {
    name                = "default"
    node_count          = 2
    vm_size             = "Standard_D2_v2"
    enable_auto_scaling = true
    min_count           = 2
    max_count           = 5
    type                = "VirtualMachineScaleSets"
    vnet_subnet_id      = azurerm_subnet.coder_pods.id
    tags                = merge(local.common_tags, var.company_tags)
  }

  identity {
    type = "SystemAssigned"
  }

  role_based_access_control {
    enabled = true
    azure_active_directory {
      managed                = true
      admin_group_object_ids = [data.azuread_group.aks_admin_group.id]
    }
  }

  linux_profile {
    # This username and ssh_key are used to access the kubelet worker nodes.
    admin_username = "coderadm"
    ssh_key {
      key_data = tls_private_key.coder.public_key_openssh
    }
  }

  network_profile {
    # The network profile must be set when attempting to use AGIC.
    network_plugin     = "azure"
    docker_bridge_cidr = "172.17.0.1/16"
    dns_service_ip     = "10.2.0.10"
    service_cidr       = "10.2.0.0/16"
  }

  addon_profile {
    http_application_routing {
      enabled = false
    }
    azure_policy {
      enabled = false
    }
    kube_dashboard {
      enabled = false
    }
    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = azurerm_log_analytics_workspace.coder.id
    }
  }

  depends_on = [
    azurerm_subnet.coder_pods,
    azurerm_log_analytics_workspace.coder
  ]

  tags = merge(local.common_tags, var.company_tags)

  #  lifecycle {
  #    ignore_changes = [
  #      default_node_pool.node_count
  #    ]
  #  }
}

resource "local_file" "kube_config" {
  # Save the AKS kube config that can be used to administer the cluster.
  filename        = "${path.module}/kube_admin_config.yaml"
  content         = azurerm_kubernetes_cluster.coder.kube_admin_config_raw
  file_permission = "0600"
}

resource "null_resource" "wait_for_aks_appgw" {
  depends_on = [
    azurerm_application_gateway.coder,
    azurerm_kubernetes_cluster.coder,
    local_file.kube_config,
    azurerm_postgresql_database.coder
  ]
}
data "azurerm_resource_group" "aks-nodes" {
  name = azurerm_kubernetes_cluster.coder.node_resource_group
}

resource "azurerm_role_assignment" "connect_aks_to_acr" {
  # This role assignment allows AKS Kubelet nodes to access the ACR to pull
  # images when it deploys a new Container Image.
  scope                = azurerm_container_registry.coder.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.coder.kubelet_identity[0].object_id

  depends_on = [
    null_resource.wait_for_aks_appgw
  ]
}

resource "azurerm_role_assignment" "aks_pods_to_subnet" {
  # Assign the AKS Kubelet Identity the Network Contributor Role so that the
  # Worker nodes can assign IP's to the Pods.
  scope                = azurerm_subnet.coder_pods.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.coder.kubelet_identity[0].object_id
  #principal_id         = azurerm_user_assigned_identity.coder.principal_id

  depends_on = [
    null_resource.wait_for_aks_appgw
  ]
}

resource "azurerm_role_assignment" "aks_to_appgw_as_contrib" {
  scope                = azurerm_application_gateway.coder.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_kubernetes_cluster.coder.kubelet_identity[0].object_id
  #principal_id         = azurerm_kubernetes_cluster.coder.identity[0].principal_id

  depends_on = [
    null_resource.wait_for_aks_appgw
  ]
}

resource "azurerm_role_assignment" "aks_to_mc_nodes_rg_as_mio" {
  scope                = data.azurerm_resource_group.aks-nodes.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_kubernetes_cluster.coder.kubelet_identity[0].object_id

  depends_on = [
    null_resource.wait_for_aks_appgw
  ]
}

resource "azurerm_role_assignment" "aks_to_mc_nodes_rg_as_vmc" {
  scope                = data.azurerm_resource_group.aks-nodes.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_kubernetes_cluster.coder.kubelet_identity[0].object_id

  depends_on = [
    null_resource.wait_for_aks_appgw
  ]
}

resource "azurerm_role_assignment" "aks_to_cp_rg_as_mio" {
  scope                = azurerm_resource_group.coder.id
  role_definition_name = "Reader"
  principal_id         = azurerm_kubernetes_cluster.coder.kubelet_identity[0].object_id

  depends_on = [
    null_resource.wait_for_aks_appgw
  ]
}


resource "null_resource" "wait_for_roles" {
  depends_on = [
    azurerm_role_assignment.connect_aks_to_acr,
    azurerm_role_assignment.aks_pods_to_subnet,
    azurerm_role_assignment.aks_to_appgw_as_contrib,
    azurerm_role_assignment.aks_to_mc_nodes_rg_as_mio,
    azurerm_role_assignment.aks_to_mc_nodes_rg_as_vmc,
    azurerm_role_assignment.aks_to_cp_rg_as_mio
  ]
}

resource "azurerm_storage_blob" "coder_aks_config" {
  # Save the AKS God Config to the Azure Storage Account we created.
  # This may be moved later or put into a key vault.
  name                   = "coder_aks_admin_kubeconfig.yaml"
  storage_account_name   = azurerm_storage_account.coder.name
  storage_container_name = azurerm_storage_container.coder_persistent.name
  type                   = "Block"
  source                 = "kube_admin_config.yaml"
  metadata = {
    description = "This is the God Config for the AKS cluster. Will bypass the RBAC."
  }

  depends_on = [
    null_resource.wait_for_aks_appgw
  ]
}

provider "kubernetes" {
  # The Kubernetes provider is used to interact with our Kubernetes environment.
  # Ideally, this would be it's own TF Module, but for this, it's all in one
  # file.
  load_config_file = false

  host = length(
    azurerm_kubernetes_cluster.coder.role_based_access_control[0].azure_active_directory
  ) > 0 ? azurerm_kubernetes_cluster.coder.kube_admin_config.0.host : azurerm_kubernetes_cluster.coder.kube_config.0.host
  username = length(
    azurerm_kubernetes_cluster.coder.role_based_access_control[0].azure_active_directory
  ) > 0 ? azurerm_kubernetes_cluster.coder.kube_admin_config.0.username : azurerm_kubernetes_cluster.coder.kube_config.0.username
  password = length(
    azurerm_kubernetes_cluster.coder.role_based_access_control[0].azure_active_directory
  ) > 0 ? azurerm_kubernetes_cluster.coder.kube_admin_config.0.password : azurerm_kubernetes_cluster.coder.kube_config.0.password

  client_certificate = length(
    azurerm_kubernetes_cluster.coder.role_based_access_control[0].azure_active_directory
    ) > 0 ? base64decode(
    azurerm_kubernetes_cluster.coder.kube_admin_config.0.client_certificate
    ) : base64decode(
    azurerm_kubernetes_cluster.coder.kube_config.0.client_certificate
  )
  client_key = length(
    azurerm_kubernetes_cluster.coder.role_based_access_control[0].azure_active_directory
    ) > 0 ? base64decode(
    azurerm_kubernetes_cluster.coder.kube_admin_config.0.client_key
    ) : base64decode(
    azurerm_kubernetes_cluster.coder.kube_config.0.client_key
  )
  cluster_ca_certificate = length(
    azurerm_kubernetes_cluster.coder.role_based_access_control[0].azure_active_directory
    ) > 0 ? base64decode(
    azurerm_kubernetes_cluster.coder.kube_admin_config.0.cluster_ca_certificate
    ) : base64decode(
    azurerm_kubernetes_cluster.coder.kube_config.0.cluster_ca_certificate
  )
}

resource "kubernetes_namespace" "coder" {
  # We'll create a namespace within our AKS cluster to deploy our containers to.
  metadata {
    name = "coder-poc"

    annotations = {
      name = "coder"
    }

    labels = {
      owner = "DevOps_Engineering"
    }
  }

  depends_on = [
    null_resource.wait_for_roles
  ]
}

resource "kubernetes_secret" "coder" {
  metadata {
    name      = "coder-pgsql-user-pass"
    namespace = "coder-poc"
  }

  data = {
    username = "${var.coder_pgsql_admin}@${data.azurerm_postgresql_server.coder.fqdn}"
    password = var.coder_pgsql_admin_password
  }

  type = "kubernetes.io/basic-auth"

  depends_on = [
    kubernetes_namespace.coder
  ]
}

resource "null_resource" "aad_pod_identity_rbac" {
  # This Null Resource executes on the Terraform Control Node kubectl. This means
  # that the node running Terraform will need to have kubectl installed. It
  # should also have Helm as well.
  #
  # The provisioner executes kubectl to apply some Azure specific Pod Identity
  # configurations for the Pods to be able to authenticate against AAD.
  provisioner "local-exec" {
    command = "kubectl apply --kubeconfig=./kube_admin_config.yaml --filename=https://raw.githubusercontent.com/Azure/aad-pod-identity/${var.aad_pod_identity_rbac_version}/deploy/infra/deployment-rbac.yaml --wait=true"
  }

  depends_on = [
    kubernetes_namespace.coder
  ]
}

resource "null_resource" "mic_exception" {
  # This Null Resource executes on the Terraform Control Node kubectl. This means
  # that the node running Terraform will need to have kubectl installed. It
  # should also have Helm as well.
  #
  # This provides some sort of exception for MIC.
  provisioner "local-exec" {
    command = "kubectl apply --kubeconfig=./kube_admin_config.yaml --filename=https://raw.githubusercontent.com/Azure/aad-pod-identity/${var.aad_pod_identity_rbac_version}/deploy/infra/mic-exception.yaml --wait=true"
  }

  depends_on = [
    null_resource.aad_pod_identity_rbac
  ]
}

resource "time_sleep" "wait_30_sec" {
  create_duration = "30s"

  depends_on = [
    null_resource.mic_exception
  ]
}

provider "helm" {
  debug = true

  kubernetes {
    host = length(
      azurerm_kubernetes_cluster.coder.role_based_access_control[0].azure_active_directory
    ) > 0 ? azurerm_kubernetes_cluster.coder.kube_admin_config.0.host : azurerm_kubernetes_cluster.coder.kube_config.0.host
    username = length(
      azurerm_kubernetes_cluster.coder.role_based_access_control[0].azure_active_directory
    ) > 0 ? azurerm_kubernetes_cluster.coder.kube_admin_config.0.username : azurerm_kubernetes_cluster.coder.kube_config.0.username
    password = length(
      azurerm_kubernetes_cluster.coder.role_based_access_control[0].azure_active_directory
    ) > 0 ? azurerm_kubernetes_cluster.coder.kube_admin_config.0.password : azurerm_kubernetes_cluster.coder.kube_config.0.password

    client_certificate = length(
      azurerm_kubernetes_cluster.coder.role_based_access_control[0].azure_active_directory
      ) > 0 ? base64decode(
      azurerm_kubernetes_cluster.coder.kube_admin_config.0.client_certificate
      ) : base64decode(
      azurerm_kubernetes_cluster.coder.kube_config.0.client_certificate
    )
    client_key = length(
      azurerm_kubernetes_cluster.coder.role_based_access_control[0].azure_active_directory
      ) > 0 ? base64decode(
      azurerm_kubernetes_cluster.coder.kube_admin_config.0.client_key
      ) : base64decode(
      azurerm_kubernetes_cluster.coder.kube_config.0.client_key
    )
    cluster_ca_certificate = length(
      azurerm_kubernetes_cluster.coder.role_based_access_control[0].azure_active_directory
      ) > 0 ? base64decode(
      azurerm_kubernetes_cluster.coder.kube_admin_config.0.cluster_ca_certificate
      ) : base64decode(
      azurerm_kubernetes_cluster.coder.kube_config.0.cluster_ca_certificate
    )
  }
}

resource "helm_release" "azure_ingress" {
  # This sets up and consumes a Helm repository then applies a Helm Chart. This
  # will require that the Terraform Control Node have Helm installed on it.
  # Preferably the latest version of Helm as Helm v1 is depricated, v2 is a
  # security concern.
  name       = "azure-ingress"
  repository = "https://appgwingress.blob.core.windows.net/ingress-azure-helm-package/"
  chart      = "ingress-azure"
  version    = "1.3.0"
  namespace  = "coder-poc"
  wait       = true
  timeout    = 300

  set {
    name  = "appgw.name"
    value = "Coder-POC-AppGW"
  }

  set {
    name  = "appgw.resourceGroup"
    value = azurerm_resource_group.coder.name
  }

  set {
    name  = "appgw.subscriptionId"
    value = data.azurerm_subscription.current.subscription_id
  }

  set {
    name  = "appgw.shared"
    value = "false"
  }

  set {
    name  = "armAuth.type"
    value = "aadPodIdentity"
  }

  set {
    name  = "armAuth.identityResourceID"
    value = azurerm_kubernetes_cluster.coder.kubelet_identity[0].user_assigned_identity_id
  }

  set {
    name  = "armAuth.identityClientID"
    value = azurerm_kubernetes_cluster.coder.kubelet_identity[0].client_id
  }

  set {
    name  = "rbac.enabled"
    value = "true"
  }

  depends_on = [
    time_sleep.wait_30_sec
  ]
}
