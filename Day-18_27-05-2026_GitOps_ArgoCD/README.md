# Day 18 — GitOps with ArgoCD & GitHub Actions

## Topic 01: GitOps

**GitOps** is a deployment model where Git is the single source of truth for both application code and infrastructure configuration. All changes go through Git — no manual `kubectl apply` in production.

```
Developer pushes code to GitHub
        ↓
GitHub Actions workflow triggers automatically
        ↓
Docker image built and pushed to ECR
        ↓
ArgoCD detects drift between Git state and cluster state
        ↓
ArgoCD syncs the cluster to match Git — automatically
```

### Key Principles

- **Declarative** — desired state is described in Git, not scripted imperatively
- **Versioned** — every change is a Git commit; rollback is a `git revert`
- **Automated** — the cluster continuously reconciles itself to match Git
- **Observable** — drift between Git and cluster is visible at all times

---

## Topic 02: GitHub Actions & OIDC Authentication

**GitHub Actions** is the CI pipeline. When code is pushed, it builds the Docker image and pushes it to a private ECR repository — without storing any long-lived AWS credentials.

Authentication is handled via **OIDC (OpenID Connect)**. GitHub's OIDC provider issues a short-lived token per workflow run, and an IAM role is configured to trust that token. The workflow assumes the role via `sts:AssumeRoleWithWebIdentity` — no access keys stored in GitHub Secrets.

### OIDC Trust Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:<org>/<repo>:*"
        }
      }
    }
  ]
}
```

### Workflow Flow

```
Push to main branch
        ↓
GitHub Actions runner starts
        ↓
Runner assumes IAM role via OIDC (no stored credentials)
        ↓
docker build → docker tag → docker push to ECR
        ↓
New image available in private ECR repo
```

---

## Topic 03: ArgoCD

**ArgoCD** is a GitOps continuous delivery tool for Kubernetes. It runs inside the cluster and continuously watches a Git repository. When the desired state in Git diverges from the actual state in the cluster, ArgoCD detects the drift and syncs the cluster back to match Git.

### ArgoCD Application CRD

An `Application` resource tells ArgoCD what to watch and where to deploy:

```yaml
spec:
  source:
    repoURL: https://github.com/<org>/<repo>
    targetRevision: HEAD
    path: argocd-manifests/
  destination:
    server: https://kubernetes.default.svc
    namespace: retail-store
  syncPolicy:
    automated:
      prune: true       # delete resources removed from Git
      selfHeal: true    # revert manual changes made directly to the cluster
```

### ArgoCD Sync Loop

```
ArgoCD polls Git every 3 minutes (or webhook triggers immediately)
        ↓
Compares live cluster state with desired Git state
        ↓
If drift detected → applies the diff to the cluster
        ↓
Application status: Synced + Healthy
```

---

## Lab Implementation

### 1. Create OIDC IAM Role for GitHub Actions

Created the trust policy and IAM role that GitHub Actions runners will assume to push images to ECR:

```bash
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:<org>/<repo>:*"
        }
      }
    }
  ]
}
EOF

# Create IAM role
aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document file://trust-policy.json

# Attach ECR push permissions
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser

# Verify
aws iam list-attached-role-policies --role-name $ROLE_NAME
```

---

### 2. Push Application Code & Trigger GitHub Actions

Pushed the application source code and ArgoCD `Application` manifest to GitHub. The push automatically triggered the `image-build-push.yaml` workflow, which built the Docker image and pushed it to the private ECR repository.

![GitHub Actions workflow triggered on push](images/Screenshot%202026-05-27%20162230.png)

![Workflow completed — image pushed to ECR](images/Screenshot%202026-05-27%20162312.png)

---

### 3. Provision Infrastructure (Terraform)

Before running `terraform apply`, authenticated to the public ECR registry — required because Helm charts for cluster add-ons are pulled from public ECR:

```bash
aws ecr-public get-login-password --region us-east-1 | \
  helm registry login -u AWS --password-stdin public.ecr.aws
```

Provisioned the full EKS cluster with all add-ons and Karpenter:

```bash
cd Terraform-files

terraform init
terraform validate
terraform plan
terraform apply -auto-approve
```

Configured kubectl and verified the cluster:

```bash
aws eks update-kubeconfig --region ap-south-1 --name chirag-eks-cluster

kubectl get nodes
kubectl get pods -n kube-system
```

![EKS cluster provisioned — nodes ready](images/Screenshot%202026-05-27%20183313.png)

---

### 4. Install ArgoCD CLI

```bash
curl -sSL -o argocd-linux-amd64 \
  https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# Verify
