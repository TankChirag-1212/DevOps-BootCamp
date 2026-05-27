resource "aws_eks_node_group" "node-group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "chirag-bootcamp-node-group"
  node_role_arn   = var.node_group_role_arn
  subnet_ids      = var.public_subnet_ids

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = var.node_group_instance_type

  ami_type = "AL2023_x86_64_STANDARD"

  disk_size = var.node_disk_size

  capacity_type = "ON_DEMAND"

  force_update_version = true

  update_config {
    max_unavailable_percentage = 33
  }

  labels = {
    "env" = "bootcamp"
    "team" = "devops"
  }

#   remote_access {
#     ec2_ssh_key = "chirag-eks-key"
#     source_security_group_ids = [aws_security_group.node_group_sg.id]
#   }

  tags = var.tags

}

# resource "aws_security_group_rule" "node_group_sg" {
#     type              = "ingress"
#     from_port         = 30000
#     to_port           = 32767
#     protocol          = "tcp"
#     security_group_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
#     cidr_blocks       = [var.my_ip_cidr]
# }