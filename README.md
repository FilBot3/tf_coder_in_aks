# Azure AKS with AGIC using Terraform

## Overview

The special thing about this repository and Terraform Module is that it is how
to use Terraform to create an AKS cluster with an AGIC using only Managed
Service Identities. I did not have to create any Service Principals! This took
some work to get over and get working with the help of the community from the
Azure ingress-azure and aad-pod-identity community.

## Requirements

* Terraform v0.14.4 or newer
* GNU Make

## Setup

Create a `.makerc` file for your subscription information

```make
SUBSCRIPTION = xxxxx-xxxxxx-xxxxxx-xxxxxxx
```

Then create an `.auto.tfvars` file in the terraform module to create.

```hcl
phil_pub_ip = "xxx.xxx.xxx.xxx/32"
```

## Usage

Use the make command to execute terraform. Otherwise read through the file and
see what it does.

```bash
make aks-agic-create
```

## References

* [AAD Pod Identities for
  AKS](https://azure.github.io/aad-pod-identity/docs/getting-started/role-assignment/)
* [Ingress-Azure AGIC
  Greenfield](https://azure.github.io/application-gateway-kubernetes-ingress/setup/install-new/)
* [GitHub: Azure/aad-pod-identity](https://github.com/Azure/aad-pod-identity)
* [GitHub:
  Azure/application-gateway-kubernetes-ingress](https://github.com/Azure/application-gateway-kubernetes-ingress)

### Coder.com

* [Coder Enterprise - Helm](https://github.com/cdr/enterprise-helm)
* [Coder Enterprise - Images](https://github.com/cdr/enterprise-images)

