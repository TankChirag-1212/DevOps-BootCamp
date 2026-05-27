# Day 15 — Karpenter: Kubernetes Cluster Autoscaling on EKS

## Topic 01: What is Karpenter?

**Karpenter** is an open-source, high-performance Kubernetes cluster autoscaler built specifically for AWS EKS. It watches for **unschedulable pods** and directly provisions EC2 instances to satisfy them — without needing pre-configured Auto Scaling Groups (ASGs).

### Karpenter vs Cluster Autoscaler

| Feature | Karpenter | Cluster Autoscaler |
|---|---|---|
| **Provisioning speed** | 30–60 seconds | 2–5 minutes |
| **Instance selection** | Intelligent — picks optimal type via bin-packing | Limited to predefined node groups |
| **Consolidation** | Automatic, configurable | Manual or slow |
| **Spot support** | Native, with interruption handling | Basic |
| **ASG dependency** | None — direct EC2 API | Required |

### Provisioning Flow

```
Unschedulable pod detected
        ↓
Karpenter analyzes pod requirements (CPU, memory, nodeSelector, affinity)
        ↓
Selects optimal EC2 instance type
        ↓
Launches EC2 instance directly via AWS API
        ↓
Node joins cluster in 30–60 seconds
        ↓
Pod scheduled on new node
```

---

## Topic 02: Terraform Project Structure

The Karpenter Terraform project extends the Day-12 EKS cluster setup by adding Karpenter-specific IAM roles, SQS queue, EventBridge rules, and the Helm release:

```
Terraform-files/
├── vpc/                          # VPC, subnets, route tables
├── eks/                          # EKS cluster, node group, add-ons, Pod Identity Associations
├── iam/                          # All IAM roles — adds karpenter-controller-role and karpenter-node-iam-role
├── main.tf                       # Root module
├── data.tf                       # Karpenter controller IAM policy document
├── karpenter-sqs-eventbridge.tf  # SQS interruption queue + 4 EventBridge rules
├── helm-install.tf               # Karpenter Helm release alongside LBC, CSI, ASCP
├── providers.tf
├── variables.tf
├── outputs.tf
└── terraform.tfvars
```

---

## Topic 03: IAM Roles for Karpenter

Karpenter requires two separate IAM roles with distinct purposes:

### Controller Role (`karpenter-controller-role`)

Used by the Karpenter controller pod itself. Grants permissions to call EC2, SQS, and IAM APIs to provision and manage nodes. Linked to the `karpenter-sa` Kubernetes ServiceAccount via a Pod Identity Association.

### Node Role (`karpenter-node-role`)

Assigned to every EC2 instance that Karpenter launches, so the node can join the EKS cluster. Attaches four AWS managed policies:

| Policy | Purpose |
|---|---|
| `AmazonEKSWorkerNodePolicy` | Allows node to register with the EKS cluster |
| `AmazonEKS_CNI_Policy` | Allows the VPC CNI plugin to manage pod networking |
| `AmazonEC2ContainerRegistryPullOnly` | Allows pulling container images from ECR |
| `AmazonSSMManagedInstanceCore` | Enables SSM Session Manager access to nodes |

The node role ARN is referenced directly in the `EC2NodeClass` manifest so Karpenter knows which role to assign when launching instances.

---

## Topic 04: SQS & EventBridge for Spot Interruption Handling

Karpenter handles Spot interruptions gracefully by polling an SQS queue that receives events from EventBridge. Four EventBridge rules route AWS events into the queue:

| EventBridge Rule | Event | Purpose |
|---|---|---|
| `k-spot` | EC2 Spot Instance Interruption Warning | 2-minute notice before Spot reclaim |
| `k-rebal` | EC2 Instance Rebalance Recommendation | Early warning before potential interruption |
| `k-state` | EC2 Instance State-change Notification | Instance stopping or terminating |
| `k-health` | AWS Health Event | AWS-scheduled maintenance events |

When Karpenter detects an interruption warning, it **proactively provisions a replacement node before draining the old one** — this is what enables zero-downtime Spot migrations.

---

## Topic 05: Karpenter Core Kubernetes Resources

Karpenter introduces two custom resource definitions (CRDs):

### EC2NodeClass — Node Template

Defines **how** nodes are provisioned — AMI, subnets, security groups, disk, and metadata options. The `role` field references the Node IAM role ARN. `httpTokens: required` enforces IMDSv2 on all Karpenter-launched nodes. EBS volumes are configured as `gp3`, 20Gi, encrypted.

### NodePool — Scaling Policy

Defines **what** nodes to provision. Key fields:

- `nodeClassRef` — links the NodePool to its EC2NodeClass
- `requirements` — label-based constraints on arch, OS, capacity type, instance family, instance size, and AZ
- `limits.cpu` — cluster-wide cap on total CPU Karpenter can provision; prevents runaway scaling costs
- `disruption.consolidationPolicy: WhenEmptyOrUnderutilized` — consolidates nodes that are empty or can be packed onto fewer nodes
- `disruption.consolidateAfter: 30s` — how long Karpenter waits after detecting underutilization before acting

### On-Demand NodePool vs Spot NodePool

