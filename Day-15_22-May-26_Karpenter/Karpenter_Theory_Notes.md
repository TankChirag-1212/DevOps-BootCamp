# 🚀 Section 17: Autoscaling with Karpenter — Theory Notes

---

## 1. What is Karpenter and Why Use It?

Karpenter is an open-source, high-performance Kubernetes cluster autoscaler built specifically for AWS EKS. It watches for **unschedulable pods** and directly provisions EC2 instances to satisfy them — without needing pre-configured Auto Scaling Groups (ASGs).

### Problems with Traditional Cluster Autoscaler
- Scales based on **node groups** (ASGs) — you must pre-define instance types
- Provisioning takes **2–5 minutes** (ASG launch + node join)
- No intelligent bin-packing — wastes capacity
- Consolidation is slow and reactive

### Why Karpenter is Better

| Feature | Karpenter | Cluster Autoscaler |
|---|---|---|
| Provisioning speed | 30–60 seconds | 2–5 minutes |
| Instance selection | Intelligent, picks optimal type | Limited to predefined node groups |
| Consolidation | Automatic, configurable | Manual or slow |
| Spot support | Native, with interruption handling | Basic |
| ASG dependency | None — direct EC2 API | Required |

### Key Capabilities
- Provisions nodes in **seconds**, not minutes
- Automatically selects the **optimal instance type** based on pod resource requests
- Supports **Spot instances** with graceful interruption handling
- **Consolidates** underutilized nodes to reduce costs
- Eliminates the need to manage Auto Scaling Groups

---

## 2. Karpenter Architecture

```
Unschedulable Pod
      ↓
Karpenter Controller (watches pod events)
      ↓
Analyzes pod requirements (CPU, memory, nodeSelector, affinity)
      ↓
Selects optimal EC2 instance type
      ↓
Launches EC2 instance directly via AWS API
      ↓
Node joins cluster (30–60 seconds)
      ↓
Pod scheduled on new node
```

### Supporting AWS Resources (set up via Terraform)
- **SQS Queue** — receives Spot interruption events
- **EventBridge Rules** — routes AWS events (Spot warnings, rebalance, etc.) to SQS
- **IAM Role (Controller)** — allows Karpenter to call EC2, SQS, IAM APIs
- **IAM Role (Node)** — assigned to EC2 instances Karpenter launches
- **Pod Identity Association** — maps Karpenter's ServiceAccount to the controller IAM role

---

## 3. Terraform Layered Architecture (3 Layers)

Karpenter setup uses a **3-layer Terraform approach** for independent lifecycle management:

```
Layer 1: VPC (01_VPC_terraform-manifests)
  └── VPC, subnets, NAT Gateway, route tables

Layer 2: EKS Cluster + Add-ons (02_EKS_terraform-manifests_with_addons)
  └── EKS cluster, managed node group, LBC, EBS CSI, External DNS, Pod Identity Agent

Layer 3: Karpenter (03_KARPENTER_terraform-manifests)
  └── Controller IAM role + policy, Node IAM role, Pod Identity Association,
      Helm install, SQS queue, EventBridge rules
```

Each layer reads the previous layer's outputs via **Terraform remote state** — no hardcoded values.

### Critical Subnet Tag — `owned` vs `shared`

```hcl
# c5_eks_tags.tf — REQUIRED for Karpenter
resource "aws_ec2_tag" "eks_subnet_tag_private_cluster" {
  value = "owned"   # Must be "owned", NOT "shared"
}
```

- `shared` → EKS control plane can use, but **Karpenter CANNOT launch nodes**
- `owned` → Full access for Karpenter, Managed Node Groups, and control plane

This is the most common mistake when setting up Karpenter — always use `owned`.

---

## 4. Karpenter Core Resources (Kubernetes CRDs)

Karpenter introduces two custom resources:

### EC2NodeClass — Node Template

Defines **how** nodes are provisioned — AMI, subnets, security groups, disk, metadata options.

```yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default-ec2nodeclass
spec:
  amiFamily: AL2023
  amiSelectorTerms:
    - alias: al2023@latest
  role: "arn:aws:iam::<account-id>:role/retail-dev-karpenter-node-role"
  subnetSelectorTerms:
    - tags:
        kubernetes.io/cluster/retail-dev-eksdemo1: owned
        kubernetes.io/role/internal-elb: "1"       # ← Private subnets only!
  securityGroupSelectorTerms:
    - tags:
        kubernetes.io/cluster/retail-dev-eksdemo1: owned
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 20Gi
        volumeType: gp3
        encrypted: true
  metadataOptions:
    httpTokens: required          # IMDSv2 enforced
    httpPutResponseHopLimit: 2
```

**Key point on subnet selection:** Adding `kubernetes.io/role/internal-elb: "1"` restricts Karpenter to **private subnets only**. Without this, Karpenter may launch nodes in public subnets (giving them public IPs — not secure). Always use this filter in production.

### NodePool — Scaling Policy

Defines **what** nodes to provision — instance types, capacity type, zones, limits, and consolidation behavior.

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: ondemand-nodepool
spec:
  template:
    spec:
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default-ec2nodeclass
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: karpenter.k8s.aws/instance-family
          operator: In
          values: ["t3", "t3a"]
        - key: karpenter.k8s.aws/instance-size
          operator: In
          values: ["micro", "small", "medium"]
        - key: topology.kubernetes.io/zone
          operator: In
          values: ["us-east-1a", "us-east-1b", "us-east-1c"]
  limits:
    cpu: "50"                              # Cluster-wide cap
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 30s
```

### NodeClaim — Individual Node Request

Auto-created by Karpenter (you don't write these). Each NodeClaim represents one EC2 instance being provisioned. Track them with:
```bash
kubectl get nodeclaims
kubectl describe nodeclaim <name>
```

---

## 5. On-Demand Autoscaling (Demo 17-02)

### Provisioning Flow

```
1. Pod created with resource requests (500m CPU, 256Mi memory)
2. Kubernetes scheduler: No capacity → Pod marked Unschedulable
3. Karpenter detects unschedulable pod
4. Karpenter calculates: 5 pods × 500m = 2.5 vCPUs needed
5. Selects 2× t3.small (2 vCPU each = 4 vCPUs total)
6. Creates NodeClaims → Launches EC2 instances
7. Nodes join cluster in ~30–60 seconds
8. Pods scheduled and Running
```

### Consolidation Flow (Scale Down)

```
1. Pods scaled down → Nodes become underutilized
2. Karpenter waits consolidateAfter: 30s
3. Cordons node (marks unschedulable)
4. Drains node (evicts pods gracefully)
5. Pods rescheduled to other nodes
6. EC2 instance terminated
7. NodeClaim deleted
```

### Key Observation
Karpenter picks the **smallest instance type** that fits the workload — not the largest. This is intelligent bin-packing that Cluster Autoscaler cannot do.

### Force Pods to On-Demand Nodes
```yaml
nodeSelector:
  karpenter.sh/capacity-type: on-demand
```

---

## 6. Spot Instances (Demo 17-03)

### What are Spot Instances?
Spare AWS compute capacity sold at steep discounts. AWS can reclaim them with a **2-minute warning** when On-Demand demand increases.

### Cost Savings

| Instance | On-Demand | Spot | Savings |
|---|---|---|---|
| t3.medium | $0.0416/hr | ~$0.0125/hr | 70% |
| c5a.large | $0.077/hr | ~$0.023/hr | 70% |
| t3a.small | $0.0188/hr | ~$0.0056/hr | 70% |

Typical savings: **50–90%**, commonly **70%** in practice.

### Spot NodePool — Key Differences from On-Demand

```yaml
requirements:
  - key: karpenter.sh/capacity-type
    operator: In
    values: ["spot"]                          # ← Spot only

  - key: karpenter.k8s.aws/instance-family
    operator: In
    values: ["t3", "t3a", "t2", "c5a", "c6a"]  # ← More families = better availability

  - key: karpenter.k8s.aws/instance-size
    operator: In
    values: ["micro", "small", "medium", "large"]  # ← Wider range
