# Day 10 — Kubernetes Ingress on AWS EKS

## Topic 01: Understanding Kubernetes Ingress

### What is an Ingress?

- **Kubernetes Ingress** is an API object that exposes HTTP(S) routes from outside the cluster to services running inside the cluster
- It's a **Layer 7 (HTTP/HTTPS)** router that routes traffic based on URLs, domains, and paths
- Without Ingress, services are only accessible internally or via NodePort; Ingress provides a production-ready way to expose apps on the internet

### Why Do We Need Ingress?

- **NodePort exposes services** but with high port numbers (30000–32767) — not user-friendly
- **LoadBalancer** creates a separate load balancer per service — expensive if you have many services
- **Ingress** uses **one load balancer** to route traffic to **multiple services** based on URLs and domains — cost-effective and production-ready

### How Does Ingress Work?

```
Internet → AWS ALB/NLB (Load Balancer) → Ingress Controller (watches Ingress objects)
           ↓
        Kubernetes Ingress Rules (routing configuration)
           ↓
        Kubernetes Services (ClusterIP)
           ↓
        Pods (running applications)
```

### Ingress Architecture in AWS

- **Ingress Resource** → Kubernetes API object defining routing rules
- **Ingress Controller** → Software that watches Ingress objects and takes action (AWS Load Balancer Controller)
- **AWS ALB/NLB** → Physical load balancer provisioned by the controller
- **Target Group** → AWS concept that groups targets (pods/nodes) for the load balancer
- **ServiceAccount** → Kubernetes identity used by the controller pod

---

## Topic 02: AWS Load Balancer Controller

### What is the Load Balancer Controller?

- A **Kubernetes controller** that watches for Ingress resources and automatically provisions AWS load balancers (ALB/NLB)
- Without it, you have to manually create load balancers in AWS; with it, Kubernetes does it for you
- It runs as a deployment in the `kube-system` namespace and continuously reconciles Ingress objects with AWS resources

### Why Use Load Balancer Controller?

- **Automation** — No manual ALB creation; just write Ingress and controller handles the rest
- **Cost Efficiency** — One ALB serves multiple services instead of one per service
- **Security** — Integrates with AWS security groups, rules, and IAM
- **High Availability** — Automatically manages target health and failover

### How Does It Work?

```
1. You create an Ingress resource (YAML file)
            ↓
2. Load Balancer Controller watches the cluster
            ↓
3. Controller detects new Ingress
            ↓
4. Controller calls AWS API to create ALB, target groups, rules
            ↓
5. Controller registers pods as targets
            ↓
6. ALB starts routing traffic based on Ingress rules
```

### Pod Identity vs IRSA

- **IRSA (IAM Roles for Service Accounts)** — Old way; used webhook to inject temporary credentials
- **Pod Identity** — Modern way; native EKS feature that's simpler and more secure
- **Pod Identity Association** — Link between Kubernetes ServiceAccount and AWS IAM Role

---

## Topic 03: Kubernetes Ingress — HTTP

### What Happens With HTTP Ingress?

- Creates an **AWS Application Load Balancer (ALB)** automatically
- Routes **HTTP traffic** to your Kubernetes services
- Configurable via **annotations** in the Ingress manifest
- ALB operates at Layer 4 initially, but controller translates HTTP rules to ALB

### Ingress Manifest Structure

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-http
  annotations:
    # Annotations control ALB behavior
spec:
  ingressClassName: alb  # Specifies which controller processes this
  defaultBackend:        # Default service if no rules match
    service:
      name: app-service
      port:
        number: 80
  rules:                 # Optional: additional routing rules
    - host: example.com
      http:
        paths:
          - path: /
            backend:
              service:
                name: app-service
                port:
                  number: 80
