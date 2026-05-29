data "aws_caller_identity" "current" {}

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

# To get latest EKS addon version compatible with EKS cluster version
data "aws_eks_addon_version" "metrics_server_latest" {
  addon_name         = "metrics-server"
  kubernetes_version = module.eks_cluster.eks-cluster-version
  most_recent        = true
}

# To get auth token for the EKS cluster (used by helm provider)
data "aws_eks_cluster_auth" "cluster" {
  name = var.eks_cluster_name
}

# Pod Identity trust policy (shared across all microservice IAM roles)
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole", "sts:TagSession"]
  }
}

# Fetch DB credentials from Secrets Manager (created manually)
data "aws_secretsmanager_secret" "retailstore_secret" {
  name = "chirag-retailstore-db-secret"
}

data "aws_secretsmanager_secret_version" "retailstore_secret_value" {
  secret_id = data.aws_secretsmanager_secret.retailstore_secret.id
}


# Karpenter Controller IAM Policy
data "aws_iam_policy_document" "karpenter_controller_policy" {

  # ---------------------------------------------------------------------------
  # AllowScopedEC2InstanceAccessActions
  # ---------------------------------------------------------------------------
  statement {
    sid    = "AllowScopedEC2InstanceAccessActions"
    effect = "Allow"

    actions = [
      "ec2:RunInstances",
      "ec2:CreateFleet",
    ]

    resources = [
      "arn:aws:ec2:${var.aws_region}::image/*",
      "arn:aws:ec2:${var.aws_region}::snapshot/*",
      "arn:aws:ec2:${var.aws_region}:*:security-group/*",
      "arn:aws:ec2:${var.aws_region}:*:subnet/*",
      "arn:aws:ec2:${var.aws_region}:*:capacity-reservation/*",
    ]
  }

  # ---------------------------------------------------------------------------
  # AllowScopedEC2LaunchTemplateAccessActions
  # ---------------------------------------------------------------------------
  statement {
    sid    = "AllowScopedEC2LaunchTemplateAccessActions"
    effect = "Allow"

    actions = [
      "ec2:RunInstances",
      "ec2:CreateFleet",
    ]

    resources = [
      "arn:aws:ec2:${var.aws_region}:*:launch-template/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${var.eks_cluster_name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.sh/nodepool"
      values   = ["*"]
    }
  }

  # ---------------------------------------------------------------------------
  # AllowScopedEC2InstanceActionsWithTags
  # ---------------------------------------------------------------------------
  statement {
    sid    = "AllowScopedEC2InstanceActionsWithTags"
    effect = "Allow"

    actions = [
      "ec2:RunInstances",
      "ec2:CreateFleet",
      "ec2:CreateLaunchTemplate",
    ]

    resources = [
      "arn:aws:ec2:${var.aws_region}:*:fleet/*",
      "arn:aws:ec2:${var.aws_region}:*:instance/*",
      "arn:aws:ec2:${var.aws_region}:*:volume/*",
      "arn:aws:ec2:${var.aws_region}:*:network-interface/*",
      "arn:aws:ec2:${var.aws_region}:*:launch-template/*",
      "arn:aws:ec2:${var.aws_region}:*:spot-instances-request/*",
      "arn:aws:ec2:${var.aws_region}:*:capacity-reservation/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${var.eks_cluster_name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks:eks-cluster-name"
      values   = [var.eks_cluster_name]
    }

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/karpenter.sh/nodepool"
      values   = ["*"]
    }
  }

  # ---------------------------------------------------------------------------
  # AllowScopedResourceCreationTagging
  # ---------------------------------------------------------------------------
  statement {
    sid    = "AllowScopedResourceCreationTagging"
    effect = "Allow"

    actions = [
      "ec2:CreateTags",
    ]

    resources = [
      "arn:aws:ec2:${var.aws_region}:*:fleet/*",
      "arn:aws:ec2:${var.aws_region}:*:instance/*",
      "arn:aws:ec2:${var.aws_region}:*:volume/*",
      "arn:aws:ec2:${var.aws_region}:*:network-interface/*",
      "arn:aws:ec2:${var.aws_region}:*:launch-template/*",
      "arn:aws:ec2:${var.aws_region}:*:spot-instances-request/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${var.eks_cluster_name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks:eks-cluster-name"
      values   = [var.eks_cluster_name]
    }

    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = [
        "RunInstances",
        "CreateFleet",
        "CreateLaunchTemplate",
      ]
    }

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/karpenter.sh/nodepool"
      values   = ["*"]
    }
  }

  # ---------------------------------------------------------------------------
  # AllowScopedResourceTagging
  # ---------------------------------------------------------------------------
  statement {
    sid    = "AllowScopedResourceTagging"
    effect = "Allow"

    actions = [
      "ec2:CreateTags",
    ]

    resources = [
      "arn:aws:ec2:${var.aws_region}:*:instance/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${var.eks_cluster_name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.sh/nodepool"
      values   = ["*"]
    }

    condition {
      test     = "StringEqualsIfExists"
      variable = "aws:RequestTag/eks:eks-cluster-name"
      values   = [var.eks_cluster_name]
    }

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "aws:TagKeys"
      values = [
        "eks:eks-cluster-name",
        "karpenter.sh/nodeclaim",
        "Name",
      ]
    }
  }

  # ---------------------------------------------------------------------------
  # AllowScopedDeletion
  # ---------------------------------------------------------------------------
  statement {
    sid    = "AllowScopedDeletion"
    effect = "Allow"

    actions = [
      "ec2:TerminateInstances",
      "ec2:DeleteLaunchTemplate",
    ]

    resources = [
      "arn:aws:ec2:${var.aws_region}:*:instance/*",
      "arn:aws:ec2:${var.aws_region}:*:launch-template/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${var.eks_cluster_name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.sh/nodepool"
      values   = ["*"]
    }
  }

  # ---------------------------------------------------------------------------
  # AllowRegionalReadActions
  # ---------------------------------------------------------------------------
  statement {
    sid    = "AllowRegionalReadActions"
    effect = "Allow"

    actions = [
      "ec2:DescribeCapacityReservations",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeSubnets",
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }

  # ---------------------------------------------------------------------------
  # AllowSSMReadActions
  # ---------------------------------------------------------------------------
  statement {
    sid    = "AllowSSMReadActions"
    effect = "Allow"

    actions = [
      "ssm:GetParameter",
    ]

    resources = [
      "arn:aws:ssm:${var.aws_region}::parameter/aws/service/*",
    ]
  }

  # ---------------------------------------------------------------------------
  # AllowPricingReadActions
  # ---------------------------------------------------------------------------
  statement {
    sid    = "AllowPricingReadActions"
    effect = "Allow"

    actions = [
      "pricing:GetProducts",
    ]

    resources = ["*"]
  }

  # ---------------------------------------------------------------------------
  # AllowInterruptionQueueActions
  # (assumes aws_sqs_queue.karpenter_interruption exists)
  # ---------------------------------------------------------------------------
  statement {
    sid    = "AllowInterruptionQueueActions"
    effect = "Allow"

    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes", 
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
    ]

    resources = [
      aws_sqs_queue.karpenter_interruption.arn,
    ]
  }

  # ---------------------------------------------------------------------------
  # AllowPassingInstanceRole
  # ---------------------------------------------------------------------------
  statement {
    sid    = "AllowPassingInstanceRole"
    effect = "Allow"

    actions = [
      "iam:PassRole",
    ]

    resources = [
      module.iam.karpenter_node_role_arn,
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values = [
        "ec2.amazonaws.com",
        "ec2.amazonaws.com.cn",
      ]
    }
  }

  # ---------------------------------------------------------------------------
  # AllowScopedInstanceProfileCreationActions
  # ---------------------------------------------------------------------------
  statement {
    sid    = "AllowScopedInstanceProfileCreationActions"
    effect = "Allow"

    actions = [
      "iam:CreateInstanceProfile",
    ]

    resources = [
      "arn:aws:iam::${data.aws_vpc.main.owner_id}:instance-profile/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${var.eks_cluster_name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks:eks-cluster-name"
      values   = [var.eks_cluster_name]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/topology.kubernetes.io/region"
      values   = [var.aws_region]
    }

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass"
      values   = ["*"]
    }
  }

  # ---------------------------------------------------------------------------
  # AllowScopedInstanceProfileTagActions
  # ---------------------------------------------------------------------------
  statement {
    sid    = "AllowScopedInstanceProfileTagActions"
    effect = "Allow"

    actions = [
      "iam:TagInstanceProfile",
    ]

    resources = [
      "arn:aws:iam::${data.aws_vpc.main.owner_id}:instance-profile/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${var.eks_cluster_name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/topology.kubernetes.io/region"
      values   = [var.aws_region]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${var.eks_cluster_name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks:eks-cluster-name"
      values   = [var.eks_cluster_name]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/topology.kubernetes.io/region"
      values   = [var.aws_region]
    }

    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass"
      values   = ["*"]
    }

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass"
      values   = ["*"]
    }
  }

  # ---------------------------------------------------------------------------
  # AllowScopedInstanceProfileActions
  # ---------------------------------------------------------------------------
  statement {
    sid    = "AllowScopedInstanceProfileActions"
    effect = "Allow"

    actions = [
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:DeleteInstanceProfile",
    ]

    resources = [
      "arn:aws:iam::${data.aws_vpc.main.owner_id}:instance-profile/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${var.eks_cluster_name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/topology.kubernetes.io/region"
      values   = [var.aws_region]
    }

    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass"
      values   = ["*"]
    }
  }

  # ---------------------------------------------------------------------------
  # AllowInstanceProfileReadActions
  # ---------------------------------------------------------------------------
  statement {
    sid    = "AllowInstanceProfileReadActions"
    effect = "Allow"

    actions = [
      "iam:GetInstanceProfile",
    ]

    resources = [
      "arn:aws:iam::${data.aws_vpc.main.owner_id}:instance-profile/*",
    ]
  }

  # ---------------------------------------------------------------------------
  # AllowUnscopedInstanceProfileListAction
  # ---------------------------------------------------------------------------
  statement {
    sid    = "AllowUnscopedInstanceProfileListAction"
    effect = "Allow"

    actions = [
      "iam:ListInstanceProfiles",
    ]

    resources = ["*"]
  }

  # ---------------------------------------------------------------------------
  # AllowAPIServerEndpointDiscovery
  # ---------------------------------------------------------------------------
  statement {
    sid    = "AllowAPIServerEndpointDiscovery"
    effect = "Allow"

    actions = [
      "eks:DescribeCluster",
    ]

    resources = [
      "arn:aws:eks:${var.aws_region}:${data.aws_vpc.main.owner_id}:cluster/${var.eks_cluster_name}",
    ]
  }
}