```

**Why more instance diversity for Spot?** Spot capacity fluctuates by instance type and AZ. More options = Karpenter can always find available capacity. Reduces `InsufficientInstanceCapacity` errors.

### Force Pods to Spot Nodes
```yaml
nodeSelector:
  karpenter.sh/capacity-type: spot
```

### Verify Spot Instances
```bash
# Filter nodes by capacity type
kubectl get nodes --selector=karpenter.sh/capacity-type=spot

# Check node labels
kubectl get node <node-name> -o json | jq '.metadata.labels'
# Look for: "karpenter.sh/capacity-type": "spot"
```

### When to Use Spot vs On-Demand

| Use Case | On-Demand | Spot |
|---|---|---|
| Production databases | ✅ | ❌ |
| Stateless web app (3+ replicas) | ⚠️ | ✅ |
| Single-replica critical service | ✅ | ❌ |
| CI/CD pipelines | ⚠️ | ✅ |
| Batch processing | ⚠️ | ✅ |
| Dev/test environments | ⚠️ | ✅ |

---

## 7. Spot Interruption Handling (Demo 17-04)

### The 2-Minute Warning
```
T = 0s:    AWS decides to reclaim Spot instance
T = 0s:    Interruption warning sent → EventBridge → SQS
T = 120s:  Instance terminates (no exceptions!)
```

Without proper handling: pods get hard-killed → service disruption.
With Karpenter: graceful migration with zero downtime.

### How Karpenter Handles Interruptions

```
1. AWS sends interruption warning → EventBridge → SQS Queue
2. Karpenter polls SQS every ~10 seconds, detects message
3. Karpenter cordons node (stops new pod scheduling)
4. Karpenter provisions replacement node PROACTIVELY ← key!
5. Karpenter drains node (respects PodDisruptionBudgets)
6. Kubernetes reschedules pods to new node
7. Old node terminates after pods are safely migrated
```

**Critical insight:** Karpenter starts provisioning the **new node BEFORE draining the old one**. This proactive approach is what enables zero downtime.

### EventBridge → SQS → Karpenter Flow

Karpenter handles these AWS events via SQS:
- `EC2 Spot Instance Interruption Warning` — 2-minute notice
- `EC2 Instance Rebalance Recommendation` — early warning before interruption
- `EC2 Instance State-change Notification` — instance stopping/terminating
- `EC2 Scheduled Change` — AWS maintenance events

All configured via Terraform in `c6_08_karpenter_eventbridge_rules.tf`.

### PodDisruptionBudget (PDB) — The Key to Zero Downtime

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: spot-test-app-pdb
spec:
  minAvailable: 3    # Keep at least 3 pods running at all times
  selector:
    matchLabels:
      app: spot-test
```

**Without PDB:**
```
Karpenter drains node → All 5 pods evicted immediately
→ 0/5 pods running → SERVICE DOWN for ~40 seconds ❌
```

**With PDB (minAvailable: 3):**
```
Karpenter drains node → PDB blocks: "Only evict 2, keep 3 running"
→ 3/5 pods still running → SERVICE UP ✅
New node ready → Replacement pods start
→ All 5 pods migrated → ZERO downtime ✅
```

### terminationGracePeriodSeconds

```yaml
spec:
  terminationGracePeriodSeconds: 30   # Give pods time to shut down cleanly
```

- Gives pods time to: stop accepting connections, complete in-flight requests, close DB connections, flush logs
- Must be **less than 90 seconds** — you need buffer before AWS force-terminates at 120s
- Most web servers (nginx, Spring Boot) handle SIGTERM gracefully automatically