```

### Ingress Annotations Explained

| Annotation | Purpose | Example |
|-----------|---------|---------|
| `scheme` | Make ALB public or internal | `internet-facing` or `internal` |
| `target-type` | Route to nodes (instance) or pods (ip) | `instance` or `ip` |
| `healthcheck-path` | URL for health checks | `/health` or `/actuator/health` |
| `healthcheck-interval-seconds` | How often to check (5-300) | `15` |
| `healthcheck-timeout-seconds` | Wait time for response (2-120) | `5` |
| `healthy-threshold-count` | Consecutive success = healthy (2-10) | `2` |
| `unhealthy-threshold-count` | Consecutive failures = unhealthy (2-10) | `2` |
| `success-codes` | HTTP status = healthy | `200` or `200-299` |
| `load-balancer-name` | Name of ALB in AWS | `my-app-alb` |

### Target Type: Instance vs IP Mode

**Instance Mode** (default, traditional)
- ALB routes to **EC2 node IP + NodePort**
- Service type: Must be **NodePort** or **LoadBalancer**
- Traffic flow: ALB → Node → Service → Pod
- **Use when:** Mixed workloads, legacy deployments
- **Limitation:** Extra network hop reduces performance

**IP Mode** (modern, container-native)
- ALB routes directly to **Pod IP**
- Service type: Must be **ClusterIP**
- Traffic flow: ALB → Pod (direct)
- **Use when:** Container-first deployments, performance-critical
- **Limitation:** Pods must be on same VPC (ENI limitation in multi-AZ)

### Health Checks in HTTP Ingress

- ALB **periodically checks** if pods are healthy before sending traffic
- If pod is unhealthy, ALB removes it from targets
- Prevents users from hitting broken pods

Health check logic:
```
ALB: GET /health → Pod
                    ↓
              Pod responds with status
                    ↓
ALB: If 200 OK → mark HEALTHY
ALB: If timeout/error → mark UNHEALTHY
```

### How HTTP Ingress Routes Traffic

1. User makes HTTP request to ALB DNS
2. ALB checks Ingress rules (host, path, etc.)
3. ALB finds matching service backend
4. ALB determines target (node or pod) based on target-type
5. ALB checks target health status
6. If healthy, routes traffic; if not, tries another target

---

## Topic 04: Kubernetes Ingress — HTTPS

### What is HTTPS?

- HTTP with **TLS/SSL encryption** (like a secret code)
- Proves the website is **authentic** using digital certificates
- Traffic is encrypted between browser and server


### SSL/TLS Certificates

- **Certificate** — Digital document that proves you own a domain
- **Certificate Authority (CA)** — Organization that issues certificates
- **AWS Certificate Manager (ACM)** — AWS service that provides **free** certificates
- **Certificate ARN** — Amazon Resource Name (unique identifier for certificate)

### Types of Certificates

- **Self-Signed** — You create it (not trusted by browsers) ❌
- **Domain Validated (DV)** — CA verifies you own domain ✅
- **Organization Validated (OV)** — CA verifies company details
- **Extended Validation (EV)** — CA does deep verification


### How HTTPS Ingress Works

```
User: https://myapp.com
           ↓
ALB: Receives HTTPS request on port 443
     ↓
ALB: Looks up certificate for myapp.com (from ACM)
     ↓
ALB: Performs TLS handshake with browser
     ↓
ALB: Routes HTTPS traffic to backend service
     ↓
Backend: Traffic arrives encrypted
```

### SSL Redirect Mechanism

- **Without redirect** — User can access both HTTP and HTTPS
- **With redirect** — ALB automatically redirects HTTP → HTTPS
- HTTP request (port 80) gets **301 Moved Permanently** response to HTTPS (port 443)
- Browser follows redirect automatically

---

## Topic 05: Health Checks

### Purpose of Health Checks

- **Goal:** Only send traffic to healthy pods
- **Mechanism:** ALB sends periodic requests to check pod status
- **Result:** If pod is unhealthy, ALB stops routing traffic to it

### Health Check Process

```
Time: 0s   → ALB sends first health check
            Pod responds: 200 OK (1/2 successes)

Time: 15s  → ALB sends second health check
            Pod responds: 200 OK (2/2 successes)
            → Target marked: HEALTHY ✅

If pod becomes unhealthy:

Time: 0s   → ALB sends health check
            Pod responds: 500 error (1/2 failures)

Time: 15s  → ALB sends health check
            Pod responds: 500 error (2/2 failures)
            → Target marked: UNHEALTHY ❌
            → ALB stops sending traffic
