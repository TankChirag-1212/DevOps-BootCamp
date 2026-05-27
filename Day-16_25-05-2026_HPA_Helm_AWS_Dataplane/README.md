# Day 16 — HPA, PDB, Topology Spread Constraints & Helm Data Plane

## Topic 01: Horizontal Pod Autoscaler (HPA)

The **Horizontal Pod Autoscaler (HPA)** automatically scales the number of pod replicas in a Deployment up or down based on observed CPU and memory utilisation metrics. It works by periodically querying the **Metrics Server** for resource usage and comparing it against the configured targets.

### How HPA Works

```
Metrics Server collects CPU/memory from pods
        ↓
HPA controller queries Metrics Server every 15 seconds
        ↓
Compares current utilisation against target thresholds
        ↓
If above threshold → scale up (add replicas)
If below threshold → scale down (remove replicas)
        ↓
Karpenter detects new pods → provisions nodes if needed
Karpenter detects empty nodes → consolidates and terminates
```

### HPA + Karpenter Integration

HPA and Karpenter work together as a two-level autoscaling system:
- **HPA** handles pod-level scaling — adds or removes replicas based on load
- **Karpenter** handles node-level scaling — provisions or terminates EC2 instances based on pod demand

When HPA scales up pods that exceed current node capacity, Karpenter automatically provisions new nodes. When HPA scales down pods and nodes become underutilised, Karpenter consolidates and terminates them.

### HPA Behaviour Configuration

The `behavior` block controls how aggressively HPA scales in each direction:

```yaml
behavior:
  scaleUp:
    stabilizationWindowSeconds: 0        # scale up immediately — no wait
    policies:
      - type: Percent                    # add up to 100% more pods
        value: 100
        periodSeconds: 15
      - type: Pods                       # or add up to 4 pods
        value: 4
        periodSeconds: 15
    selectPolicy: Max                    # use whichever policy adds more pods
  scaleDown:
    stabilizationWindowSeconds: 300      # wait 5 minutes before scaling down
    policies:
      - type: Percent                    # remove at most 50% of pods
        value: 50
        periodSeconds: 15
      - type: Pods                       # or remove at most 1 pod
        value: 1
        periodSeconds: 60
    selectPolicy: Min                    # use whichever policy removes fewer pods
```

Scale-up is aggressive (`selectPolicy: Max`) to handle traffic spikes quickly. Scale-down is conservative (`selectPolicy: Min`, 5-minute stabilisation window) to avoid flapping when load briefly drops.

### Metrics Server Requirement

HPA requires the **Metrics Server** add-on to be installed in the cluster. Without it, `kubectl get hpa` shows `<unknown>` for all metrics and HPA cannot make scaling decisions. In this lab the Metrics Server was missing initially — the Terraform code was updated to install it as an EKS add-on, after which HPA metrics became visible immediately.

---

## Topic 02: PodDisruptionBudget (PDB)

A **PodDisruptionBudget** limits how many pods of a deployment can be simultaneously unavailable during voluntary disruptions — node drains, rolling updates, Karpenter consolidation, or cluster upgrades.

```yaml
spec:
  minAvailable: 2    # at least 2 pods must be running at all times
```

With `minAvailable: 2` and HPA maintaining 3+ replicas, Karpenter can only evict one pod at a time during node consolidation — keeping the service available throughout. Without a PDB, Karpenter could evict all pods on a node simultaneously, causing a service outage.

### PDB + HPA + Karpenter Together

```
HPA scales up to 6 replicas due to load
        ↓
Load drops → HPA scales down to 3 replicas
        ↓
Karpenter detects underutilised node → tries to drain it
        ↓
PDB (minAvailable: 2) limits eviction → only 1 pod evicted at a time
        ↓
Service stays available throughout consolidation
```

---

## Topic 03: Topology Spread Constraints (TSC)

**Topology Spread Constraints** ensure pods are evenly distributed across nodes and Availability Zones, preventing all replicas from landing on the same node or AZ.

Without TSC, the Kubernetes scheduler may place all 3 replicas of a service on the same node — if that node is terminated by Karpenter, all replicas go down simultaneously despite having a PDB.

With TSC, replicas are spread across different AZs so a single node or AZ failure only affects a fraction of the pods. This works in combination with PDB (which limits eviction rate) and HPA (which maintains the desired replica count).

---

## Topic 04: Terraform Project Structure

Day 16 combines the EKS + Karpenter infrastructure from Day-15 with the AWS data plane from Day-13 into a single Terraform project:

```
Terraform-files/
├── vpc/            # VPC, subnets
├── eks/            # EKS cluster, node group, add-ons (including Metrics Server)
├── iam/            # IAM roles — cluster, node group, LBC, EBS CSI, Karpenter controller & node
├── catalog/        # RDS MySQL security group + IAM role + Pod Identity Association
├── cart/           # DynamoDB table + IAM role + Pod Identity Association
├── checkout/       # ElastiCache Redis cluster + security group
├── orders/         # RDS PostgreSQL security group + SQS queue + IAM role + Pod Identity Association
├── main.tf
├── data.tf
├── helm-install.tf               # LBC, CSI Driver, ASCP, Karpenter Helm releases
├── karpenter-sqs-eventbridge.tf  # SQS queue + EventBridge rules
├── providers.tf
├── variables.tf
├── outputs.tf
└── terraform.tfvars
```

