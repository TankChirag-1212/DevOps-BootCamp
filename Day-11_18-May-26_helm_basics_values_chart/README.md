# Day 11 - Helm Basics-custom values-chart-Publish

## Topic 1 : Helm Basic Commands

first to get the helm charts from OCI registries we need to authenticate below is the cmd for that 

```bash
aws ecr-public get-login-password --region us-east-1 | helm registry login -u AWS --password-stdin public.ecr.aws
```

note:- for public ecr registry authentication only 'us-east-1' has to be used and for private we can use any of the available region

once authentication is done, I installed the Retail-store-chart for further implentation of helm commands

```
helm install ui oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart \
  --version 1.0.0
```

List Helm Releases

```bash
# List Helm releases (default table output)
helm list
helm ls

# List Helm releases in YAML or JSON
helm list --output=yaml
helm list --output=json

# List Helm releases for a specific namespace (if not using default)
helm list -n default
```

Verifying the resources after installing the helm chart for retail-store-sample

```bash
# List Pods created by the 'ui' release
kubectl get pods

# List Services created by the 'ui' release
kubectl get svc

# Port-forward to access the application locally (adjust service name if different)
kubectl port-forward svc/ui 30080:80

# Access the Retail UI application
http://localhost:30080
```

Helm Rollback to Previous Release

```bash
# Upgrade to a new chart version (1.2.4) and change app theme (example)
helm upgrade ui oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart \
  --version 1.2.4 \
  --set app.theme=green

# Show release history
helm history ui

# Roll back to revision 1
helm rollback ui 1

# Verify rollback
helm list
helm history ui
kubectl get pods -w

# (If service is ClusterIP) Port-forward to access the application
kubectl port-forward svc/ui 30080:80
# http://localhost:30080
```

Note:- 
- `helm rollback ui` → rolls back to the last successful release.
- `helm rollback ui 1 --dry-run` → preview rollback without applying.

Inspect and Preview:-

```bash
# See chart default values (great for discovering knobs)
helm show values oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart --version 1.3.0

# Dry-run to preview what will be applied
cd retailstore-apps
helm install ui oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart --version 1.3.0 -f values-ui.yaml --dry-run --debug | less
```

Custom values and Prescendence

1. Where do values come from?

- Chart defaults: `values.yaml` inside the chart (what the author ships)
- Your overrides: `-f <file.yaml>` (recommended) and/or `--set key=value` (quick tweaks)

2. Precedence (highest → lowest):

- --set (and --set-string)
- Multiple -f files in order (the last file wins for the same key)
- Chart’s default values.yaml

3. Best practices:

- Prefer `-f values-<env>.yaml` for most overrides; use `--set` for small, one-off changes.
- Keep environment files (`values-dev.yaml`, `values-stg.yaml`, `values-prod.yaml`) to avoid accidental drift.
- Avoid putting secrets in values files. Use External Secrets or Kubernetes Secrets + IRSA.


install helm release with custom values

```bash
# Verify if AWS Load Balancer Controller installed
kubectl get deploy  -n kube-system aws-load-balancer-controller
kubectl get pods -n kube-system

# Verify Default Ingressclass configured
kubectl get ingressclass

# Observation: "alb" should be default ingressclass

# Change Directory (adjust to your repo layout)
cd 12-02-Helm-Custom-Values/retailstore-apps

# Helm Install
cd retailstore-apps
helm install ui oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart \
  --version 1.3.0 \
  -f values-ui.yaml
```

Verifying the applicaiton using below commands and accessing the application via browser

```bash
# Get the ALB DNS name
kubectl get ingress ui 

# Access Application
http://<ALB-DNS-NAME>
http://<ALB-DNS-NAME>/topology
```

In Depth

