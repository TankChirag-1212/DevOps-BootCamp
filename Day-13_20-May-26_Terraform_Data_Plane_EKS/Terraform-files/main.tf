module "catalog" {
  source = "./catalog"

  name                          = "${var.business_division}-dev"
  vpc_id                        = data.aws_vpc.main.id
  # subnet_ids                  = [data.aws_subnet.pub_sub_1.id, data.aws_subnet.pub_sub_2.id]  # uncomment when creating new RDS
  eks_cluster_name              = data.terraform_remote_state.eks.outputs.eks_cluster_name
  eks_cluster_security_group_id = data.terraform_remote_state.eks.outputs.eks_cluster_security_group_id
  assume_role_policy            = data.aws_iam_policy_document.assume_role.json
  # db_username                 = jsondecode(data.aws_secretsmanager_secret_version.retailstore_secret_value.secret_string).username  # uncomment when creating new RDS
  # db_password                 = jsondecode(data.aws_secretsmanager_secret_version.retailstore_secret_value.secret_string).password  # uncomment when creating new RDS
  aws_region                    = var.aws_region
  account_id                    = data.aws_caller_identity.current.account_id
  tags                          = var.tags
}

module "cart" {
  source = "./cart"

  name               = "${var.business_division}-dev"
  eks_cluster_name   = data.terraform_remote_state.eks.outputs.eks_cluster_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = var.tags
}

module "checkout" {
  source = "./checkout"

  name                          = "${var.business_division}-dev"
  vpc_id                        = data.aws_vpc.main.id
  subnet_ids                    = [data.aws_subnet.pub_sub_1.id, data.aws_subnet.pub_sub_2.id]
  eks_cluster_security_group_id = data.terraform_remote_state.eks.outputs.eks_cluster_security_group_id
  tags                          = var.tags
}

module "orders" {
  source = "./orders"

  name                          = "${var.business_division}-dev"
  vpc_id                        = data.aws_vpc.main.id
  # subnet_ids                  = [data.aws_subnet.pub_sub_1.id, data.aws_subnet.pub_sub_2.id]  # uncomment when creating new RDS
  eks_cluster_name              = data.terraform_remote_state.eks.outputs.eks_cluster_name
  eks_cluster_security_group_id = data.terraform_remote_state.eks.outputs.eks_cluster_security_group_id
  assume_role_policy            = data.aws_iam_policy_document.assume_role.json
  # db_username                 = jsondecode(data.aws_secretsmanager_secret_version.retailstore_secret_value.secret_string).username  # uncomment when creating new RDS
  # db_password                 = jsondecode(data.aws_secretsmanager_secret_version.retailstore_secret_value.secret_string).password  # uncomment when creating new RDS
  aws_region                    = var.aws_region
  account_id                    = data.aws_caller_identity.current.account_id
  tags                          = var.tags
}
