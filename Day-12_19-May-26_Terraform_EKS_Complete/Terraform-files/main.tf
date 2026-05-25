module "vpc" {
  source               = "./vpc"
  vpc_id               = data.aws_vpc.main.id
  igw_id               = data.aws_internet_gateway.main.id
  aws_region           = var.aws_region
  public_subnet_1_cidr = var.public_subnet_1_cidr
  public_subnet_2_cidr = var.public_subnet_2_cidr
  tags                 = var.tags
}

module "eks_cluster" {
  source = "./eks"
  vpc_id               = data.aws_vpc.main.id
  aws_region           = var.aws_region
  eks_version          = var.eks_version
  eks_cluster_role_arn = module.iam.eks_cluster_role_arn

  node_group_role_arn      = module.iam.node_group_role_arn
  node_group_instance_type = var.node_group_instance_type
  node_disk_size           = var.node_disk_size

  #   vpc_id = module.vpc.vpc_id
  public_subnet_ids = [module.vpc.public_subnet_1_id, module.vpc.public_subnet_2_id]
  service_ipv4_cidr = var.service_ipv4_cidr
  my_ip_cidr        = var.my_ip_cidr

  # EKS Add-Ons
  pia_latest     = data.aws_eks_addon_version.pia_latest.version
  ebs_csi_latest = data.aws_eks_addon_version.ebs_csi_latest.version

  # Pod Identity Association
  albc_role_arn = module.iam.albc_role_arn
  ebs_csi_role_arn = module.iam.ebs_csi_role_arn

  tags = var.tags

  depends_on = [
    module.vpc,
    module.iam
  ]
}

module "iam" {
  source = "./iam"
  tags   = var.tags

  # for alb-controller add-on
  eks_addon_trust_policy = data.aws_iam_policy_document.eks_addon_trust_policy.json
  albc_iam_policy        = data.http.lbc_iam_policy.response_body

  # for ebs csi add-on

}