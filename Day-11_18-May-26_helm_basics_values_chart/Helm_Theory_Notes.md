# ⎈ Section 12: Helm Package Manager — Theory Notes


## 1. Why Helm?

Without Helm, deploying even a single microservice to Kubernetes requires managing multiple individual YAML files — Deployment, Service, ConfigMap, Ingress, ServiceAccount, HPA, PDB, etc. For 5 microservices, that's 25–40+ files to maintain, version, and apply manually.

**Problems Helm solves:**
- **Repetition** — same boilerplate YAML across every service
- **No versioning** — `kubectl apply` has no concept of releases or rollback
- **No parameterization** — hardcoded values across files, no environment-specific overrides
- **No dependency management** — no way to declare that service A needs service B

**Helm Benefits:**
- Package all K8s resources for an app into a single **chart**
- **Version** charts and track release history
- **Parameterize** with values files — one chart, many environments
- **Rollback** to any previous revision with one command
- **Share** charts via repositories (Artifact Hub, ECR, GitHub Pages)

---

## 2. Core Concepts

### Chart
A Helm package — a collection of files that describe a related set of Kubernetes resources. Think of it like an apt/yum package but for Kubernetes.

### Release
A running instance of a chart installed into a cluster. One chart can produce multiple releases (e.g., `helm install ui-dev ./ui` and `helm install ui-prod ./ui`). Each release is independent with its own history.

### Repository
A server hosting packaged charts and an `index.yaml` catalog. Examples: Artifact Hub (public), Amazon ECR (OCI), GitHub Pages (self-hosted).

### Revision
Every `helm install` or `helm upgrade` increments the revision counter for a release. Helm stores each revision's state as a Kubernetes Secret, enabling rollback to any point.

---

## 3. Helm Chart Structure

```
mychart/
├── Chart.yaml          ← chart metadata
├── values.yaml         ← default configuration values
├── .helmignore         ← files excluded from packaging
├── charts/             ← downloaded chart dependencies (subcharts)
└── templates/          ← Kubernetes manifest templates
    ├── _helpers.tpl    ← reusable named templates (not rendered directly)
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    ├── configmap.yaml
    ├── serviceaccount.yaml
    ├── hpa.yaml
    ├── pdb.yaml
    ├── NOTES.txt       ← post-install message printed to user
    └── tests/
        └── test-connection.yaml
```

### Chart.yaml — Key Fields

```yaml
apiVersion: v2                          # v2 = Helm 3 (required)
name: retail-store-sample-ui-chart      # chart name
description: Retail Store UI Helm Chart
type: application                       # application or library
version: 1.3.1                          # chart version (SemVer) — bump on every release
appVersion: "1.3.0"                     # version of the app being packaged (informational)
```

- `version` tracks chart changes (templates, values). Bump it every time you publish.
- `appVersion` tracks the application version (e.g., Docker image tag). Independent of `version`.

### values.yaml — Default Values

Provides defaults for all configurable parameters. Templates reference them with `{{ .Values.key }}`. Users override without touching the chart source.

```yaml
replicaCount: 1
image:
  repository: public.ecr.aws/aws-containers/retail-store-sample-ui
  pullPolicy: IfNotPresent
  tag: ""
app:
  theme: default
ingress:
  enabled: false
releaseInfo:
  enabled: false
```

### _helpers.tpl — Named Templates

Prefixed with `_` so Helm skips rendering it as a manifest. Defines reusable snippets called across all templates:

```yaml
{{- define "ui.fullname" -}}
{{ .Release.Name }}-{{ .Chart.Name }}
{{- end }}

{{- define "ui.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

Called in templates with: `{{- include "ui.labels" . | nindent 4 }}`

### NOTES.txt — Post-Install Message

Rendered as a Go template and printed after `helm install` / `helm upgrade`. Used to show the user how to access the application.

---

## 4. OCI Charts vs Traditional Repositories

The Retail Store charts in this course are published as **OCI artifacts** on Amazon ECR Public.

| Feature              | Traditional HTTP Repo              | OCI Registry (ECR)                  |
|----------------------|------------------------------------|-------------------------------------|
| Add repo first?      | Yes — `helm repo add`              | No — install directly from `oci://` |
| Protocol             | HTTP + `index.yaml`                | OCI Distribution Spec               |
| Auth                 | Basic auth                         | `helm registry login`               |
| Helm version needed  | Any                                | Helm 3.8+                           |

