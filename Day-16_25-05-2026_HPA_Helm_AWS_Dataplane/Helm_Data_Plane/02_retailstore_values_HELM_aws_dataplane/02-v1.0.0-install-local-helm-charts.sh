#!/bin/bash

set -e
echo "--------------------------------------------"
echo "Authenticating to Amazon Public ECR for Helm..."
echo "--------------------------------------------"

# Authenticate to Amazon Public ECR (token valid for 12 hours)
aws ecr-public get-login-password --region us-east-1 | \
helm registry login -u AWS --password-stdin public.ecr.aws
sleep 5

echo "--------------------------------------------"
echo "Starting Helm installs for Retail Store Sample App..."
echo "--------------------------------------------"
echo

# Step 01 - Catalog Service
echo "--------------------------------------------"
echo "Installing Catalog Service..."
helm upgrade --install catalog ../01_retailstore_charts_updates/charts_v1.0.0/retail-store-sample-catalog-chart \
  -f values-catalog.yaml
sleep 10

# Step 02 - Cart Service
echo "--------------------------------------------"
echo "Installing Carts Service..."
helm upgrade --install carts ../01_retailstore_charts_updates/charts_v1.0.0/retail-store-sample-cart-chart \
  -f values-cart.yaml
sleep 10

# Step 03 - Checkout Service
echo "--------------------------------------------"
echo "Installing Checkout Service..."
helm upgrade --install checkout \
  ../01_retailstore_charts_updates/charts_v1.0.0/retail-store-sample-checkout-chart \
  -f values-checkout.yaml
sleep 10

# Step 04 - Orders Service
echo "--------------------------------------------"
echo "Installing Orders Service..."
helm upgrade --install orders ../01_retailstore_charts_updates/charts_v1.0.0/retail-store-sample-orders-chart \
  -f values-orders.yaml
sleep 10


# Step 05 - UI Service
echo "--------------------------------------------"
echo "Installing UI Service..."
helm upgrade --install ui ../01_retailstore_charts_updates/charts_v1.0.0/retail-store-sample-ui-chart \
  -f values-ui.yaml
sleep 10

echo
echo "--------------------------------------------"
echo "All Helm installs completed!"
echo "--------------------------------------------"


