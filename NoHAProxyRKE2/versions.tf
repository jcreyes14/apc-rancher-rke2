terraform {
  required_version = ">= 0.14"
  required_providers {
    vsphere = {
      source = "hashicorp/vsphere"
      version = ">= 2.2.0"
    }
    rancher2 = {
      source = "rancher/rancher2"
      version = ">= 1.24.0"
      configuration_aliases = [ rancher2.bootstrap, rancher2.admin ]
    }
    helm = {
      source = "hashicorp/helm"
      version = "2.7.1"
    }
  }
}