---

## Topic 05: K8s Manifests Structure

```
k8s_manifests_with_Data_Plane/
├── 00_Karpenter/           # EC2NodeClass, On-Demand NodePool, Spot NodePool
├── 01_secretproviderclass/ # SecretProviderClass for Catalog (MySQL) and Orders (PostgreSQL)
├── 02_RetailStore_Microservices/  # SA, ConfigMap, Deployment, Service per microservice
│   ├── 01_catalog/
│   ├── 02_cart/
│   ├── 03_checkout/
│   ├── 04_orders/
│   └── 05_ui/
├── 03_ingress/             # HTTP ALB Ingress (IP mode)
├── 04_HPA/                 # HPA per microservice (CPU 70%, memory 80%, min 3 / max 8)
└── 05_PDB/                 # PDB per microservice (minAvailable: 2)
```

---

## Lab Implementation

### 1. Provision Infrastructure (Terraform)

Provisioned the full stack — EKS cluster with Karpenter, all add-ons, and all AWS data plane services — in a single `terraform apply`:

```bash
cd Terraform-files

terraform init
terraform validate
terraform plan
terraform apply -auto-approve

terraform output
terraform state list
```

![All add-on pods running in kube-system](images/Screenshot%202026-05-26%20225700.png)

![Terraform output — data plane endpoints](images/Screenshot%202026-05-26%20225723.png)

![EKS cluster provisioned and nodes ready](images/Screenshot%202026-05-26%20225622.png)

Configured kubectl and verified the cluster and all add-on pods:

```bash
aws eks update-kubeconfig --region ap-south-1 --name chirag-eks-cluster

kubectl get nodes
kubectl get pods -n kube-system
```

![EC2NodeClass and NodePools created](images/Screenshot%202026-05-26%20230919.png)

![NodePools active and ready](images/Screenshot%202026-05-26%20231030.png)

---

### 2. Deploy Karpenter CRDs

Deployed the EC2NodeClass and both NodePools so Karpenter is ready to provision nodes when pods become unschedulable:

```bash
kubectl apply -f 00_Karpenter/

kubectl get ec2nodeclass
kubectl get nodepool
```


---

### 3. Deploy SecretProviderClass & Microservices

Deployed the SecretProviderClass resources first (required before Catalog and Orders pods start), then all 5 microservices and the Ingress:

```bash
kubectl apply -f 01_secretproviderclass/
kubectl apply -R -f 02_RetailStore_Microservices/
kubectl apply -f 03_ingress/

kubectl get all,ingress,secretproviderclass
```

![All microservices deployed and running](images/Screenshot%202026-05-26%20231159.png)

![Ingress created — ALB DNS assigned](images/Screenshot%202026-05-26%20231231.png)

![Application accessible via ALB DNS](images/Screenshot%202026-05-26%20232123.png)

![Topology endpoint — all 5 services healthy](images/Screenshot%202026-05-26%20232159.png)

---

### 4. Deploy HPA & PDB

Deployed HPA and PDB for all 5 microservices. Each HPA targets CPU at 70% and memory at 80%, with a minimum of 3 replicas and a maximum of 8:

```bash
kubectl apply -f 04_HPA/
kubectl apply -f 05_PDB/

kubectl get hpa,pdb
```

![HPA and PDB deployed — metrics showing unknown](images/Screenshot%202026-05-26%20232938.png)

---

### 5. Fix Metrics Server — HPA Showing Unknown

`kubectl get hpa` showed `<unknown>` for all metrics because the Metrics Server add-on was not installed. Updated the Terraform EKS add-ons configuration to include the Metrics Server and re-applied:

```bash
# After updating Terraform to add Metrics Server addon
terraform apply -auto-approve

# Verify Metrics Server is running
kubectl get pods -n kube-system | grep metrics-server

# Verify HPA now shows real metrics
kubectl get hpa
```

![Metrics Server installed — HPA metrics now visible](images/Screenshot%202026-05-26%20233438.png)

![HPA scaling orders pods — memory above 80%](images/Screenshot%202026-05-26%20235847.png)

---

### 6. Fix Orders HPA — Resource Requests Too Low

Immediately after Metrics Server was installed, HPA started scaling the Orders pods because memory utilisation was above 80%. The root cause was that the resource requests in the Orders deployment were set too low relative to actual consumption.

Updated the resource requests in the Orders deployment manifest to better reflect actual usage and redeployed:

```bash
kubectl apply -f 02_RetailStore_Microservices/04_orders/03_orders_deployment.yaml

# Watch HPA scale back down
kubectl get hpa -w
kubectl get pods -w
```

