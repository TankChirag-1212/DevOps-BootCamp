# Day 13 — Terraform Data Plane & RetailStore Microservices on EKS

## Topic 01: What is the Data Plane?

In the context of this lab, the **Data Plane** refers to the AWS managed services that the RetailStore microservices depend on for persistence and messaging — provisioned separately from the EKS cluster itself using Terraform.

Each microservice owns its own backing store, following the microservices principle of data isolation:

| Microservice | AWS Service | Purpose |
|---|---|---|
| **Catalog** | RDS MySQL | Stores product catalogue data |
| **Cart** | DynamoDB | Stores shopping cart items per customer |
| **Checkout** | ElastiCache Redis | Session state and checkout flow caching |
| **Orders** | RDS PostgreSQL + SQS | Stores orders; SQS decouples checkout → orders async flow |

---

## Topic 02: Terraform Project Structure

The Terraform code is split into two separate stages that are applied independently:

- **Stage 1 (Day-12)** — Provisions the EKS cluster with all required add-ons (Pod Identity Agent, AWS Load Balancer Controller, EBS CSI Driver, Secrets Store CSI + ASCP)
- **Stage 2 (Day-13)** — Provisions the data plane AWS services and the per-microservice IAM roles and Pod Identity Associations

The Day-13 Terraform is organised into one module per microservice, each responsible for its own AWS resources and IAM setup:

```
Terraform-files/
├── catalog/        # RDS MySQL security group + IAM role + Pod Identity Association
├── cart/           # DynamoDB table + IAM role + Pod Identity Association
├── checkout/       # ElastiCache Redis cluster + security group
├── orders/         # RDS PostgreSQL security group + SQS queue + IAM role + Pod Identity Association
├── main.tf         # Root module — calls all four child modules
├── data.tf         # Remote state data source to read VPC/EKS outputs from Stage 1
├── providers.tf
├── variables.tf
├── outputs.tf
└── terraform.tfvars
```

---

## Topic 03: Per-Microservice IAM & Pod Identity

Each microservice that needs to call AWS APIs gets its own dedicated IAM role with a scoped-down policy, linked to its Kubernetes ServiceAccount via a Pod Identity Association. This follows the principle of least privilege — no microservice has more permissions than it needs.

| Microservice | IAM Policy | Pod Identity ServiceAccount |
|---|---|---|
| **Catalog** | `secretsmanager:GetSecretValue` on `chirag-retailstore-db-secret*` | `catalog` in `default` namespace |
| **Cart** | Full DynamoDB CRUD on all tables | `carts` in `default` namespace |
| **Orders** | SQS send/receive/delete + `secretsmanager:GetSecretValue` | `orders` in `default` namespace |

The Checkout service uses ElastiCache Redis directly via its endpoint — no AWS API calls needed, so no Pod Identity role is required for it.

---

## Topic 04: Kubernetes Manifests Structure

The K8s manifests are also organised per microservice and deployed in a specific order to handle dependencies correctly:

```
k8s_manifests_with_Data_Plane/
├── 01_secretproviderclass/         # SecretProviderClass for Catalog (MySQL) and Orders (PostgreSQL)
├── 02_RetailStore_Microservices/   # One folder per microservice (SA, ConfigMap, Deployment, Service)
│   ├── 01_catalog/
│   ├── 02_cart/
│   ├── 03_checkout/
│   ├── 04_orders/
│   └── 05_ui/
├── 03_ingress/                     # HTTP ALB Ingress (IP mode)
└── 04_Verification_Pods/           # Temporary client pods for validating each backing service
```

The `SecretProviderClass` resources must be deployed before the Catalog and Orders pods, because those pods mount a CSI volume that references the `SecretProviderClass` — if it doesn't exist, the pod will fail to start.

---

## Topic 05: Troubleshooting — MySQL Role Activation

During the lab, the Catalog and Orders pods were failing to connect to their RDS databases even though the credentials in Secrets Manager were correct. The root cause was that the MySQL user (`mysqluser`) had been granted the `rds_superuser_role` but the role was not being activated automatically on login.