**Authenticate to ECR Public:**
```bash
aws ecr-public get-login-password --region us-east-1 | \
  helm registry login -u AWS --password-stdin public.ecr.aws
```

**Install directly from OCI URL:**
```bash
helm install ui oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart --version 1.3.0
```

---

## 5. Values & Overrides

### Precedence (highest → lowest)
1. `--set key=value` (CLI, highest)
2. `-f custom-values.yaml` (last file wins if multiple `-f` flags)
3. Chart's default `values.yaml` (lowest)

### `-f` vs `--set`

| | `-f values.yaml` | `--set key=value` |
|---|---|---|
| Best for | Many values, complex structures | Single quick overrides, CI/CD |
| Readability | High — version-controlled file | Low for many values |
| Precedence | Lower than `--set` | Highest |

### Inspect chart defaults before overriding
```bash
helm show values oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart --version 1.3.0
```

### Dry-run before applying
```bash
helm install ui oci://... --version 1.3.0 -f values-ui.yaml --dry-run --debug
```

### Environment-specific values pattern
```
values-dev.yaml
values-staging.yaml
values-prod.yaml
```
Same chart, different values per environment — no chart duplication.

---

## 6. Core Helm Commands

### Install & Upgrade

```bash
# Install a new release
helm install <release-name> <chart> --version <ver> -f values.yaml

# Upgrade existing release
helm upgrade <release-name> <chart> --version <ver> -f values.yaml

# Install if not exists, upgrade if it does (idempotent — best for CI/CD)
helm upgrade --install <release-name> <chart> --version <ver> -f values.yaml

# Atomic upgrade — auto-rollback if upgrade fails
helm upgrade --install myapp ./chart --atomic --timeout 5m
```

### Inspect a Release

```bash
helm list                          # list all releases
helm list -n <namespace>           # in a specific namespace
helm status <release>              # release status
helm status <release> --show-resources  # all K8s resources created
helm get values <release>          # overridden values only
helm get values <release> --all    # all values (defaults + overrides)
helm get manifest <release>        # rendered K8s YAML applied to cluster
helm history <release>             # revision history
```

### Rollback

```bash
helm rollback <release> <revision>   # roll back to specific revision
helm rollback <release>              # roll back to previous revision
helm rollback <release> --dry-run    # preview without applying
```
Rollback creates a new revision entry in history.

### Uninstall

```bash
helm uninstall <release>                  # remove release + history
helm uninstall <release> --keep-history   # remove resources, keep history for audit
```

### Local Development Commands

```bash
helm lint ./mychart                        # validate chart syntax
helm template <release> ./mychart          # render templates locally (no cluster)
helm template <release> ./mychart -f values.yaml --debug   # with debug output
helm pull oci://... --version 1.3.0 --untar  # download and unpack chart source
helm show chart  oci://...                 # show Chart.yaml
helm show values oci://...                 # show default values.yaml
helm show readme oci://...                 # show README
helm test <release>                        # run test hooks
```

---

## 7. Go Templating in Helm

Helm uses Go's `text/template` engine. Key built-in objects:

| Object | Description | Example |
|--------|-------------|---------|
| `.Values` | Values from values.yaml + overrides | `.Values.image.tag` |
| `.Release` | Release metadata | `.Release.Name`, `.Release.Namespace`, `.Release.Revision` |
| `.Chart` | Chart metadata | `.Chart.Name`, `.Chart.Version`, `.Chart.AppVersion` |
| `.Capabilities` | Cluster info | `.Capabilities.KubeVersion` |
| `.Files` | Non-template files in chart | `.Files.Get "config.ini"` |

### Whitespace Control
- `{{ }}` — renders value, preserves surrounding whitespace
- `{{- }}` — trims whitespace/newline **before** the tag
- `{{ -}}` — trims whitespace/newline **after** the tag
- `{{- -}}` — trims both sides

### Key Template Functions

```yaml
# toYaml — convert values object to YAML block
resources:
  {{- toYaml .Values.resources | nindent 2 }}

# include — call named template and pipe result (preferred over 'template')
labels:
  {{- include "ui.labels" . | nindent 4 }}

# required — fail with message if value is empty
host: {{ required "A valid .Values.host is required!" .Values.host }}

# default — fallback value
tag: {{ .Values.image.tag | default .Chart.Version }}
```

