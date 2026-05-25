# Day 15 — Karpenter: Kubernetes Cluster Autoscaling on EKS

## Topic 01: What is Karpenter?

**Karpenter** is an open-source, high-performance Kubernetes cluster autoscaler built specifically for AWS EKS. It watches for **unschedulable pods** and directly provisions EC2 instances to satisfy them — without needing pre-configured Auto Scaling Groups (ASGs).

### Karpenter vs Cluster Autoscaler

| Feature | Karpenter | Cluster Autoscaler |
|---|---|---|
| **Provisioning speed** | 30–60 seconds | 2–5 minutes |
| **Instance selection** | Intelligent — picks optimal type | Limited to predefined node groups |
| **Consolidation** | Automatic, configurable | Manual or slow |
| **Spot support** | Native, with interruption handling | Basic |
| **ASG dependency** | None — direct EC2 API | Required |

The traditional Cluster Autoscaler scales based on node groups — you must pre-define instance types and sizes upfront. Karpenter eliminates this constraint entirely by calling the EC2 API directly and selecting the optimal instance type based on actual pod resource requests.

### Provisioning Flow

```
Unschedulable Pod detected
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

## Topic 02: Terraform Setup — Supporting AWS Resources

Karpenter requires several AWS resources beyond the EKS cluster itself. These are provisioned via Terraform alongside the Helm install:

| Resource | Purpose |
|---|---|
| **SQS Queue** | Receives Spot interruption and EC2 lifecycle events from EventBridge |
| **EventBridge Rules** | Routes AWS events (Spot warnings, rebalance, state changes, health events) to the SQS queue |
| **IAM Role (Controller)** | Allows Karpenter to call EC2, SQS, and IAM APIs to provision and manage nodes |
| **IAM Role (Node)** | Assigned to EC2 instances that Karpenter launches, so they can join the cluster |
| **Pod Identity Association** | Maps Karpenter's `karpenter-sa` ServiceAccount to the controller IAM role |

### EventBridge Rules

Four EventBridge rules route events into the Karpenter SQS queue:

- **EC2 Spot Instance Interruption Warning** — 2-minute notice before a Spot instance is reclaimed
- **EC2 Instance Rebalance Recommendation** — early warning before a potential interruption
- **EC2 Instance State-change Notification** — instance stopping or terminating
- **AWS Health Event** — AWS-scheduled maintenance events

### Critical Subnet Tag

Subnets used by Karpenter must be tagged with `owned`, not `shared`:

- `shared` → EKS control plane can use the subnet, but **Karpenter cannot launch nodes into it**
- `owned` → Full access for Karpenter, managed node groups, and the control plane

This is the most common misconfiguration when setting up Karpenter — always use `owned`.

---

## Topic 03: Karpenter Core Kubernetes Resources

Karpenter introduces two custom resource definitions (CRDs) that replace the concept of node groups:

### EC2NodeClass — Node Template

Defines **how** nodes are provisioned — the AMI, subnets, security groups, disk configuration, and metadata options. Think of it as the launch template for Karpenter-managed nodes.

Key fields:
- `amiFamily: AL2023` — uses Amazon Linux 2023, the current recommended EKS AMI
- `role` — the Node IAM role ARN assigned to every EC2 instance Karpenter launches
- `subnetSelectorTerms` — which subnets Karpenter can launch nodes into (selected by ID or tags)
- `securityGroupSelectorTerms` — security groups applied to launched nodes, selected by cluster tag
- `blockDeviceMappings` — EBS root volume config; `gp3`, 20Gi, `encrypted: true` is the recommended baseline
- `metadataOptions.httpTokens: required` — enforces IMDSv2 on all Karpenter-launched nodes

### NodePool — Scaling Policy

Defines **what** nodes to provision — instance families, sizes, capacity type (On-Demand or Spot), AZ constraints, cluster-wide CPU limits, and consolidation behaviour.

Key fields:
- `nodeClassRef` — links the NodePool to its EC2NodeClass
- `requirements` — a list of label-based constraints (arch, OS, capacity type, instance family, instance size, AZ)
- `limits.cpu` — cluster-wide cap on total CPU Karpenter can provision; prevents runaway scaling costs
- `disruption.consolidationPolicy` — `WhenEmptyOrUnderutilized` consolidates nodes that are empty or can be packed onto fewer nodes; `WhenEmpty` only consolidates fully empty nodes
- `disruption.consolidateAfter` — how long Karpenter waits after detecting underutilization before acting

### NodeClaim — Individual Node Request

Auto-created by Karpenter (never written manually). Each NodeClaim represents one EC2 instance being provisioned. They are created when pods are unschedulable and deleted when nodes are consolidated or terminated.

---

## Topic 04: On-Demand Autoscaling

When pods are created with resource requests that exceed available cluster capacity, Karpenter detects them as unschedulable and provisions new On-Demand nodes to fit them.

Karpenter uses **intelligent bin-packing** — it picks the smallest instance type that satisfies the combined resource requests of all pending pods, not the largest available. This is something the Cluster Autoscaler cannot do.

### Scale-Down & Consolidation

When pods are scaled down and nodes become underutilized, Karpenter:

1. Waits for `consolidateAfter` duration (e.g. 30s)
2. Cordons the node (marks it unschedulable for new pods)
3. Drains the node (evicts pods gracefully, respecting PodDisruptionBudgets)
4. Reschedules evicted pods onto remaining nodes
5. Terminates the EC2 instance and deletes the NodeClaim

To force pods onto On-Demand nodes specifically, add a `nodeSelector` to the pod spec:

```yaml
nodeSelector:
  karpenter.sh/capacity-type: on-demand