![Orders deployment updated — memory utilisation normalised](images/Screenshot%202026-05-27%20000936.png)

![HPA scaled orders pods back down](images/Screenshot%202026-05-27%20001750.png)

![All HPAs stable — within thresholds](images/Screenshot%202026-05-27%20001831.png)

![All pods healthy after HPA stabilisation](images/Screenshot%202026-05-27%20001849.png)

---

### 7. Validate Application & Data Plane

Placed a dummy order to validate the full end-to-end flow and verified data was flowing correctly through each backing AWS service:

```bash
kubectl get all,ingress,hpa,pdb
# http://ALB_DNS_NAME/
# http://ALB_DNS_NAME/topology
```

- Added items to cart → verified entries in **DynamoDB** table
- Placed an order → verified message in **SQS** queue → verified order stored in **PostgreSQL** RDS
- Checked **ElastiCache Redis** for checkout session data
- Verified **MySQL RDS** catalog data accessible

![Retail store UI — order placed successfully](images/Screenshot%202026-05-27%20002007.png)

![DynamoDB — cart items stored](images/Screenshot%202026-05-27%20002250.png)

![SQS queue — order messages received](images/Screenshot%202026-05-27%20005704.png)

![PostgreSQL RDS — orders stored](images/Screenshot%202026-05-27%20005826.png)

---

### 8. Part 2 — Deploy via Helm

Cleaned up the manually deployed resources and redeployed the entire application using Helm charts, demonstrating how the same workload can be managed as Helm releases:

```bash
# Cleanup manual deployment
kubectl delete -f 01_secretproviderclass/ -f 03_ingress/ -R -f 02_RetailStore_Microservices/ -f 04_HPA/ -f 05_PDB/

kubectl get all,ingress,secret,pdb,hpa,cm
```

```bash
cd Helm_Data_Plane/02_retailstore_values_HELM_aws_dataplane

# Install all microservice Helm charts via script
chmod +x 04_v2.0.0-install-local-helm-charts.sh
./04_v2.0.0-install-local-helm-charts.sh

# Verify
helm list
kubectl get pods
kubectl get hpa,pdb,ingress
```

![Helm releases installed — all microservices](images/Screenshot%202026-05-27%20010443.png)

![All pods running via Helm](images/Screenshot%202026-05-27%20010733.png)

![HPA and PDB active via Helm deployment](images/Screenshot%202026-05-27%20012039.png)

![Application accessible via ALB — Helm deployment](images/Screenshot%202026-05-27%20012115.png)

![Topology — all services healthy via Helm](images/Screenshot%202026-05-27%20012151.png)

![Helm release details](images/Screenshot%202026-05-27%20012304.png)

![Karpenter nodes provisioned for Helm workload](images/Screenshot%202026-05-27%20012431.png)

![NodeClaims active](images/Screenshot%202026-05-27%20012510.png)

![HPA scaling activity](images/Screenshot%202026-05-27%20012722.png)

![All HPAs stable — Helm deployment](images/Screenshot%202026-05-27%20012936.png)

---

### 9. Cleanup

Uninstalled all Helm releases, then destroyed all Terraform-managed infrastructure:

```bash
chmod +x 01-uninstall-retail-apps.sh
./01-uninstall-retail-apps.sh

helm list
kubectl get pods
```

```bash
cd Terraform-files
terraform destroy -auto-approve
terraform state list
```

![Helm releases uninstalled](images/Screenshot%202026-05-27%20013112.png)

![Terraform destroy complete](images/Screenshot%202026-05-27%20013219.png)

![All AWS resources cleaned up](images/Screenshot%202026-05-27%20014520.png)

---

## Summary

Day 16 brought together HPA, PDB, Topology Spread Constraints, Karpenter, and the full AWS data plane into a production-grade autoscaling setup, then demonstrated deploying the same workload via Helm.

- **HPA** — scales pod replicas based on CPU/memory metrics; requires the Metrics Server add-on; scale-up is aggressive (`selectPolicy: Max`), scale-down is conservative (5-minute stabilisation window) to prevent flapping
- **Metrics Server** — must be installed as an EKS add-on for HPA to function; without it `kubectl get hpa` shows `<unknown>` for all metrics
- **Resource requests accuracy** — HPA calculates utilisation as `actual usage / requested`; if requests are set too low, HPA will constantly scale up even under normal load — always set requests to reflect real consumption
- **PDB** — limits simultaneous pod evictions during voluntary disruptions; `minAvailable: 2` ensures at least 2 pods stay running during Karpenter consolidation or rolling updates
- **Topology Spread Constraints** — distributes replicas evenly across nodes and AZs; prevents all replicas landing on the same node, which would make PDB ineffective
- **HPA + Karpenter** — two-level autoscaling: HPA manages pod count, Karpenter manages node count; they work together automatically with no additional configuration
- **Helm deployment** — the same workload (microservices + HPA + PDB + Ingress) can be packaged and deployed as Helm releases, making upgrades, rollbacks, and environment management significantly simpler than raw `kubectl apply`