```bash
# Pull the UI chart from ECR Public (OCI) and unpack it
helm pull oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart \
  --version 1.3.0 \
  --untar

# Inspect what got created
ls -la

tree -a || true

# Folder structure
.
└── retail-store-sample-ui-chart
    ├── .helmignore
    ├── Chart.yaml
    ├── README.md
    ├── templates
    │   ├── _helpers.tpl
    │   ├── configmap.yml
    │   ├── deployment.yaml
    │   ├── hpa.yaml
    │   ├── ingress.yaml
    │   ├── istio-gateway.yml
    │   ├── istio-virtualservice.yml
    │   ├── NOTES.txt
    │   ├── pdb.yaml
    │   ├── service.yaml
    │   ├── serviceaccount.yaml
    │   └── tests
    │       └── test-connection.yaml
    └── values.yaml
```

Typical Helm chart layout (names may vary slightly by publisher):

- Chart.yaml – Chart metadata: name, description, type, version (chart), appVersion (app).

- values.yaml – Default values shipped with the chart (what gets used when you don’t override).

- .helmignore – Files/paths excluded when packaging.

- templates/ – Where the K8s YAML templates live:
    - deployment.yaml – Pod/ReplicaSet spec; references many .Values.* keys.
    - service.yaml – ClusterIP/LoadBalancer spec and ports.
    - ingress.yaml – Ingress rules and annotations (if supported).
    - configmap.yml (or similarly named) – App configuration rendered from values.
    - _helpers.tpl – Helper templates for names/labels (used across templates).
    - NOTES.txt – Post-install notes printed by Helm.
    - Optional: hpa.yaml, serviceaccount.yaml, tests/* (Helm test hooks), istio-*.yml.

> Tip: Open values.yaml next to templates/. As you skim templates, note every .Values.* usage and where it maps in values.yaml.

Chart Defaults 

```bash
# See the chart’s default values directly from the registry (handy reference)
helm show values oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart \
  --version 1.3.0 | less

# Also inspect the local copy you just pulled:
cat ui/values.yaml

# (Optional) extra discovery
helm show chart  oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart --version 1.3.0
helm show readme oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart --version 1.3.0
```

Lint and Render 

```bash
# Lint the chart templates
helm lint ui

# Render the chart locally (defaults)
helm template ui ./ui | less

# Render with your custom values (adjust path if your repo differs)
helm template ui ./ui -f ../retailstore-apps/values-ui.yaml | less

# With custom values + extra debug
helm template ui ./ui -f ../retailstore-apps/values-ui.yaml --debug | less
```

Helm Test 

- some charts include **test hooks** under `templates/tests/*`
- In our chart, we have `templates/tests/test-connection.yaml`

```
# Helm test
helm test ui-local
```

some handy cheat-sheet commands

```bash
# Pull (OCI) + unpack
helm pull oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart --version 1.3.0 --untar

# Show chart metadata & defaults from registry
helm show chart  oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart --version 1.3.0
helm show values oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart --version 1.3.0
helm show readme oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart --version 1.3.0

# Lint + render from local source
helm lint ui
helm template ui ./ui -f ../retailstore-apps/values-ui.yaml --debug

# Install from local source (separate release name)
helm install ui-local ./ui -f ../retailstore-apps/values-ui.yaml
helm status ui-local --show-resources
```

## Topic 3 : Packaging and Publishing Helm Chart

pre-requisites

- Update chart metadata (Chart.yaml)
- Package Helm chart (.tgz)
- Push to Amazon ECR Private (OCI registry)
- Install Helm chart directly from ECR
- Understand image tag fallback (.Chart.Version)
- New: Release Info ConfigMap

```bash
# Pull the UI chart from ECR Public (OCI) and unpack it
helm pull oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart \
  --version 1.3.0 \
  --untar

# Inspect what got created
ls -la  

# Rename the long folder name to smaller folder name
mv retail-store-sample-ui-chart ui
```

updating something in chart.yaml with new version 1.3.0 -> 1.3.1 

then created ecr private repository to push the helm chart

```bash
# Set Variables
REGION=ap-south-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

# Verify Variables
echo $REGION
echo $ACCOUNT_ID
echo $REGISTRY

# Login to ECR for Helm/OCI
aws ecr get-login-password --region "$REGION" \
| helm registry login -u AWS --password-stdin "$REGISTRY"

# Create flat repo (exactly chart name)
aws ecr create-repository \
  --repository-name retail-store-sample-ui-chart \
  --region "$REGION" || true

# Package chart (matches Chart.yaml)
cd charts
helm package ./ui   # -> retail-store-sample-ui-chart-1.3.1.tgz

# Push to ECR (OCI): IMPORTANT: push to registry root (no suffix) ---
helm push retail-store-sample-ui-chart-1.3.1.tgz oci://"$REGISTRY"

# Verify
aws ecr describe-images \
  --repository-name retail-store-sample-ui-chart \
  --region "$REGION" \
  --query 'imageDetails[].imageTags'
```

to validate installed chart from private ecr repo 

```bash
# helm upgrade or install
helm upgrade --install retail-ui \
  oci://"$REGISTRY"/retail-store-sample-ui-chart \
  --version 1.2.5 \
  -f ../retailstore-apps/values-ui.yaml
```

verifying the resources after installing the helm chart

```bash
# List Helm Releases
helm list

# List Kubernetes Resources
helm status retail-ui --show-resources 

# Verify pods & service
kubectl get pods,svc

# Verify Release Info ConfigMap
kubectl get cm 
kubectl get cm retail-ui-release-info -o yaml
kubectl describe cm retail-ui-release-info
```

finally cleanup of ecr private repo
```bash
# Delete AWS ECR Repository
aws ecr delete-repository \
  --repository-name retail-store-sample-ui-chart \
  --region "$REGION" \
  --force
```

Helm Charts with all the microservices

```bash
# Download Charts
cd retailstore-charts
./download-and-untar-helm-charts.sh

# Review all charts code
├── retail-store-sample-cart-chart
│   ├── Chart.yaml
│   ├── templates
│   └── values.yaml
├── retail-store-sample-catalog-chart
│   ├── Chart.yaml
│   ├── templates
│   └── values.yaml
├── retail-store-sample-checkout-chart
│   ├── Chart.yaml
│   ├── templates
│   └── values.yaml
├── retail-store-sample-orders-chart
│   ├── Chart.yaml
│   ├── templates
│   └── values.yaml
└── retail-store-sample-ui-chart
    ├── Chart.yaml
    ├── README.md
    ├── templates
    └── values.yaml
```

Installing all the microservices charts one by one

```bash
# Authenticate to Amazon Public ECR (token valid for 12 hours)
aws ecr-public get-login-password --region us-east-1 | \
helm registry login -u AWS --password-stdin public.ecr.aws

# Change Directory
cd retailstore-apps

# Catalog
helm install catalog oci://public.ecr.aws/aws-containers/retail-store-sample-catalog-chart \
  --version 1.3.0 -f values-catalog.yaml

# Cart
helm install cart oci://public.ecr.aws/aws-containers/retail-store-sample-cart-chart \
  --version 1.3.0 -f values-cart.yaml

# Checkout
helm install checkout oci://public.ecr.aws/aws-containers/retail-store-sample-checkout-chart \
  --version 1.3.0 -f values-checkout.yaml

# Orders
helm install orders oci://public.ecr.aws/aws-containers/retail-store-sample-orders-chart \
  --version 1.3.0 -f values-orders.yaml

# UI (Ingress enabled, HTTP — see values-ui.yaml)
helm install ui oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart \
  --version 1.3.0 -f values-ui.yaml
```

Verifying all the deployments

```bash
# Helm releases
helm list

# Pods / Services / Ingress
kubectl get pods
kubectl get svc
kubectl get ingress

# UI release details
helm status ui --show-resources
helm status catalog --show-resources
helm status cart --show-resources
helm status checkout --show-resources
helm status orders --show-resources

# Verify Ingress Load Balancer Controller Logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -f
```

Accessing the UI application using ALB dns

```
kubectl get ingress ui 

http://<ALB-DNS-NAME>
http://<ALB-DNS-NAME>/topology
```

Cleaning up everything

```
helm uninstall ui orders checkout cart-carts catalog
```