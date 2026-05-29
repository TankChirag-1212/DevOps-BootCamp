output "checkout_redis_endpoint" {
  value = aws_elasticache_cluster.checkout_redis.cache_nodes[0].address
}

output "redis_sg_id" {
  value = aws_security_group.redis_sg.id
}
