output "coder_aks_client_certificate" {
  value       = azurerm_kubernetes_cluster.coder.kube_config.0.client_certificate
  description = "The AKS k8s Cert used to access the cluster."
  sensitive   = true
}

output "coder_aks_kube_config" {
  value       = azurerm_kubernetes_cluster.coder.kube_config_raw
  description = "The configuraiton used with kubectl."
  sensitive   = true
}

output "coder_aks_control_plane_principal_id" {
  value       = azurerm_kubernetes_cluster.coder.identity[0].principal_id
  description = "The System Managed Identity for AKS Control Plane"
  sensitive   = false
}

output "coder_aks_kubelet_client_id" {
  value       = azurerm_kubernetes_cluster.coder.kubelet_identity[0].client_id
  description = "The System Managed Identity Client ID for AKS Kubelet Workers."
  sensitive   = false
}

output "coder_aks_kubelet_objeect_id" {
  value       = azurerm_kubernetes_cluster.coder.kubelet_identity[0].object_id
  description = "The System Managed Identity Object ID for AKS Kubelet Workers."
  sensitive   = false
}

output "coder_aks_kubelet_umi_id" {
  value       = azurerm_kubernetes_cluster.coder.kubelet_identity[0].user_assigned_identity_id
  description = "The System Managed Identity UMI ID for AKS Kubelet Workers."
  sensitive   = false
}