```

---

## Topic 05: Spot Instances

Spot instances are spare AWS compute capacity available at up to **70% discount** compared to On-Demand pricing. The trade-off is that AWS can reclaim them with a **2-minute warning** when On-Demand demand increases.

### Spot NodePool vs On-Demand NodePool

The Spot NodePool uses `karpenter.sh/capacity-type: spot` in its requirements and intentionally specifies a **wider range of instance families and sizes**:

```
On-Demand NodePool: t3, t3a — 2 families
Spot NodePool:      t3, t3a, t2, c5a, c6a — 5 families, micro to large
```

More instance diversity is critical for Spot — Spot capacity fluctuates by instance type and AZ. A wider selection means Karpenter can always find available capacity and avoids `InsufficientInstanceCapacity` errors.

To force pods onto Spot nodes:

```yaml
nodeSelector:
  karpenter.sh/capacity-type: spot
```

### When to Use Spot vs On-Demand

| Use Case | Recommended |
|---|---|
| Production databases / stateful workloads | On-Demand |
| Stateless web apps with 3+ replicas | Spot ✅ |
| Single-replica critical services | On-Demand |
| CI/CD pipelines | Spot ✅ |
| Batch processing | Spot ✅ |
| Dev/test environments | Spot ✅ |

---

## Topic 06: Spot Interruption Handling

When AWS decides to reclaim a Spot instance, it sends a 2-minute warning. Without proper handling, pods get hard-killed and the service goes down. Karpenter handles this gracefully using the SQS queue set up in Terraform.

### Interruption Flow

```
T=0s:   AWS sends interruption warning → EventBridge → SQS queue
T=~10s: Karpenter polls SQS, detects the message
T=~10s: Karpenter cordons the node (stops new pod scheduling)
T=~10s: Karpenter provisions a REPLACEMENT node PROACTIVELY ← key
T=~50s: New node joins the cluster
T=~50s: Karpenter drains the old node (respects PodDisruptionBudgets)
T=~60s: Pods rescheduled to new node
T=120s: Old instance terminates
```

The critical insight is that Karpenter starts provisioning the **replacement node before draining the old one**. This proactive approach is what enables zero downtime during interruptions.

---

## Topic 07: PodDisruptionBudget — Zero Downtime on Spot

A **PodDisruptionBudget (PDB)** is a Kubernetes resource that limits how many pods of a deployment can be unavailable at the same time during voluntary disruptions (like node drains).

Without a PDB, Karpenter drains a node by evicting all pods at once — causing a service outage until they reschedule. With a PDB, Karpenter is forced to evict pods gradually, keeping a minimum number running throughout.

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: my-app-pdb
spec:
  minAvailable: 3
  selector:
    matchLabels:
      app: my-app
```

**Without PDB:** All 5 pods evicted simultaneously → 0/5 running → service down for ~40 seconds

**With PDB (`minAvailable: 3`):** Karpenter can only evict 2 pods at a time → 3/5 still running → service stays up throughout the migration

### terminationGracePeriodSeconds

Setting `terminationGracePeriodSeconds: 30` on pods gives them time to stop accepting connections, complete in-flight requests, close database connections, and flush logs before being force-killed. This should be kept under 90 seconds to leave buffer before AWS force-terminates the instance at the 120-second mark.

### The Production Formula

```
Karpenter + PodDisruptionBudget + terminationGracePeriodSeconds
= 70% cost savings + zero downtime
```

---

## Topic 08: Terraform Project Structure

The Karpenter Terraform project extends the Day-12 structure by adding Karpenter-specific resources:

```
Terraform-files/
├── vpc/                          # VPC and subnet configuration
├── eks/                          # EKS cluster, node group, add-ons, Pod Identity Associations
│   └── eks-addons.tf             # Includes Karpenter Pod Identity Association
├── iam/                          # IAM roles — adds karpenter-controller-role and karpenter-node-role
├── main.tf                       # Root module — passes Karpenter role ARNs to eks module
├── karpenter-sqs-eventbridge.tf  # SQS queue + 4 EventBridge rules
├── helm-install.tf               # Karpenter Helm release added alongside LBC, CSI, ASCP
├── data.tf                       # Karpenter controller IAM policy document
└── terraform.tfvars
```

The Karpenter Helm release is installed via Terraform with the cluster name, cluster endpoint, and SQS queue name passed as `set` values — so Karpenter knows which cluster to manage and which queue to poll for interruption events.

---

## Summary

Day 15 focused on Karpenter — a modern, intelligent cluster autoscaler that replaces the traditional Cluster Autoscaler for EKS workloads.

- **Karpenter vs Cluster Autoscaler** — Karpenter provisions nodes in 30–60 seconds (vs 2–5 minutes), selects optimal instance types via bin-packing, and requires no pre-configured ASGs
- **EC2NodeClass** — defines how nodes are provisioned (AMI, subnets, security groups, disk, IMDSv2); one class can be shared across multiple NodePools
- **NodePool** — defines what nodes to provision (instance families, sizes, capacity type, AZ constraints, CPU limits, consolidation policy); separate NodePools for On-Demand and Spot
- **Spot instances** — up to 70% cheaper than On-Demand; Spot NodePools should specify wider instance family/size diversity to maximise availability
- **Interruption handling** — Karpenter polls an SQS queue (fed by EventBridge rules) for Spot interruption warnings and proactively provisions a replacement node before draining the old one
- **PodDisruptionBudget** — essential for zero-downtime Spot usage; limits how many pods can be evicted at once during node drains, keeping the service available throughout the migration
- **`owned` subnet tag** — subnets must be tagged `owned` (not `shared`) for Karpenter to launch nodes into them; this is the most common setup mistake
