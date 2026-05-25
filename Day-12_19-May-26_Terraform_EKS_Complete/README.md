# Day 12 — Terraform EKS Cluster with Add-Ons

## Overview

Day 12 is the Terraform automation of everything that was set up manually across the previous days (Day-05 through Day-10). The same EKS cluster, node group, IAM roles, add-ons, and Helm releases are now fully codified into reusable Terraform modules — no manual AWS console or CLI steps required.

The goal is a single `terraform apply` that produces a fully operational EKS cluster with all required add-ons ready for application deployment.

---

## Topic 01: Project Structure

The Terraform project is organised into three child modules called from a root module, keeping each concern cleanly separated:

```
Terraform-files/
├── vpc/            # VPC, subnets, internet gateway, route tables
├── eks/            # EKS cluster, node group, add-ons, Pod Identity Associations
├── iam/            # All IAM roles and policies for the cluster and add-ons
├── main.tf         # Root module — wires all three child modules together
├── data.tf         # Data sources (VPC lookup, IAM policy document for trust policy)
├── helm-install.tf # Helm releases for AWS Load Balancer Controller, CSI Driver, ASCP
├── providers.tf    # AWS, Helm providers
├── variables.tf
├── outputs.tf
└── terraform.tfvars
```

---

## Topic 02: EKS Cluster Configuration

The EKS cluster is configured with a few deliberate security and operational choices:

- **API server access** — Public access is enabled but restricted to a specific IP CIDR (`my_ip_cidr`), so the Kubernetes API is not open to the entire internet
- **Private access** — Also enabled so nodes and pods inside the VPC can reach the API server without going over the public internet
- **Authentication mode** — Set to `API_AND_CONFIG_MAP`, supporting both the newer EKS Access Entries API and the legacy `aws-auth` ConfigMap
- **`bootstrap_cluster_creator_admin_permissions = true`** — Automatically grants the IAM identity that runs `terraform apply` cluster admin access, so `kubectl` works immediately after provisioning without any extra access entry setup
- **Control plane logging** — All five log types (`api`, `audit`, `authenticator`, `controllerManager`, `scheduler`) are enabled and sent to CloudWatch

---

## Topic 03: Node Group Configuration

The managed node group is configured with:

- **Instance type** — Defined via variable, defaulting to a general-purpose type suitable for the bootcamp workloads
- **AMI type** — `AL2023_x86_64_STANDARD` (Amazon Linux 2023, the current recommended EKS AMI)
- **Capacity type** — `ON_DEMAND` for reliability during lab work
- **Scaling** — Desired: 2, Min: 1, Max: 3
- **Rolling update** — `max_unavailable_percentage = 33` ensures at most one-third of nodes are unavailable during a node group version update

---

## Topic 04: IAM Module

All IAM resources are grouped in the `iam/` module with one file per role:

| File | Role | Policy |
|---|---|---|
| `eks-cluster-iam-role.tf` | EKS cluster service role | `AmazonEKSClusterPolicy` |
| `node-groups-iam-role.tf` | Node group instance role | `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly` |
| `alb-controller-role.tf` | AWS Load Balancer Controller | Custom ALB controller IAM policy (fetched via HTTP data source) |
| `ebs-csi-role.tf` | EBS CSI Driver | `AmazonEBSCSIDriverPolicy` (AWS managed) |

All add-on roles use the same **Pod Identity trust policy** — a shared `data.aws_iam_policy_document` that allows `pods.eks.amazonaws.com` to assume the role via `sts:AssumeRole` and `sts:TagSession`.

---

## Topic 05: EKS Add-Ons & Pod Identity Associations

The `eks/eks-addons.tf` file installs the EKS managed add-ons and creates the Pod Identity Associations that link each add-on's IAM role to its Kubernetes ServiceAccount:

| Add-On | Install Method | ServiceAccount | Namespace |
|---|---|---|---|
| **Pod Identity Agent** | `aws_eks_addon` | — | `kube-system` |
| **EBS CSI Driver** | `aws_eks_addon` | `ebs-csi-controller-sa` | `kube-system` |
| **AWS Load Balancer Controller** | Helm (`helm-install.tf`) | `alb-controller-sa` | `kube-system` |
| **Secrets Store CSI Driver** | Helm (`helm-install.tf`) | — | `kube-system` |
| **ASCP** | Helm (`helm-install.tf`) | — | `kube-system` |

The Pod Identity Agent add-on must be installed before any Pod Identity Association is created — this is enforced via `depends_on` in the Terraform resources.

---

## Topic 06: Helm Releases via Terraform

The `helm-install.tf` file manages three Helm releases using the Terraform Helm provider, passing the same configuration values that were used during the manual Day-10 installation:

- **AWS Load Balancer Controller** — `clusterName`, `vpcId`, `region`, and `serviceAccount.name` are all passed as `set` blocks; the VPC ID is read from a `data.aws_vpc` data source rather than hardcoded
- **Secrets Store CSI Driver** — `syncSecret.enabled = true` and the Pod Identity audience token are set to match the Day-08 manual configuration
- **ASCP** — Installed as a separate Helm release with `secrets-store-csi-driver.install = false` to avoid installing the CSI driver a second time

All three Helm releases have `depends_on = [module.eks_cluster]` to ensure the cluster and node group are fully ready before Helm attempts to connect.

---

## Summary

Day 12 codified the entire EKS cluster setup from previous days into a single Terraform project, making the cluster fully reproducible with one command.

- **Module separation** — VPC, EKS, and IAM are split into child modules so each concern can be read, tested, and reused independently
- **`bootstrap_cluster_creator_admin_permissions`** — Eliminates the manual step of creating an access entry after cluster creation; the Terraform executor gets cluster admin automatically
- **Shared Pod Identity trust policy** — A single `data.aws_iam_policy_document` is reused across all add-on IAM roles, keeping the trust policy consistent and DRY
- **Helm via Terraform** — The AWS Load Balancer Controller, CSI Driver, and ASCP are installed as `helm_release` resources in the same `terraform apply`, so the cluster is fully operational immediately after provisioning
- **`depends_on` ordering** — Pod Identity Agent must be active before Pod Identity Associations are created; node group must be ready before add-ons are installed; these dependencies are explicitly declared in Terraform to prevent race conditions
