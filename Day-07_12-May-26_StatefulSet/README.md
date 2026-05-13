# Day 07 — Kubernetes StatefulSet

## Topic 01: What is a Stateful Application?

A stateful application **remembers data between sessions**. It stores information (state) so that the next time you interact with it, it knows what happened before.

> **Example:** A MySQL database remembers all your records even after a restart. If you insert a row today, it's still there tomorrow — that's stateful behavior.

Compare this to a **stateless** app like a simple web server that just responds to requests without remembering anything about previous ones.

---

## Topic 02: What is a StatefulSet?

A StatefulSet is a Kubernetes resource used to **deploy and manage stateful applications**. Unlike a regular Deployment, it gives each pod a **stable identity and its own persistent storage**.

### Key Features

| Feature | What it means |
|---|---|
| Stable Network Identity | Each pod gets a fixed, predictable name (e.g., `mysql-0`, `mysql-1`) |
| Persistent Storage | Each pod gets its own volume that survives restarts |
| Ordered Startup/Shutdown | Pods start and stop one at a time, in order |
| Rolling Updates | Updates happen pod-by-pod with no downtime |

### Pod Naming in StatefulSet

If you create a StatefulSet named `mysql` with 3 replicas, Kubernetes creates:

```
mysql-0   ← starts first
mysql-1   ← starts after mysql-0 is ready
mysql-2   ← starts after mysql-1 is ready
```

Each pod also gets a stable DNS name:

```
mysql-0.mysql-service.default.svc.cluster.local
mysql-1.mysql-service.default.svc.cluster.local
```

This is different from a Deployment where pods get random names like `mysql-7d9f8b-xkqp2`.

---

## Topic 03: StatefulSet YAML Example

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: "mysql-service"   # must match a Headless Service
  replicas: 3
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "password"
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
  volumeClaimTemplates:           # each pod gets its own PVC
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
```

> `volumeClaimTemplates` automatically creates a separate PersistentVolumeClaim for each pod — `data-mysql-0`, `data-mysql-1`, `data-mysql-2`.

---

## Topic 04: When to Use StatefulSet

Use StatefulSet when your app needs:
- **Its own persistent storage per pod** — e.g., each DB node stores different data
- **A stable, predictable hostname** — e.g., a cluster node that other nodes connect to by name
- **Ordered startup** — e.g., a primary DB must start before replicas

### Common Use Cases

| App | Why StatefulSet? |
|---|---|
| MySQL / PostgreSQL | Needs persistent data + ordered primary/replica setup |
| MongoDB | Each replica set member needs a stable identity |
| Kafka | Brokers need stable IDs and their own storage |
| RabbitMQ | Cluster nodes discover each other by hostname |
| Redis Cluster | Nodes need stable addresses for cluster communication |
| Elasticsearch | Each node stores its own shard data |

### When NOT to Use StatefulSet

Use a regular **Deployment** instead when:
- Your app is **stateless** (e.g., a REST API, frontend app)
- Pods don't need their own storage
- Pod identity/order doesn't matter

> **Example:** A Node.js API server that reads from a database but doesn't store anything itself — use a Deployment, not a StatefulSet.

---

## Topic 05: What is a Headless Service?

A Headless Service is a Kubernetes Service with `clusterIP: None`. Instead of giving you one IP that load-balances across pods, it gives you **direct DNS access to each individual pod**.

### Why is it Needed with StatefulSet?

StatefulSet pods need to be reachable by their individual names (e.g., `mysql-0`, `mysql-1`). A regular ClusterIP service hides the individual pods behind one IP. A Headless Service exposes each pod directly via DNS.

### Headless Service YAML Example

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-service
spec:
  clusterIP: None          # this makes it headless
  selector:
    app: mysql
  ports:
  - port: 3306
```

With this, each pod is reachable at:

```
mysql-0.mysql-service.default.svc.cluster.local
mysql-1.mysql-service.default.svc.cluster.local
mysql-2.mysql-service.default.svc.cluster.local
```

### ClusterIP vs Headless Service

| | ClusterIP Service | Headless Service |
|---|---|---|
| Has a virtual IP? | Yes | No (`clusterIP: None`) |
| Load balancing? | Yes | No |
| DNS resolves to | Single service IP | Individual pod IPs |
| Use case | Stateless apps | StatefulSets, direct pod access |

> **Analogy:** ClusterIP is like calling a call center (one number, any agent answers). Headless is like having each agent's direct phone number.

---

## Topic 06: StatefulSet vs Deployment — Quick Comparison

| | Deployment | StatefulSet |
|---|---|---|
| Pod names | Random (`app-7d9f-xkq`) | Ordered (`app-0`, `app-1`) |
| Storage | Shared or none | Each pod gets its own PVC |
| Startup order | All at once | One by one, in order |
| Use for | Stateless apps | Stateful apps (DBs, queues) |

---

## Lab Implementation

### 1. Provision EKS Cluster (Terraform)

First I provisioned the EKS cluster using Terraform by running the below commands:

```bash
terraform init
terraform validate
terraform plan
terraform apply -auto-approve
terraform output
```

Once the EKS cluster was created, I configured access to it by updating the kube config file:

```bash
aws eks --region us-east-1 update-kubeconfig --name chirag-eks-cluster
```