This is a MySQL 8 behaviour — granted roles are not active by default unless `activate_all_roles_on_login` is enabled at the server level or the default role is explicitly set for the user. The fix was to connect to the RDS instance via a temporary MySQL client pod and run:

```sql
SET DEFAULT ROLE ALL TO '<user-name>'@'%';
```

This sets all granted roles as the default active roles for that user on every login, resolving the authentication failure without needing to change any application code or Secrets Manager values.

---

## Lab Implementation

### 1. Provision EKS Cluster (Day-12 Terraform)

The EKS cluster with all add-ons was provisioned first using the Day-12 Terraform files, then kubectl was configured:

```bash
cd Day-12_19-May-26_Terraform_EKS_Complete/Terraform-files

terraform init
terraform validate
terraform plan
terraform apply -auto-approve
terraform output
```

```bash
aws eks update-kubeconfig --region ap-south-1 --name chirag-eks-cluster
kubectl get nodes
kubectl get all -A
```

![EKS cluster nodes verified](images/Screenshot%202026-05-20%20155627.png)

![All add-on pods running](images/Screenshot%202026-05-20%20155645.png)

![Cluster resources healthy](images/Screenshot%202026-05-20%20155714.png)

---

### 2. Provision Data Plane (Day-13 Terraform)

With the EKS cluster running, provisioned all the backing AWS services — RDS MySQL, RDS PostgreSQL, DynamoDB, ElastiCache Redis, SQS — along with the per-microservice IAM roles and Pod Identity Associations:

```bash
cd Day-13_20-May-26_Terraform_Data_Plane_EKS/Terraform-files

terraform init
terraform validate
terraform plan
terraform apply -auto-approve
terraform output
```

![Terraform plan — data plane resources](images/Screenshot%202026-05-20%20161856.png)

![DynamoDB table created](images/Screenshot%202026-05-20%20165551.png)

![ElastiCache Redis cluster created](images/Screenshot%202026-05-20%20165701.png)

![SQS queue created](images/Screenshot%202026-05-20%20165717.png)

---

### 3. Deploy SecretProviderClass, UI & Ingress

Deployed in this specific order first — SecretProviderClass must exist before any pod that mounts it, and the UI + Ingress were deployed early to validate the ALB was provisioning correctly before deploying the backend services:

```bash
kubectl apply -f 01_secretproviderclass/
kubectl apply -f 02_RetailStore_Microservices/05_ui/
kubectl apply -f 03_ingress/

kubectl get pods,secretproviderclass,ingress
```

![SecretProviderClass and UI deployed](images/Screenshot%202026-05-21%20142853.png)

![Ingress created — ALB DNS assigned](images/Screenshot%202026-05-21%20143006.png)

![UI accessible via ALB DNS](images/Screenshot%202026-05-21%20143131.png)

![Topology endpoint showing UI only](images/Screenshot%202026-05-21%20143655.png)

---

### 4. Deploy Remaining Microservices

With the ALB confirmed working, deployed all remaining microservices:

```bash
kubectl apply -R -f 02_RetailStore_Microservices/

kubectl get all,secrets,cm,secretproviderclass,ingress
```

![All microservices deployed](images/Screenshot%202026-05-21%20163324.png)

![Pod status — catalog and orders failing](images/Screenshot%202026-05-21%20163357.png)

---

### 5. Troubleshoot Catalog & Orders Pod Failures

The Catalog and Orders pods were in `CrashLoopBackOff`. Described the deployments to identify the root cause:

```bash
kubectl describe deploy catalog
kubectl describe deploy orders
```

Both were failing to authenticate to their RDS databases. Spun up a temporary MySQL client pod to connect directly to the RDS instance and investigate:

```bash
kubectl run mysql-client --rm -it \
  --image=mysql:8.0 \
  --restart=Never \
  -- mysql -h catalog-mysql -u <user-name> -p
```

