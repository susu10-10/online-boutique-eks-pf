terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.61.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.2.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.2.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = data.terraform_remote_state.bootstrap.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.bootstrap.outputs.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes = {
    host                   = data.terraform_remote_state.bootstrap.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.bootstrap.outputs.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubectl" {
  host                   = data.terraform_remote_state.bootstrap.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.bootstrap.outputs.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
  load_config_file       = false
}