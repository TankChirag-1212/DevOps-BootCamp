module "vpc" {
  source               = "./vpc"
  aws_region           = var.aws_region
  public_subnet_1_cidr = var.public_subnet_1_cidr
  public_subnet_2_cidr = var.public_subnet_2_cidr
  tags                 = var.tags
}

module "eks_cluster" {
  source = "./eks"
  #   aws_region = var.aws_region
  eks_version = var.eks_version

  node_group_instance_type = var.node_group_instance_type
  node_disk_size           = var.node_disk_size

  #   vpc_id = module.vpc.vpc_id
  public_subnet_ids = [module.vpc.public_subnet_1_id, module.vpc.public_subnet_2_id]
  service_ipv4_cidr = var.service_ipv4_cidr
  my_ip_cidr        = var.my_ip_cidr

  tags = var.tags
}