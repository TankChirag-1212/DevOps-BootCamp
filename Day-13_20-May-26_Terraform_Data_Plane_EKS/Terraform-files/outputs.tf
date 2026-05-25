# Catalog
output "catalog_rds_endpoint" {
  value = module.catalog.catalog_rds_endpoint
}

output "catalog_sa_getsecrets_role_arn" {
  value = module.catalog.catalog_sa_getsecrets_role_arn
}

output "catalog_sa_pod_identity_association_arn" {
  value = module.catalog.catalog_sa_pod_identity_association_arn
}

# Cart
output "cart_dynamodb_role_arn" {
  value = module.cart.cart_dynamodb_role_arn
}

output "cart_dynamodb_pod_identity_association_arn" {
  value = module.cart.cart_dynamodb_pod_identity_association_arn
}

# Checkout
output "checkout_redis_endpoint" {
  value = module.checkout.checkout_redis_endpoint
}

# Orders
output "orders_rds_postgresql_endpoint" {
  value = module.orders.orders_rds_postgresql_endpoint
}

output "orders_sqs_queue_url" {
  value = module.orders.orders_sqs_queue_url
}

output "orders_postgresql_sa_getsecrets_role_arn" {
  value = module.orders.orders_postgresql_sa_getsecrets_role_arn
}

output "orders_postgresql_sa_pod_identity_association_arn" {
  value = module.orders.orders_postgresql_sa_pod_identity_association_arn
}