I validated the access by checking the nodes available:

```bash
kubectl get nodes
```

![kubectl get all after deploying manifests](images/Screenshot%202026-05-12%20154836.png)

### 2. Deploy K8s Manifests

I then deployed the k8s manifest files in the following order:

```bash
kubectl apply -f mysql-config.yaml
kubectl apply -f services.yaml
kubectl apply -f statefulset.yaml
kubectl apply -f deployment.yaml
```
![kubectl describe sts catalog-mysql](images/Screenshot%202026-05-12%20154959.png)

Once created, I validated everything by running:

```bash
kubectl get all
kubectl get configmap
```

![nslookup on headless service and pod DNS](images/Screenshot%202026-05-12%20160929.png)

I also checked the specifications of the StatefulSet named `catalog-mysql`:

```bash
kubectl describe sts catalog-mysql
```

![DNS name stable after pod re-creation](images/Screenshot%202026-05-12%20161149.png)

### 3. Validate Stable DNS Name

To validate the StatefulSet concept of stable DNS names, I first ran a test pod for DNS checking:

```bash
kubectl run dns-test --image=busybox:1.28 -it --rm
```

Once I got terminal access to the pod, I ran `nslookup` to check the DNS of the service and individual pods:

```bash
nslookup mysql
nslookup catalog-mysql-1.mysql.default.svc.cluster.local
```



I noted the private IP bound to this DNS name. I then deleted that specific pod — which was re-created by the StatefulSet controller — to check whether the IP changes but the DNS name stays the same:

```bash
# Delete the specific pod
kubectl delete pod catalog-mysql-1

# Check DNS again from the dns-test pod
nslookup catalog-mysql-1.mysql.default.svc.cluster.local
```

The DNS name remained the same even after the pod was re-created with a new IP — which is the core concept of StatefulSet: **stable DNS identity regardless of pod restarts**.

### 4. Validate Ordered Scaling

I checked the scaling behaviour of the StatefulSet to verify that pods are created in ascending order and terminated in descending order:

```bash
# Scale up
kubectl scale statefulset catalog-mysql --replicas=4

# In another terminal, watch real-time pod updates
watch kubectl get all -o wide

# Scale down
kubectl scale statefulset catalog-mysql --replicas=2
```

![Ordered scale up — catalog-mysql-3 created last](images/Screenshot%202026-05-12%20162011.png)

![Ordered scale down — catalog-mysql-3 terminated first](images/Screenshot%202026-05-12%20162158.png)

![Final pod state after scale down](images/Screenshot%202026-05-12%20162303.png)

When scaling up, the new pod was created with the name `catalog-mysql-3` (ascending order). When scaling down, `catalog-mysql-3` was the first to be terminated (descending order) — confirming the ordered startup and shutdown behaviour of StatefulSets.

### 5. Port-Forward & Test APIs

I also accessed the catalog service by doing port-forwarding to localhost port 3000:

```bash
kubectl port-forward svc/catalog-service 3000:8080
```

Then I accessed the following URLs in the browser and got valid responses, confirming the service is working fine and routing traffic correctly to the pods:

```
http://localhost:3000/topology
http://localhost:3000/health
http://localhost:3000/catalog/tags
http://localhost:3000/catalog/products
```

![Port-forward and API response](images/Screenshot%202026-05-12%20183844.png)

![API response from catalog service](images/Screenshot%202026-05-12%20183849.png)


### 6. Cleanup

Once everything was validated, I cleaned up all the k8s resources:

```bash
kubectl delete -f mysql-config.yaml
kubectl delete -f services.yaml
kubectl delete -f statefulset.yaml
kubectl delete -f deployment.yaml

kubectl get all
kubectl get cm
```
![catalog/products API response](images/Screenshot%202026-05-12%20184720.png)

After confirming everything was cleaned up in the EKS cluster, I decommissioned the cluster using Terraform:

```bash
terraform plan -destroy
terraform destroy -auto-approve
```

![Cleanup — all resources deleted](images/Screenshot%202026-05-12%20185658.png)

---

## Summary

Day 07 focused on understanding StatefulSets and how Kubernetes manages stateful applications differently from stateless ones.

- Understood the difference between **stateful and stateless applications** — stateful apps like databases persist data across restarts, while stateless apps like REST APIs do not
- Learned what a **StatefulSet** is and its key features — stable pod names (`mysql-0`, `mysql-1`), per-pod persistent storage via `volumeClaimTemplates`, ordered startup/shutdown, and rolling updates
- Understood when to use StatefulSet vs Deployment — StatefulSets are for databases and clustered apps that need stable identity and storage; Deployments are for stateless workloads
- Learned about **Headless Services** (`clusterIP: None`) and why they are required with StatefulSets — they expose each pod directly via DNS instead of load-balancing behind a single virtual IP
- Validated the **stable DNS name** concept hands-on — deleted a pod and confirmed the DNS name remained unchanged after the pod was re-created with a new IP
- Observed **ordered scaling** behaviour — pods scale up in ascending order (`catalog-mysql-3` created last) and scale down in descending order (`catalog-mysql-3` terminated first)
- Verified end-to-end connectivity by port-forwarding the catalog service and hitting the application APIs successfully
