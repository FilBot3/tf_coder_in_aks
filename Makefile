.PHONY: aks-agic-create aks-agic-destroy aks-nginx-create aks-nginx-destroy k9s

include .makerc

k9s:
	bash scripts/login_to_poc.sh
	k9s

aks-nginx-create:
	az account set --subscription=$(SUBSCRIPTION)
	terraform fmt -recursive
	terraform -chdir=tf-aks-nginx init
	terraform -chdir=tf-aks-nginx validate
	terraform -chdir=tf-aks-nginx plan -out=tf_plan.tfplan
	terraform -chdir=tf-aks-nginx apply tf_plan.tfplan
	bash scripts/login_to_poc.sh

aks-nginx-destroy:
	az account set --subscription=$(SUBSCRIPTION)
	terraform fmt -recursive
	terraform -chdir=tf-aks-nginx init
	terraform -chdir=tf-aks-nginx validate
	terraform -chdir=tf-aks-nginx plan -destroy -out=tf_plan.tfplan
	terraform -chdir=tf-aks-nginx apply tf_plan.tfplan

aks-agic-create:
	az account set --subscription=$(SUBSCRIPTION)
	terraform fmt -recursive
	terraform -chdir=tf-aks-agic init
	terraform -chdir=tf-aks-agic validate
	terraform -chdir=tf-aks-agic plan -out=tf_plan.tfplan
	terraform -chdir=tf-aks-agic apply tf_plan.tfplan
	bash scripts/login_to_poc.sh

aks-agic-destroy:
	az account set --subscription=$(SUBSCRIPTION)
	terraform -chdir=tf-aks-agic fmt -recursive
	terraform -chdir=tf-aks-agic init
	terraform -chdir=tf-aks-agic validate
	terraform -chdir=tf-aks-agic plan -destroy -out=tf_plan.tfplan
	terraform -chdir=tf-aks-agic apply tf_plan.tfplan

graphviz:
	terraform -chdir=tf-aks-agic graph | dot -Tsvg > graph.svg


aks-agic-workspace:
	terraform -chdir=tf-aks-agic workspace new poc

coder-workspace:
	terraform -chdir=tf-coder workspace new poc

coder-create:
	az account set --subscription=$(SUBSCRIPTION)
	terraform fmt -recursive
	terraform -chdir=tf-coder init
	terraform -chdir=tf-coder validate
	terraform -chdir=tf-coder plan -out=tf_plan.tfplan
	terraform -chdir=tf-coder apply tf_plan.tfplan
	bash scripts/login_to_poc.sh

coder-destroy:
	az account set --subscription=$(SUBSCRIPTION)
	terraform -chdir=tf-coder fmt -recursive
	terraform -chdir=tf-coder init
	terraform -chdir=tf-coder validate
	terraform -chdir=tf-coder plan -destroy -out=tf_plan.tfplan
	terraform -chdir=tf-coder apply tf_plan.tfplan

