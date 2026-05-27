# Day 11 — Helm: Package Manager for Kubernetes

## Lab Implementation

### 1. Authenticate to ECR Public & Install Initial Chart

Authenticated to ECR Public (must use `us-east-1` for public registry) and installed the Retail Store UI chart to explore basic Helm commands:

```bash
aws ecr-public get-login-password --region us-east-1 | \
  helm registry login -u AWS --password-stdin public.ecr.aws

helm install ui oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart \
  --version 1.0.0
```

Verified the deployed resources and accessed the application via port-forwarding:

```bash
helm list
kubectl get pods,svc

kubectl port-forward svc/ui 30080:80
# http://localhost:30080
```

---

### 2. Upgrade, History & Rollback

Upgraded the release to a newer chart version with a custom value, then explored the revision history and rolled back:

```bash
# Upgrade to v1.2.4 with a custom theme
helm upgrade ui oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart \
  --version 1.2.4 \
  --set app.theme=green

# View revision history
helm history ui

# Roll back to revision 1
helm rollback ui 1

# Verify rollback
helm list
helm history ui
kubectl get pods -w
```

---

### 3. Inspect Chart Internals

Pulled the chart source locally to explore the template structure and understand how values map to rendered manifests:

```bash
# Show default values from the registry
helm show values oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart \
  --version 1.3.0

# Pull and unpack chart source
helm pull oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart \
  --version 1.3.0 \
  --untar

# Lint and render templates locally
helm lint ui
helm template ui ./ui -f values-ui.yaml --debug | less
```

The unpacked chart structure:

```
retail-store-sample-ui-chart/
├── Chart.yaml
├── values.yaml
├── .helmignore
└── templates/
    ├── _helpers.tpl
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    ├── configmap.yml
    ├── serviceaccount.yaml
    ├── hpa.yaml
    ├── pdb.yaml
    ├── NOTES.txt
    └── tests/
        └── test-connection.yaml
```

---

### 4. Install with Custom Values File

Installed the chart using a custom `values-ui.yaml` override file to enable the ALB Ingress, then validated via the ALB DNS name:

```bash
# Verify ALB Controller and IngressClass are ready
kubectl get deploy -n kube-system aws-load-balancer-controller
kubectl get ingressclass

# Install with custom values
helm install ui oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart \
  --version 1.3.0 \
  -f values-ui.yaml

# Get ALB DNS name
kubectl get ingress ui

# Access application
# http://<ALB-DNS-NAME>
# http://<ALB-DNS-NAME>/topology
```

---

### 5. Package & Publish to ECR Private

Modified the chart version in `Chart.yaml` (1.3.0 → 1.3.1), packaged it, and pushed it to a private ECR repository:

```bash
REGION=ap-south-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

# Login to ECR Private
aws ecr get-login-password --region "$REGION" | \
  helm registry login -u AWS --password-stdin "$REGISTRY"

# Create ECR repository (name must match chart name exactly)
aws ecr create-repository \
  --repository-name retail-store-sample-ui-chart \
  --region "$REGION"

# Package the chart
cd charts
helm package ./ui    # produces retail-store-sample-ui-chart-1.3.1.tgz

# Push to ECR
helm push retail-store-sample-ui-chart-1.3.1.tgz oci://"$REGISTRY"

# Verify
aws ecr describe-images \
  --repository-name retail-store-sample-ui-chart \
  --region "$REGION" \
  --query 'imageDetails[].imageTags'
```

Installed from the private ECR registry to validate the published chart:

```bash
helm upgrade --install retail-ui \
  oci://"$REGISTRY"/retail-store-sample-ui-chart \
  --version 1.3.1 \
  -f values-ui.yaml

# Verify release info ConfigMap
kubectl get cm retail-ui-release-info -o yaml
```

---

### 6. Deploy All 5 Microservices via Helm

Installed each microservice chart from ECR Public with its own values file:

```bash
helm install catalog  oci://public.ecr.aws/aws-containers/retail-store-sample-catalog-chart  --version 1.3.0 -f values-catalog.yaml
helm install cart     oci://public.ecr.aws/aws-containers/retail-store-sample-cart-chart     --version 1.3.0 -f values-cart.yaml
helm install checkout oci://public.ecr.aws/aws-containers/retail-store-sample-checkout-chart --version 1.3.0 -f values-checkout.yaml
helm install orders   oci://public.ecr.aws/aws-containers/retail-store-sample-orders-chart   --version 1.3.0 -f values-orders.yaml
helm install ui       oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart       --version 1.3.0 -f values-ui.yaml
```

Verified all releases and accessed the application:

```bash
helm list
kubectl get pods,svc,ingress

# http://<ALB-DNS-NAME>
# http://<ALB-DNS-NAME>/topology
```

---

### 7. Cleanup

```bash
# Uninstall all Helm releases
helm uninstall ui orders checkout cart catalog

# Delete ECR private repository
aws ecr delete-repository \
  --repository-name retail-store-sample-ui-chart \
  --region "$REGION" \
  --force
```

---

## Summary

Day 11 covered Helm as the package manager for Kubernetes, from basic install/upgrade/rollback through to packaging and publishing custom charts to Amazon ECR.

- **Chart** — a versioned package of all Kubernetes resources for an application; `version` tracks chart changes, `appVersion` tracks the app version independently
- **Release & Revision** — every `helm install` or `helm upgrade` creates a new revision stored as a Kubernetes Secret; `helm rollback` appends a new revision rather than rewinding history
- **Values precedence** — `--set` overrides `-f file` overrides chart defaults; use `-f values-<env>.yaml` for environment-specific config, `--set` only for quick one-off changes
- **OCI charts** — ECR-hosted charts are installed directly via `oci://` URL with no `helm repo add` step; ECR Public auth always requires `us-east-1`
- **`helm template` + `helm lint`** — render and validate templates locally before deploying to a cluster; `--dry-run --debug` previews the full install without applying anything
- **Packaging & publishing** — `helm package` produces a `.tgz`, `helm push` uploads it to ECR OCI; ECR repository name must exactly match the chart name in `Chart.yaml`
- **Release Info ConfigMap** — a practical pattern to embed chart version, release name, revision, and timestamp into a ConfigMap for production observability and debugging
