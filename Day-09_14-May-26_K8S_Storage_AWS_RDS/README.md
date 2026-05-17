# Day 09 — Kubernetes Persistent Storage with EBS CSI Driver

## Topic 01: Kubernetes Storage — PV, PVC & StorageClass

Kubernetes provides a storage abstraction layer to decouple application pods from the underlying storage infrastructure.

| Resource | What it does |
|---|---|
| **PersistentVolume (PV)** | A piece of storage provisioned in the cluster (e.g. an EBS volume) |
| **PersistentVolumeClaim (PVC)** | A request for storage by a pod — binds to a matching PV |
| **StorageClass** | Defines the provisioner and parameters for dynamic PV provisioning |

With **dynamic provisioning**, a PVC automatically triggers the creation of a PV (and the underlying cloud volume) without manual intervention. The `WaitForFirstConsumer` binding mode ensures the EBS volume is created in the same Availability Zone as the pod.

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-sc
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
```

---

## Topic 02: EBS CSI Driver

The **AWS EBS CSI Driver** is a Kubernetes add-on that enables EKS to dynamically provision, attach, and manage Amazon EBS volumes as PersistentVolumes.

### How It Works

1. A StatefulSet's `volumeClaimTemplates` creates a PVC per pod replica
2. The EBS CSI Driver sees the PVC and provisions an EBS volume in AWS
3. The volume is attached to the node and mounted into the pod at the specified path
4. Data persists on the EBS volume even if the pod is deleted or rescheduled

### Authentication via Pod Identity Agent

The EBS CSI Driver's controller (`ebs-csi-controller-sa`) needs AWS permissions to manage EBS volumes. This is granted by:
- Creating an IAM role with the `AmazonEBSCSIDriverPolicy` managed policy
- Creating a **Pod Identity Association** to bind the IAM role to the `ebs-csi-controller-sa` service account in `kube-system`

---

## Topic 03: Data Persistence in StatefulSets

StatefulSets use `volumeClaimTemplates` to create a dedicated PVC for each pod replica. This means:
- `mysql-0` gets its own EBS volume (`data-ebs-mysql-0`)
- `mysql-1` gets its own EBS volume (`data-ebs-mysql-1`)
- If `mysql-0` is deleted, Kubernetes recreates it and **reattaches the same EBS volume** — data is not lost

> **Important:** Deleting a StatefulSet does **not** delete its PVCs. PVCs (and the underlying EBS volumes) must be deleted manually to avoid orphaned cloud resources and unexpected costs.

---

## Lab Implementation

### 1. Set Environment Variables

```bash
export AWS_REGION="ap-south-1"
export EKS_CLUSTER_NAME="chirag-eks-cluster"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
```

---

### 2. Create IAM Role for EBS CSI Driver

Created a trust policy that allows EKS pods to assume the role via the Pod Identity Agent:

```bash
mkdir -p iam-policies
cd iam-policies

cat <<EOF > ebs-csi-driver-trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "pods.eks.amazonaws.com"
      },
      "Action": [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }
  ]
}
EOF
```

Created the IAM role and attached the AWS-managed EBS CSI policy:

```bash
# Create IAM Role
aws iam create-role \
  --role-name AmazonEKS_EBS_CSI_DriverRole_${EKS_CLUSTER_NAME} \
  --assume-role-policy-document file://ebs-csi-driver-trust-policy.json

# Attach the managed policy
aws iam attach-role-policy \
  --role-name AmazonEKS_EBS_CSI_DriverRole_${EKS_CLUSTER_NAME} \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy

# Verify
aws iam list-attached-role-policies \
  --role-name AmazonEKS_EBS_CSI_DriverRole_${EKS_CLUSTER_NAME}
```

![IAM role created and policy attached](images/Screenshot%202026-05-15%20105350.png)

---

### 3. Create Pod Identity Association & Install EBS CSI Driver Add-on

Created the Pod Identity Association to bind the IAM role to the `ebs-csi-controller-sa` service account, then installed the EBS CSI Driver as an EKS add-on:

```bash
# Create Pod Identity Association
aws eks create-pod-identity-association \
  --cluster-name ${EKS_CLUSTER_NAME} \
  --namespace kube-system \
  --service-account ebs-csi-controller-sa \
  --role-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/AmazonEKS_EBS_CSI_DriverRole_${EKS_CLUSTER_NAME}

# Install EBS CSI Driver add-on
aws eks create-addon \
  --cluster-name ${EKS_CLUSTER_NAME} \
  --addon-name aws-ebs-csi-driver \
  --service-account-role-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/AmazonEKS_EBS_CSI_DriverRole_${EKS_CLUSTER_NAME}

# Verify add-on status
aws eks list-addons --cluster-name ${EKS_CLUSTER_NAME}

aws eks describe-addon \
  --cluster-name ${EKS_CLUSTER_NAME} \
  --addon-name aws-ebs-csi-driver \
  --query "addon.status" --output text
