#!/usr/bin/env bash

az account set \
  --subscription=76623a17-984b-4133-b5a8-f67b80e55508
az aks get-credentials \
  --resource-group=Dudleyp-Coder-RG \
  --name=coder-poc \
  --overwrite-existing