```

### Health Check Configuration

```yaml
alb.ingress.kubernetes.io/healthcheck-path: /actuator/health/readiness
alb.ingress.kubernetes.io/healthcheck-protocol: HTTP
alb.ingress.kubernetes.io/healthcheck-port: traffic-port
alb.ingress.kubernetes.io/healthcheck-interval-seconds: '15'
alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
alb.ingress.kubernetes.io/healthy-threshold-count: '2'
alb.ingress.kubernetes.io/unhealthy-threshold-count: '2'
alb.ingress.kubernetes.io/success-codes: '200'
```

**Configuration Details:**
- `healthcheck-path` — Application endpoint that returns health status
- `healthcheck-protocol` — Protocol for checking (HTTP for web apps)
- `healthcheck-port` — Use `traffic-port` (same as service port)
- `interval-seconds` — Don't check too often (saves CPU)
- `timeout-seconds` — Must be less than interval
- `healthy-threshold` — Prevents false positives from single failure
- `unhealthy-threshold` — Prevents false negatives
- `success-codes` — HTTP status that means "healthy"

### Best Practices for Health Checks

- **Use app-specific endpoints** — Don't just check if port is open
- **Health endpoint should be fast** — Don't query database
- **Return correct status codes** — 200 = healthy, 5xx = unhealthy
- **Implement graceful shutdown** — Health check returns 503 during shutdown
- **Monitor health check metrics** — Track how often targets are marked unhealthy

---

## Ingress vs Service Comparison

| Feature | Ingress | Service |
|---------|---------|---------|
| **OSI Layer** | Layer 7 (Application) | Layer 4 (Transport) |
| **Routing Type** | URL/domain based | IP:Port based |
| **Use Case** | Production web apps | Internal communication |
| **Load Balancer** | One LB for many services | One LB per service |
| **Cost** | Lower (shared LB) | Higher (dedicated LB) |
| **Configuration** | Via Ingress manifest | Via Service spec |
| **External Access** | Yes, HTTP(S) | Via NodePort/LoadBalancer |

---

## Key Concepts

### Ingress Class

- **Purpose:** Specifies which Ingress controller processes the resource
- **Example:** `ingressClassName: alb` means AWS Load Balancer Controller
- **Other options:** `nginx`, `gce`, custom controllers
- **Benefits:** Cluster can have multiple controllers for different routing needs

### Service Backend

- **Definition:** Kubernetes Service that receives traffic from Ingress
- **Discovery:** Ingress finds Service by name in same namespace
- **Port:** Must specify which port on Service to use
- **Connection:** Service then routes to matching pods via selectors

### Endpoint Slices

- **Definition:** Kubernetes tracks which Pod IPs belong to a Service
- **Updated:** When pods are created/deleted, endpoint slices update
- **Used by:** Ingress controller uses this to find pod IPs for registration

### Target Registration

- **Instance Mode:** ALB registers Node IPs as targets
- **IP Mode:** ALB registers individual Pod IPs as targets
- **Dynamic:** When pods scale up/down, targets are updated automatically

### Namespace Scoping

- **Services:** Cluster-scoped by name (can have conflicts across namespaces)
- **Ingress:** Namespace-scoped (can have same name in different namespaces)
- **Implication:** Ingress in namespace A cannot route to Service in namespace B directly

### Service Port vs Container Port

- **Container Port:** Port inside pod where app listens (defined in Deployment)
- **Service Port:** Port that Service listens on (can be different)
- **Target Port:** Maps Service port to container port
- **NodePort:** High-numbered port ALB uses to reach pods (instance mode)

---

## Limitations and Considerations

- **IP Mode limitation:** ENI limits mean IP mode doesn't work well in very large clusters
- **DNS propagation:** DNS changes take time (TTL), not instant
- **Certificate renewal:** ACM auto-renews, but monitor for failures
- **ALB limits:** AWS has request rate limits on ALB
- **Multi-namespace routing:** Ingress cannot route to services in different namespaces
- **Single-region:** ALB is regional, not global (use Route53 for global load balancing)

---

## Lab Implementation

### 1. Provision EKS Cluster & Configure kubectl

Provisioned the EKS cluster using Terraform and configured kubectl access:

```bash
terraform init
terraform validate
terraform plan
terraform apply -auto-approve
terraform output
```

```bash
aws eks update-kubeconfig --region ap-south-1 --name chirag-eks-cluster
kubectl get nodes
```

![EKS cluster nodes verified](images/Screenshot%202026-05-17%20211315.png)

![Pod Identity Agent add-on active](images/Screenshot%202026-05-17%20213532.png)

---

### 2. Set Environment Variables

```bash
export AWS_REGION="ap-south-1"
export EKS_CLUSTER_NAME="chirag-eks-cluster"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo $AWS_REGION
echo $EKS_CLUSTER_NAME
echo $AWS_ACCOUNT_ID
```

---

### 3. Install EKS Pod Identity Agent Add-on

The Pod Identity Agent is required so the ALB Controller pod can authenticate to AWS using its linked IAM role:

```bash
aws eks create-addon \
  --cluster-name ${EKS_CLUSTER_NAME} \
  --addon-name eks-pod-identity-agent