### Image Tag Fallback Pattern (used in Retail Store charts)
```yaml
image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.Version }}"
```
If `image.tag` is not set in values, it falls back to the chart version. Always set it explicitly in production.

---

## 8. Release Info ConfigMap Pattern (Demo 12-04)

A practical pattern to embed release metadata into a ConfigMap for observability:

```yaml
# templates/release-info.yaml
{{- if .Values.releaseInfo.enabled }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "ui.fullname" . }}-release-info
data:
  chartName: "{{ .Chart.Name }}"
  chartVersion: "{{ .Chart.Version }}"
  appVersion: "{{ .Chart.AppVersion }}"
  releaseName: "{{ .Release.Name }}"
  releaseNamespace: "{{ .Release.Namespace }}"
  releaseRevision: "{{ .Release.Revision }}"
  releaseTime: "{{ now | date "2006-01-02T15:04:05Z07:00" }}"
{{- end }}
```

Enable via values override: `releaseInfo.enabled: true`

Useful for: auditing which chart version is deployed, debugging, and CI/CD traceability. This is not mandatory file for helm, but very important when it comes to debugging in production and works as initial step to begin further investigation.

---

## 9. Packaging & Publishing to Amazon ECR

### Workflow

```
Edit Chart.yaml (bump version)
        ↓
helm package ./ui          → retail-store-sample-ui-chart-1.3.1.tgz
        ↓
helm push <tgz> oci://<registry>
        ↓
helm install from oci://<registry>/<chart-name> --version 1.3.1
```

### Full Commands

```bash
# Set variables
REGION=ap-south-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

# Login to ECR
aws ecr get-login-password --region "$REGION" | \
  helm registry login -u AWS --password-stdin "$REGISTRY"

# Create ECR repository (chart name must match)
aws ecr create-repository --repository-name retail-store-sample-ui-chart --region "$REGION"

# Package
helm package ./ui    # produces retail-store-sample-ui-chart-1.3.1.tgz

# Push
helm push retail-store-sample-ui-chart-1.3.1.tgz oci://"$REGISTRY"

# Install from ECR
helm install retail-ui oci://"$REGISTRY"/retail-store-sample-ui-chart --version 1.3.1 -f values-ui.yaml
```

### Key Rules
- ECR repository name must **exactly match** the chart name in `Chart.yaml`
- Push to the **registry root** (`oci://$REGISTRY`), not a subfolder
- Always bump `version` in `Chart.yaml` before packaging a new release

---

## 10. Helm Release Lifecycle

```
helm install        → Revision 1 (DEPLOYED)
helm upgrade        → Revision 2 (DEPLOYED), Revision 1 (SUPERSEDED)
helm upgrade        → Revision 3 (DEPLOYED), Revision 2 (SUPERSEDED)
helm rollback 1     → Revision 4 (DEPLOYED) ← re-applies Revision 1 state
helm uninstall      → All resources deleted
```

- Release state is stored as Kubernetes Secrets in the release namespace
- `helm history` shows all revisions with status, chart version, and description
- `--keep-history` on uninstall preserves history Secrets for audit

---

## 11. Helm vs kubectl apply

| Feature | Helm | kubectl apply |
|---------|------|---------------|
| Release tracking | Yes — named releases with history | No |
| Rollback | Built-in `helm rollback` | Manual — re-apply old YAML |
| Templating | Go templates + values files | Static YAML only |
| Parameterization | values.yaml + overrides | None |
| Dependency management | Subcharts, conditions | None |
| Upgrade diff | 3-way strategic merge | Patch-based apply |
| Dry-run | `--dry-run --debug` | `--dry-run=client` |

---

## 13. Best Practices

- **Never hardcode** image tags, resource limits, or environment-specific values in templates — put them in `values.yaml`
- **Use `-f values-<env>.yaml`** for environment-specific overrides, not `--set` for many values
- **Never store secrets** in values files — use AWS Secrets Manager + CSI Driver (Section 09)
- **Always bump `version`** in `Chart.yaml` before packaging and publishing
- **Use `--atomic`** in CI/CD pipelines to auto-rollback failed upgrades
- **Use `helm template` + `helm lint`** locally before deploying to a cluster
- **Use `helm upgrade --install`** in CI/CD for idempotent deployments
- **Explicitly set `image.tag`** — don't rely on the `.Chart.Version` fallback in production
- **Use `--keep-history`** on uninstall in production for audit trails

---