```

![EBS CSI Driver add-on active](images/Screenshot%202026-05-15%20105417.png)

![Pod Identity Association created](images/Screenshot%202026-05-15%20105706.png)

---

### 4. Deploy K8s Manifests

Deployed all manifests including the EBS StorageClass:

```bash
kubectl apply -f secret-provider-class.yaml
kubectl apply -f service-account.yaml
kubectl apply -f catalog-config.yaml
kubectl apply -f services.yaml
kubectl apply -f statefulset.yaml
kubectl apply -f deployment.yaml
kubectl apply -f storage-class-ebs.yaml

kubectl get sc,pvc,pv,pods
```

![StorageClass, PVC and PV provisioned](images/Screenshot%202026-05-15%20105820.png)

![All pods running](images/Screenshot%202026-05-15%20110043.png)

---

### 5. Validate Application

Used port-forwarding to verify the application was running correctly:

```bash
kubectl port-forward svc/catalog-service 3000:8080
```

- `http://localhost:3000/health`
- `http://localhost:3000/topology`
- `http://localhost:3000/catalog/products`

![Application health check](images/Screenshot%202026-05-15%20110216.png)

![Catalog products endpoint](images/Screenshot%202026-05-15%20110225.png)

![Topology endpoint](images/Screenshot%202026-05-15%20110238.png)

---

### 6. Validate Data Stored in EBS Volume

Ran a temporary MySQL client pod to verify data was accessible from the EBS-backed volume:

```bash
kubectl run mysql-client --rm -it \
  --image=mysql:8.0 \
  --restart=Never \
  -- mysql -h mysql -u mysql_user -p

# Inside MySQL client pod
SHOW DATABASES;
USE catalogdb;
SHOW TABLES;
SELECT COUNT(*) FROM products;
SELECT * FROM tags;
```

![MySQL data accessible from EBS volume](images/Screenshot%202026-05-15%20110334.png)

![MySQL query results](images/Screenshot%202026-05-15%20110350.png)

---

### 7. Validate Data Persistence

Deleted the `mysql-0` pod in a separate terminal to verify that Kubernetes recreates it and reattaches the same EBS volume with all data intact:

```bash
# Terminal 1 — watch pods
kubectl get pods -w

# Terminal 2 — delete the pod
kubectl delete pod mysql-0
```

![Pod deleted and recreated — data persisted](images/Screenshot%202026-05-15%20111151.png)

![EBS volume reattached after pod restart](images/Screenshot%202026-05-15%20111436.png)

![Data intact after pod recreation](images/Screenshot%202026-05-15%20111501.png)

![All pods healthy after persistence test](images/Screenshot%202026-05-15%20111804.png)

---

### 8. Cleanup

Deleted all Kubernetes resources:

```bash
kubectl delete -f secret-provider-class.yaml
kubectl delete -f statefulset.yaml
kubectl delete -f deployment.yaml
kubectl delete -f services.yaml
kubectl delete -f catalog-config.yaml
kubectl delete -f service-account.yaml
kubectl delete -f storage-class-ebs.yaml

kubectl get sc,pvc,pv,pods
```

> **Note:** The PVC (`data-ebs-mysql-0`) persists even after deleting the StatefulSet. It must be deleted manually, otherwise the underlying EBS volume remains and continues to incur costs.

```bash
kubectl delete pvc data-ebs-mysql-0

# Verify EBS volumes via AWS CLI
aws ec2 describe-volumes \
  --filters "Name=tag:KubernetesCluster,Values=chirag-eks-cluster" \
  --query "Volumes[*].{ID:VolumeId,State:State,Size:Size,Name:Tags[?Key=='Name']|[0].Value}" \
  --output table
```

![PVC deleted and EBS volume released](images/Screenshot%202026-05-15%20112502.png)

![EBS volumes verified via AWS CLI](images/Screenshot%202026-05-15%20112626.png)

---

## Summary

Day 09 focused on persistent storage in Kubernetes using the AWS EBS CSI Driver, building on the Day 08 setup of CSI Secrets Store and Pod Identity Agent.

- **PersistentVolume (PV) & PVC** — Kubernetes abstractions that decouple pods from storage; PVCs are requests for storage that bind to PVs
- **StorageClass with `WaitForFirstConsumer`** — enables dynamic EBS volume provisioning in the same AZ as the scheduled pod
- **EBS CSI Driver** — EKS add-on that manages the full lifecycle of EBS volumes (provision, attach, mount, detach, delete)
- **StatefulSet `volumeClaimTemplates`** — creates a dedicated PVC per pod replica; if a pod is deleted, Kubernetes recreates it and reattaches the same EBS volume — data is not lost
- **PVCs are not deleted with StatefulSets** — PVCs (and EBS volumes) must be deleted manually during cleanup to avoid orphaned resources and unexpected costs
- **Pod Identity Association** — binds the IAM role with `AmazonEBSCSIDriverPolicy` to the `ebs-csi-controller-sa` service account so the driver can manage EBS volumes on behalf of the cluster
