module "vpc" {
  source = "./modules/vpc"

  tags                = var.tags
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  subnet_az           = var.subnet_az
}

module "ec2" {
  source = "./modules/ec2"

  tags                 = var.tags
  public_subnet_id     = module.vpc.public_subnet_id
  private_subnet_id    = module.vpc.private_subnet_id
  vpc_id               = module.vpc.vpc_id
  sg_pub_ingress_cidrs = var.sg_pub_ingress_cidrs
}