### Interruption Handling Timeline (Real Demo)
- ⚡ Detection: 10–20 seconds (SQS polling interval)
- ⚡ New node provisioned: 30–40 seconds
- ⚡ Full pod migration: ~2–3 minutes
- ⚡ Downtime: ZERO (PDB kept 3 pods running throughout)

### The Production Formula
```
Karpenter + PodDisruptionBudget + terminationGracePeriod
= 70% Cost Savings + Zero Downtime
```

---

## 8. Disruption & Consolidation Settings

```yaml
disruption:
  consolidationPolicy: WhenEmptyOrUnderutilized   # or WhenEmpty
  consolidateAfter: 30s                           # wait before consolidating
  budgets:
    - nodes: "100%"
      reasons:
        - "Drifted"
        - "Underutilized"
        - "Empty"
```

- `WhenEmpty` — only consolidate nodes with no pods
- `WhenEmptyOrUnderutilized` — consolidate nodes that are empty OR can be packed onto fewer nodes
- `consolidateAfter` — how long Karpenter waits after detecting underutilization before acting

---

## 9. Key Commands Reference

### Karpenter Resources
```bash
kubectl get nodepools                          # list NodePools
kubectl get ec2nodeclass                       # list EC2NodeClasses
kubectl get nodeclaims                         # list active NodeClaims (one per node)
kubectl describe nodepool <name>               # NodePool details
kubectl describe nodeclaim <name>              # individual node provisioning details
```

### Nodes by Capacity Type
```bash
kubectl get nodes -l karpenter.sh/nodepool                    # all Karpenter nodes
kubectl get nodes -l karpenter.sh/capacity-type=spot          # Spot nodes only
kubectl get nodes -l karpenter.sh/capacity-type=on-demand     # On-Demand nodes only
```

### Karpenter Logs
```bash
kubectl -n kube-system logs -f -l app.kubernetes.io/name=karpenter
kubectl -n kube-system logs -f -l app.kubernetes.io/name=karpenter | grep -E "interrupt|cordon|drain"
```

### Verify Karpenter Installation
```bash
helm list -n kube-system                                       # check Helm release
kubectl get pods -n kube-system -l app.kubernetes.io/name=karpenter
helm get values karpenter -n kube-system | grep interruptionQueue
```

---

## 10. Production Best Practices

- **Always use PodDisruptionBudgets** for any production workload on Spot — `minAvailable: 2` minimum
- **Use private subnets only** — add `kubernetes.io/role/internal-elb: "1"` to EC2NodeClass subnet selector
- **Diversify instance types** in Spot NodePool — more families and sizes = better availability
- **Set terminationGracePeriodSeconds** appropriately — never exceed 90s for Spot workloads
- **Use `owned` subnet tags**, not `shared` — Karpenter cannot launch nodes in `shared` subnets
- **Mix Spot and On-Demand** for critical apps — 60% Spot + 40% On-Demand is a common pattern
- **Set NodePool CPU limits** (`limits.cpu: "50"`) to prevent runaway scaling costs
- **Use `WhenEmptyOrUnderutilized`** consolidation policy to maximize cost savings
- **Enforce IMDSv2** (`httpTokens: required`) in EC2NodeClass for security
- **Encrypt EBS volumes** (`encrypted: true`) in EC2NodeClass block device mappings

---

## 11. Section Summary

| Demo | What Was Covered |
|---|---|
| 17-01 | Karpenter installation via Terraform (3-layer architecture), EC2NodeClass, NodePool setup |
| 17-02 | On-Demand autoscaling — scale up (5→10 replicas), scale down, consolidation |
| 17-03 | Spot instances — 70% cost savings, instance diversity, verifying Spot capacity |
| 17-04 | Spot interruption handling — SQS/EventBridge flow, PDB, zero-downtime migration |

**Core takeaway:** Karpenter + Spot Instances + PodDisruptionBudgets = production-grade autoscaling with up to 70% cost savings and zero downtime.
