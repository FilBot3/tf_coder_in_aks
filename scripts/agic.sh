#!/usr/binenv bash

set -x
set -e

function terraform_create() {
  terraform fmt -recursive
  terraform -chdir=tf-aks-agic init
  terraform -chdir=tf-aks-agic validate
  terraform -chdir=tf-aks-agic plan -out=tf_plan.tfplan
  terraform -chdir=tf-aks-agic apply tf_plan.tfplan
}

function terraform_destroy() {
  terraform fmt -recursive
  terraform -chdir=tf-aks-agic init
  terraform -chdir=tf-aks-agic validate
  terraform -chdir=tf-aks-agic plan -out=tf_plan.tfplan -destroy
  terraform -chdir=tf-aks-agic apply tf_plan.tfplan
}

case $1 in
  "create")
    terraform_create
    ;;
  "destroy")
    terraform_destroy
    ;;
  *)
    terraform_create
    ;;
esac