aws eks list-addons --cluster-name ${EKS_CLUSTER_NAME}
```

![IAM policy created](images/Screenshot%202026-05-17%20230214.png)

![IAM role created and policy attached](images/Screenshot%202026-05-17%20230406.png)

---

### 4. Create IAM Policy & Role for ALB Controller

The AWS Load Balancer Controller needs IAM permissions to create and manage ALBs in the AWS account. Downloaded the official policy document and created the IAM policy:

```bash
# Download the official IAM policy from the AWS Load Balancer Controller repo
curl -o aws-load-balancer-controller-policy.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

# Create the IAM policy
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy_${EKS_CLUSTER_NAME} \
  --policy-document file://aws-load-balancer-controller-policy.json
```

Created the trust policy that allows EKS pods to assume the role via the Pod Identity Agent, then created the IAM role and attached the policy:

```bash
cat <<EOF > alb-controller-trust-policy.json
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

# Create the IAM Role
aws iam create-role \
  --role-name AmazonEKS_LBC_Role_${EKS_CLUSTER_NAME} \
  --assume-role-policy-document file://alb-controller-trust-policy.json

# Attach the policy to the role
aws iam attach-role-policy \
  --role-name AmazonEKS_LBC_Role_${EKS_CLUSTER_NAME} \
  --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy_${EKS_CLUSTER_NAME}

# Verify attachment
aws iam list-attached-role-policies \
  --role-name AmazonEKS_LBC_Role_${EKS_CLUSTER_NAME}
```

![Pod Identity Association created](images/Screenshot%202026-05-17%20230556.png)

![ALB Controller pods running](images/Screenshot%202026-05-17%20230906.png)

---

### 5. Create Pod Identity Association

Linked the IAM role to the `alb-controller-sa` Kubernetes Service Account so the controller pod can authenticate to AWS via the Pod Identity Agent:

```bash
aws eks create-pod-identity-association \
  --cluster-name ${EKS_CLUSTER_NAME} \
  --namespace kube-system \
  --service-account alb-controller-sa \
  --role-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/AmazonEKS_LBC_Role_${EKS_CLUSTER_NAME}
```

![ALB Controller deployment verified](images/Screenshot%202026-05-17%20231045.png)

---

### 6. Install AWS Load Balancer Controller via Helm

Added the EKS Helm chart repository and installed the AWS Load Balancer Controller. The VPC ID is passed explicitly since IMDS auto-detection is restricted on this cluster:

```bash
# Add the EKS Helm chart repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Fetch the cluster's VPC ID
VPC_ID=$(aws eks describe-cluster \
  --name ${EKS_CLUSTER_NAME} \
  --query "cluster.resourcesVpcConfig.vpcId" \
  --output text)
echo $VPC_ID

# Install the controller
helm install alb-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=${EKS_CLUSTER_NAME} \
  --set region=${AWS_REGION} \
  --set vpcId=${VPC_ID} \
  --set serviceAccount.create=true \
  --set serviceAccount.name=alb-controller-sa
