#!/usr/bin/env bash

set -x
set -e

set -o errexit
set -o nounset
set -o pipefail


[[ ! -z "${SUBSCRIPTION_ID:-}" ]] || SUBSCRIPTION_ID=76623a17-984b-4133-b5a8-f67b80e55508
[[ ! -z "${RESOURCE_GROUP:-}" ]] || RESOURCE_GROUP=Dudleyp-Coder-RG
[[ ! -z "${CLUSTER_NAME:-}" ]] || CLUSTER_NAME=coder-poc


if ! az account set -s "${SUBSCRIPTION_ID}"; then
  echo "az login as a user and set the appropriate subscription ID"
  az login
  az account set -s "${SUBSCRIPTION_ID}"
fi

#
# Information Gathering
#

if [[ -z "${NODE_RESOURCE_GROUP:-}" ]]; then
  echo "Retrieving your node resource group"
  NODE_RESOURCE_GROUP="$(az aks show \
    --resource-group ${RESOURCE_GROUP} \
    --name ${CLUSTER_NAME} \
    --query nodeResourceGroup \
    --outpt tsv)"
fi

echo "Retrieving your cluster identity ID, which will be used for role assignment"
ID="$(az aks show \
  --resource-group ${RESOURCE_GROUP} \
  --name ${CLUSTER_NAME} \
  --query servicePrincipalProfile.clientId \
  --output tsv)"

echo "Checking if the aks cluster is using managed identity"
if [[ "${ID:-}" == "msi" ]]; then
  ID="$(az aks show \
    --resource-group ${RESOURCE_GROUP} \
    --name ${CLUSTER_NAME} \
    --query identityProfile.kubeletidentity.clientId \
    --output tsv)"
fi

#
# Role Assignments
#

echo "Assigning 'Managed Identity Operator' role to ${ID}"
az role assignment create \
  --role "Managed Identity Operator" \
  --assignee "${ID}" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}/resourcegroups/${NODE_RESOURCE_GROUP}"

echo "Assigning 'Virtual Machine Contributor' role to ${ID}"
az role assignment create \
  --role "Virtual Machine Contributor" \
  --assignee "${ID}" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}/resourcegroups/${NODE_RESOURCE_GROUP}"

# your resource group that is used to store your user-assigned identities
# assuming it is within the same subscription as your AKS node resource group
if [[ -n "${IDENTITY_RESOURCE_GROUP:-}" ]]; then
  echo "Assigning 'Managed Identity Operator' role to ${ID} with ${IDENTITY_RESOURCE_GROUP} resource group scope"
  az role assignment create \
    --role "Managed Identity Operator" \
    --assignee "${ID}" \
    --scope "/subscriptions/${SUBSCRIPTION_ID}/resourcegroups/${IDENTITY_RESOURCE_GROUP}"
fi