Confirmed the user existed and had the correct grants, but the `rds_superuser_role` was not being activated on login. Fixed it by setting the default role:

```sql
SET DEFAULT ROLE ALL TO '<user-name>'@'%';
```

![MySQL client pod — investigating user grants](images/Screenshot%202026-05-21%20163642.png)

![Default role set — issue resolved](images/Screenshot%202026-05-21%20164220.png)

![Catalog pod now running](images/Screenshot%202026-05-21%20164304.png)

![Orders pod now running](images/Screenshot%202026-05-21%20164923.png)

---

### 6. Validate All Services

With all 5 pods running, validated the full application via the ALB DNS name and verified each backing service had data:

```bash
kubectl get all,secrets,cm,secretproviderclass,ingress
```

- `http://ALB_DNS_NAME/topology` — all 5 services should show as healthy
- Placed a dummy order to trigger the full flow: UI → Checkout → SQS → Orders → PostgreSQL

![All 5 pods running](images/Screenshot%202026-05-21%20165140.png)

![Topology — all services healthy](images/Screenshot%202026-05-21%20165624.png)

![Retail store UI accessible](images/Screenshot%202026-05-21%20183100.png)

![SQS queue — order messages received](images/Screenshot%202026-05-21%20201122.png)

![DynamoDB — cart items stored](images/Screenshot%202026-05-21%20201141.png)

![RDS PostgreSQL — orders stored](images/Screenshot%202026-05-21%20201229.png)

![RDS MySQL — catalog data accessible](images/Screenshot%202026-05-21%20201257.png)

![ElastiCache Redis — checkout session data](images/Screenshot%202026-05-21%20201347.png)

---

### 7. Cleanup

Deleted all Kubernetes resources first, then destroyed the Terraform infrastructure in reverse order (data plane first, then EKS cluster):

```bash
kubectl delete -R -f 02_RetailStore_Microservices/
kubectl delete -f 01_secretproviderclass/
kubectl delete -f 03_ingress/

kubectl get all,secrets,cm,secretproviderclass,ingress
```

```bash
# Destroy data plane first
cd Day-13_20-May-26_Terraform_Data_Plane_EKS/Terraform-files
terraform destroy -auto-approve

# Then destroy EKS cluster
cd Day-12_19-May-26_Terraform_EKS_Complete/Terraform-files
terraform destroy -auto-approve
```

![All K8s resources deleted](images/Screenshot%202026-05-21%20203144.png)

![Data plane resources destroyed](images/Screenshot%202026-05-21%20203358.png)

![EKS cluster destroyed](images/Screenshot%202026-05-21%20203646.png)

![Terraform destroy complete — data plane](images/Screenshot%202026-05-21%20204150.png)

![Terraform destroy complete — EKS cluster](images/Screenshot%202026-05-21%20204303.png)

![AWS console — all resources cleaned up](images/Screenshot%202026-05-21%20205621.png)

---

## Summary

Day 13 focused on provisioning the AWS data plane for a full 5-microservice RetailStore application using Terraform, and deploying the application onto the EKS cluster from Day-12.

- **Data plane separation** — The backing AWS services (RDS, DynamoDB, ElastiCache, SQS) are provisioned in a separate Terraform stage from the EKS cluster, keeping infrastructure concerns cleanly separated
- **Per-microservice IAM roles** — Each microservice gets its own scoped-down IAM role linked via Pod Identity Association, following least-privilege; no microservice can access another's AWS resources
- **Deployment order matters** — `SecretProviderClass` must be deployed before any pod that mounts it; deploying UI and Ingress first allowed early ALB validation before the backend services were ready
- **MySQL role activation** — MySQL 8 granted roles are not active by default; `SET DEFAULT ROLE ALL TO '<user>'@'%'` is required to activate them on every login, which was the root cause of the Catalog and Orders pod failures
- **Destroy order matters** — The data plane must be destroyed before the EKS cluster, since the data plane Terraform reads remote state outputs (VPC ID, security group IDs) from the EKS cluster stage