```

![All microservices deployed and running](images/Screenshot%202026-05-17%20231522.png)

> **Helm flags explained:**
> - `serviceAccount.create=true` — Creates the ServiceAccount automatically during installation
> - `serviceAccount.name` — Must match the name used in the Pod Identity Association
> - `vpcId` — Required when IMDS auto-detection is restricted on the cluster
> - `region` — Explicitly sets the AWS region when IMDS access is limited

Validated the controller was running correctly:

```bash
helm list -n kube-system
helm status alb-controller -n kube-system

kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
kubectl get deployment -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

![Instance mode Ingress details](images/Screenshot%202026-05-17%20233041.png)

---

### 7. Deploy the Retail Sample Application

With the ALB Controller running, deployed all manifests for the retail store application recursively. This includes the catalog, cart, checkout, orders, UI microservices, and both Ingress resources (instance mode and IP mode):

```bash
kubectl apply -R -f ./Retail-k8s-manifests/
```

Verified all deployments, services, and Ingress resources were created:

```bash
kubectl get all -A
kubectl get ingress -A
```

![IP mode Ingress details](images/Screenshot%202026-05-17%20233300.png)

![Both ALBs visible in AWS console](images/Screenshot%202026-05-17%20233451.png)

---

### 8. Inspect Ingress & ALB Provisioning

Described both Ingress resources to confirm the ALB Controller had provisioned the load balancers and registered the targets:

```bash
kubectl describe ingress chirag-eks-cluster-instance-mode
kubectl describe ingress chirag-eks-cluster-ip-mode
```

![Retail store home page — instance mode ALB](images/Screenshot%202026-05-17%20234157.png)

![Health check endpoint — instance mode ALB](images/Screenshot%202026-05-17%20234500.png)

---

### 9. Validate the Application

Accessed the application via the ALB DNS name in the browser and via curl to confirm both instance mode and IP mode Ingresses were routing traffic correctly:

```bash
curl -v http://<ALB-DNS-Name>
```

- `http://<ALB-DNS-Name>` — Retail store home page
- `http://<ALB-DNS-Name>/topology` — Service topology
- `http://<ALB-DNS-Name>/actuator/health/readiness` — Health check endpoint

![Topology endpoint — instance mode ALB](images/Screenshot%202026-05-17%20234514.png)

![Retail store home page — IP mode ALB](images/Screenshot%202026-05-17%20234538.png)

![Topology endpoint — IP mode ALB](images/Screenshot%202026-05-17%20234615.png)

![Health check endpoint — IP mode ALB](images/Screenshot%202026-05-17%20234816.png)


---

### 10. Cleanup

Deleted all Kubernetes resources, uninstalled the Helm release, and destroyed the cluster:

```bash
kubectl delete -R -f ./Retail-k8s-manifests/

helm uninstall alb-controller -n kube-system

terraform destroy -auto-approve
```

![ALB target groups healthy in AWS console](images/Screenshot%202026-05-17%20235843.png)

![Cluster destroyed](images/Screenshot%202026-05-18%20000022.png)

---

## Summary

Day 10 focused on exposing Kubernetes applications to the internet using Ingress and the AWS Load Balancer Controller on EKS.

- **Ingress** — A Layer 7 Kubernetes API object that routes HTTP(S) traffic to services based on host/path rules; one ALB serves multiple services, making it far more cost-effective than a LoadBalancer service per microservice
- **AWS Load Balancer Controller** — A Kubernetes controller that watches Ingress resources and automatically provisions and manages AWS ALBs; installed via Helm into `kube-system`
- **Pod Identity Association** — Binds the IAM role (with ALB management permissions) to the `alb-controller-sa` service account so the controller can call AWS APIs
- **Instance mode vs IP mode** — Instance mode routes ALB traffic to node NodePorts (extra hop); IP mode routes directly to pod IPs (lower latency, requires ClusterIP services)
- **Ingress annotations** — Control all ALB behaviour (scheme, target-type, health check path/interval/thresholds, SSL certificate ARN, HTTP→HTTPS redirect) directly from the Ingress manifest
- **Health checks** — ALB periodically hits the configured health check path; only healthy targets receive traffic, preventing users from hitting broken pods