| | On-Demand NodePool | Spot NodePool |
|---|---|---|
| `capacity-type` | `on-demand` | `spot` |
| Instance families | `t3`, `t3a` | `t3`, `t3a`, `t2`, `c5a`, `c6a` |
| Instance sizes | `micro` to `large` | `micro` to `large` |

The Spot NodePool intentionally specifies more instance families — Spot capacity fluctuates by instance type and AZ, so wider diversity means Karpenter can always find available capacity.

### NodeClaim — Individual Node Request

Auto-created by Karpenter (never written manually). Each NodeClaim represents one EC2 instance being provisioned. Created when pods are unschedulable, deleted when nodes are consolidated or terminated.

---

## Topic 06: Critical Subnet Tag

Subnets used by Karpenter must be tagged with `owned`, not `shared`:

- `shared` → EKS control plane can use the subnet, but **Karpenter cannot launch nodes into it**
- `owned` → Full access for Karpenter, managed node groups, and the control plane

This is the most common misconfiguration when setting up Karpenter.

---

## Lab Implementation

### 1. Provision EKS Cluster with Karpenter (Terraform)

Provisioned the full infrastructure — VPC, EKS cluster, add-ons, IAM roles, SQS queue, EventBridge rules, and Karpenter Helm release — in a single `terraform apply`:

```bash
cd Day-15_22-May-26_Karpenter/Terraform-files

terraform init
terraform validate
terraform plan
terraform apply -auto-approve

terraform output
```

Configured kubectl and verified all add-ons and the Karpenter controller pod were running:

```bash
aws eks update-kubeconfig --region ap-south-1 --name chirag-eks-cluster

kubectl get nodes
kubectl get pods -n kube-system
```

![EKS cluster nodes and Karpenter controller running](images/Screenshot%202026-05-26%20230919.png)

---

### 2. Deploy EC2NodeClass & NodePools

Deployed the three Karpenter CRD manifests to configure how and what nodes Karpenter should provision:

```bash
kubectl apply -f k8s-manifests/ec2-node-class.yaml
kubectl apply -f k8s-manifests/node-pool-ondemand.yaml
kubectl apply -f k8s-manifests/node-pool-spot.yaml

# Verify
kubectl get ec2nodeclass
kubectl get nodepool
```

![EC2NodeClass and NodePools created](images/Screenshot%202026-05-26%20231030.png)

---

### 3. Test On-Demand Autoscaling

Deployed a test workload to trigger Karpenter node provisioning. The deployment creates 5 pods each requesting 500m CPU and 256Mi memory, with a `nodeSelector` forcing them onto On-Demand nodes:

```bash
kubectl apply -f k8s-manifests/test-deployment.yaml
```

Watched Karpenter detect the unschedulable pods, create NodeClaims, and provision new EC2 instances:

```bash
# Watch NodeClaims being created
kubectl get nodeclaims

# Watch new nodes joining the cluster
kubectl get nodes

# Verify pods scheduled on Karpenter nodes
kubectl get pods
```

Karpenter selected the optimal instance type based on the combined resource requests (5 × 500m CPU = 2.5 vCPU needed) and provisioned nodes in approximately 30–60 seconds.

![NodeClaims created and pods scheduled on Karpenter nodes](images/Screenshot%202026-05-26%20232123.png)

---

### 4. Cleanup

Deleted all Kubernetes resources first — Karpenter automatically terminates the EC2 instances it provisioned when the NodePools and NodeClaims are removed:

```bash
kubectl delete -f k8s-manifests/

# Verify nodes and Karpenter resources are gone
kubectl get nodes
kubectl get pods
kubectl get ec2nodeclass
kubectl get nodepool
kubectl get nodeclaims
```

Then destroyed all Terraform-managed infrastructure:

```bash
terraform destroy -auto-approve

# Verify no resources remain
terraform state list
```

---

## Summary

Day 15 focused on Karpenter — a modern, intelligent cluster autoscaler that replaces the traditional Cluster Autoscaler for EKS workloads.

- **Karpenter vs Cluster Autoscaler** — Karpenter provisions nodes in 30–60 seconds (vs 2–5 minutes), selects optimal instance types via bin-packing, and requires no pre-configured ASGs
- **Two IAM roles** — the controller role grants Karpenter permission to call AWS APIs; the node role is assigned to every EC2 instance Karpenter launches so it can join the cluster
- **SQS + EventBridge** — four EventBridge rules route Spot interruption warnings, rebalance recommendations, state changes, and health events into an SQS queue that Karpenter polls for proactive interruption handling
- **EC2NodeClass** — defines how nodes are provisioned (AMI, subnets, security groups, disk, IMDSv2); the node role ARN is referenced here
- **NodePool** — defines what nodes to provision (instance families, sizes, capacity type, AZ constraints, CPU limits, consolidation policy); separate NodePools for On-Demand and Spot
- **Spot instance diversity** — Spot NodePools should specify wider instance family/size ranges to maximise availability across fluctuating Spot capacity pools
- **`owned` subnet tag** — subnets must be tagged `owned` (not `shared`) for Karpenter to launch nodes into them; the most common setup mistake
