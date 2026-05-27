# Security Group for ElastiCache Redis
resource "aws_security_group" "redis_sg" {
  name        = "${var.name}-redis-sg"
  description = "Allow EKS cluster to access ElastiCache Redis"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.eks_cluster_security_group_id]
    description     = "Allow traffic from EKS cluster SG"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-redis-sg" })
}

# ElastiCache Subnet Group
resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "${var.name}-redis-subnets"
  subnet_ids = var.subnet_ids
}

# ElastiCache Redis Cluster
resource "aws_elasticache_cluster" "checkout_redis" {
  cluster_id           = "${var.name}-checkout-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids   = [aws_security_group.redis_sg.id]
  engine_version       = "7.1"
  parameter_group_name = "default.redis7"
  tags                 = merge(var.tags, { Name = "${var.name}-checkout-redis" })
}
