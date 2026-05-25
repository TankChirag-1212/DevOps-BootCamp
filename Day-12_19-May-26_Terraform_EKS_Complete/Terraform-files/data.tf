# Fetching vpc details
data "aws_vpc" "main" {
  tags = {
    Name = "Bootcamp-vpc-do-not-delete-vpc"
  }
}

# Fetching internet gateway details
data "aws_internet_gateway" "main" {
  tags = {
    Name = "Bootcamp-vpc-do-not-delete-igw"
  }
}

# comman trust-policy for all the add-on roles
data "aws_iam_policy_document" "eks_addon_trust_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

# AWS Load Balancer Controller IAM Policy get from aws-load-balancer-controller/ GIT Repo (latest)
data "http" "lbc_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"

  request_headers = {
    Accept = "application/json"
  }
}

# To get latest EKS pod-identity-agent addon version compatible with EKS cluster version
data "aws_eks_addon_version" "pia_latest" {
  addon_name         = "eks-pod-identity-agent"
  kubernetes_version = module.eks_cluster.eks-cluster-version
  most_recent        = true
}

# To get latest EBS CSI addon version compatible with EKS cluster version
data "aws_eks_addon_version" "ebs_csi_latest" {
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = module.eks_cluster.eks-cluster-version
  most_recent        = true
}

# To get auth token for the EKS cluster (used by helm provider)
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks_cluster.eks-cluster-name
}