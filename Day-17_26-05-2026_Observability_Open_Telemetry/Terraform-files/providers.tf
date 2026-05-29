terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.28"
    }
  }
  backend "s3" {
    bucket       = "chirag-tank-bootcamp-454143665149-ap-south-1-an"
    key          = "dev/eks-data-plane/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}

provider "helm" {
  kubernetes = {
    host                   = try(module.eks_cluster.cluster_endpoint, "")
    cluster_ca_certificate = try(base64decode(module.eks_cluster.eks-cluster-certificate-authority-data), "")
    token                  = try(data.aws_eks_cluster_auth.cluster.token, "")
  }
}

provider "kubernetes" {
  host                   = try(module.eks_cluster.cluster_endpoint, "")
  cluster_ca_certificate = try(base64decode(module.eks_cluster.eks-cluster-certificate-authority-data), "")
  token                  = try(data.aws_eks_cluster_auth.cluster.token, "")
}