argocd version
```

---

### 5. Deploy ArgoCD to the Cluster

```bash
kubectl create namespace argocd

kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Verify all ArgoCD pods are running
kubectl get pods -n argocd
```

![ArgoCD pods running in argocd namespace](images/Screenshot%202026-05-27%20202256.png)

---

### 6. Access ArgoCD UI

Retrieved the initial admin password and accessed the ArgoCD UI via port-forward:

```bash
# Get admin password
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 --decode && echo

# Port-forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Logged in via CLI or browser at `https://localhost:8080`:

```bash
argocd login localhost:8080 --username admin --password <password> --insecure
```

![ArgoCD UI — login page](images/Screenshot%202026-05-27%20205910.png)

![ArgoCD UI — no applications yet](images/Screenshot%202026-05-27%20205943.png)

---

### 7. Deploy ArgoCD Application Manifest

Applied the `Application` CRD to register the app with ArgoCD. ArgoCD immediately synced the cluster to match the Git state:

```bash
kubectl apply -f argocd-manifests/application-ui.yaml

# Verify sync status
argocd app list
kubectl get all -n retail-store
```

![ArgoCD application synced — Healthy](images/Screenshot%202026-05-27%20210519.png)

![ArgoCD UI — application tree view](images/Screenshot%202026-05-27%20210711.png)

![All pods running after ArgoCD sync](images/Screenshot%202026-05-27%20211603.png)

---

### 8. Validate GitOps — Push a Change

Updated the UI source code and pushed to GitHub. The workflow built a new image, pushed it to ECR, and ArgoCD automatically detected the new image tag in the manifest and redeployed the UI pod — no manual intervention:

```bash
# After pushing code change to GitHub
argocd app get retail-store-ui   # watch sync status update
kubectl get pods -n retail-store -w
```

![New GitHub Actions run triggered by code push](images/Screenshot%202026-05-27%20211807.png)

![ArgoCD detected drift and synced automatically](images/Screenshot%202026-05-27%20212155.png)

![Updated UI live — change reflected in browser](images/Screenshot%202026-05-27%20212221.png)

---

### 9. Validate Application via Ingress

Verified the application was accessible via the ALB ingress DNS name:


![ArgoCD showing all resources Synced + Healthy](images/Screenshot%202026-05-27%20224058.png)

![ArgoCD app details — sync history](images/Screenshot%202026-05-27%20225013.png)

![ArgoCD app details — resource tree](images/Screenshot%202026-05-27%20225035.png)

![ArgoCD app details — events](images/Screenshot%202026-05-27%20225222.png)

---

### 10. Cleanup

Deleted the ArgoCD application (which pruned all deployed resources), then destroyed all Terraform-managed infrastructure:

```bash
# Uninstall retail apps via script
chmod +x Helm-dataplane-remote-charts/01-uninstall-retail-apps.sh
./Helm-dataplane-remote-charts/01-uninstall-retail-apps.sh

# Delete ArgoCD application from UI or CLI
argocd app delete retail-store-ui
```

```bash
cd Terraform-files
terraform destroy -auto-approve
terraform state list
```

![Resources cleaned up — ArgoCD app deleted](images/Screenshot%202026-05-27%20235536.png)

![Terraform destroy complete](images/Screenshot%202026-05-28%20000913.png)

![All AWS resources removed](images/Screenshot%202026-05-28%20001123.png)

![Final state — no resources remaining](images/Screenshot%202026-05-28%20001136.png)

![Terraform state empty](images/Screenshot%202026-05-28%20010223.png)

![AWS console — cluster deleted](images/Screenshot%202026-05-28%20010347.png)

---

## Summary

Day 18 implemented a full GitOps pipeline using GitHub Actions for CI and ArgoCD for CD, deploying the retail store application to EKS.

- **GitOps** — Git is the single source of truth; no manual `kubectl apply` in production; all changes are versioned, auditable, and reversible via Git history
- **OIDC authentication** — GitHub Actions assumes an IAM role via OIDC per workflow run; no long-lived credentials stored in GitHub Secrets; the trust policy scopes access to a specific repository
- **GitHub Actions CI** — on every push, the workflow builds a Docker image and pushes it to a private ECR repository; the image tag (commit SHA) is updated in the Kubernetes manifest
- **ArgoCD** — runs inside the cluster; continuously reconciles live cluster state with the desired state in Git; `selfHeal: true` reverts any manual changes made directly to the cluster; `prune: true` removes resources deleted from Git
- **Automated sync** — when a new image is pushed and the manifest is updated in Git, ArgoCD detects the drift within minutes and rolls out the new version automatically — no human intervention required after the initial `git push`
