# Day 06 — Kubernetes: Pods, Deployment, Service & ConfigMap

## Topic 01: Kubernetes Pods

### What is a Pod?

- The **smallest deployable unit** in a Kubernetes cluster — a wrapper or box that contains one or more containers along with shared network, storage, and identity
- Kubernetes never runs containers directly — it deploys pods, and inside those pods containers are spun up using the docker image
- All pods are deployed on worker nodes which are part of the EKS cluster — the node's CPU and memory details are used by the **kube-scheduler** to decide which node is best suited for pod deployment

### One Container Per Pod — Best Practice

One container per pod is the best practice followed in Kubernetes.

**Reason:** Kubernetes' basic unit is the pod, not the container inside it. So whenever scaling comes into picture, Kubernetes multiplies pods and not the containers inside them. If we create 2 containers of the same image in one pod then scaling multiple pods comes with additional containers. Also, the same image containers cannot listen on the same port (e.g. port 80). Additionally, a Service (load balancer) sends traffic to the pod and not to the containers inside it.

### Multi-Container Patterns (Niche Use Cases)

There are niche requirements where multi-container patterns are used:

- **Sidecar** — a helper container in the same pod for log ingestion purposes
- **Init Container** — runs before the main container starts, e.g. DB migration or setting up some environment
- **Ambassador** — a proxy container

### Networking in Pods

- All containers in a pod share the **same IP**, so distinguishing them from outside the pod gets confusing
- Internally, containers in the same pod communicate via `localhost`
- Multi-containers in the same pod share the same **network and storage/volume**

### Pod Commands

- `kubectl describe pod <pod-name>` — the most important troubleshooting command for pods; displays all detailed information like which node it is running on, events, volumes, networks, namespaces, labels, etc.
- `kubectl logs -f <pod-name>` — get the logs of a pod
- `kubectl port-forward pod/<pod-name> <host-port>:<container-port>` — does port-forwarding and allows access to the application via `localhost:<host-port>` until the port-forwarding session is active
- `kubectl exec -it pod/<pod-name> -- bash` — gives shell access to the container running inside the pod; we can do any troubleshooting or run any command inside the container using this

---

## Topic 02: Kubernetes Deployment

### Problems with Pods and How Deployments Resolve Them

**1. Node Events**

Node events like OS updates, patching, scaling, or spot instance interruptions — during these activities, if we are deploying pods manually, Kubernetes kills all the pods inside that node (**Draining**). This happens automatically but Kubernetes does not create new pods to cover those in another node since we are managing creation manually. This situation is handled by the **Deployment Controller**.

The Deployment Controller maintains the **replica count** (the number of pods that shall be up and running at all times). So whenever a node is going to drain, the Deployment Controller makes sure that the replica set count of pods are created in other nodes before draining the existing pods.

**2. High Traffic Period**

During high peak traffic periods, manual pod management becomes hectic as we need to scale new pods manually. Using Deployment and **Horizontal Pod Autoscaler (HPA)** this can be done automatically. HPA monitors the CPU and memory usage of pods and based on the threshold defined, it automatically scales the number of pods up or down to handle the traffic load.

**3. Application Updates**

When we need to update the application running inside the pods, if we are managing pods manually we need to delete the existing pods and create new ones with the updated image — which causes downtime. Using the Deployment Controller we can do **rolling updates**, which means it will create new pods with the updated image and once they are up and running it will delete the old pods. This way there is no downtime during application updates.

### Flow

```
Deployment → ReplicaSet → Pods (p1, p2, p3 pods get created)
              (replica-count = 3)
```

### Deployment Commands

- `kubectl apply -f catalog-deploy.yaml` — deploys the Deployment, ReplicaSet and Pods in the EKS cluster
- `kubectl get deployment/replicaset/pods` — displays the pods/deployment/replicaset currently deployed or available
- `kubectl rollout status deployment/<name>` — provides the status of the last deployment, whether it was successfully rolled out or not
- `kubectl describe deploy <name>` — provides in-depth details related to the deployment only, like Replicas status, strategyType, RollingUpdateStrategy, events, etc.
- `kubectl describe rs <name>` — provides in-depth details related to the ReplicaSet like selector, labels, annotations, controlled by which deployment, replicas current state, pods status, events, etc.
- `kubectl port-forward deploy/<name> <host-port>:<container-port>` — does port forwarding for the pod (behaviour with multiple pods in a deployment is unclear)
- `kubectl scale deployment <name> --replicas=3` — asks the ReplicaSet to create 3 pods; takes hardly 5–10s to create the pods
- `kubectl rollout history deployment/<name>` — displays the number of revisions done after deploying the deployment
- `kubectl set image deployment/catalog catalog=<updated-image>` — updates the image in the deployment config; creates another ReplicaSet with the updated image and simultaneously deletes the pods in the previous ReplicaSet. At the end it does **not** delete the previous ReplicaSet, just the pods
- `kubectl rollout undo deployment/<name>` — undoes the last rollout and rolls back to the previous version of the deployment; creates new pods with the previous image and deletes the pods with the updated image. At the end it does **not** delete the ReplicaSet, just the pods
- `kubectl rollout undo deployment/<name> --to-revision=2` — rolls back the deployment to the second revision (e.g. `1=>old-image`, `2=>updated-image`, `3=>old-image`)

> **Note:** Every rollout or rollback creates a new revision version.

---

## Topic 03: Kubernetes Service

### Why Do We Need Services?

- Pods are ephemeral — they die and get new IPs every time
- You can't hardcode pod IPs in your app
- A Service gives a **stable endpoint** (IP + DNS name) that never changes, even if the pods behind it keep changing

### How Does a Service Find Pods?

- Services use **Label Selectors** to find pods; the service continuously watches pods matching the selector
- When a pod is added or removed, the service updates its list of endpoints accordingly
- `kubectl get endpointslices` — to get endpoint details

### Service Types

**1. ClusterIP (Default)**
- Only accessible inside the cluster; used for internal communication between services
- e.g. 2 microservices are deployed and their pods need to communicate with each other — ClusterIP provides a single stable endpoint for that communication

**2. NodePort**
- Exposes the service on each node's IP at a static port (30000–32767)
- Accessible from outside the cluster via `NodeIP:NodePort`

**3. LoadBalancer**
- Creates an external load balancer (AWS ELB, GCP LB); used in cloud environments for production traffic
- Auto-assigns a public IP

**4. ExternalName**
- Maps a service to an external DNS name (e.g. `db.example.com`); it is not proxying, just DNS resolution
- Used to access external services from inside the cluster

**5. Headless Service**
- Specifically used for StatefulSets where stateful applications are deployed; these pods are usually not removed, so we have to directly use the pod's IP for communication
- To do so, set `clusterIP: None` in the service YAML file

### Key Difference Between Service and Ingress

- Service works at **Layer 4** (TCP/UDP — IP and port based routing), but Ingress works at **Layer 7** (HTTP/HTTPS — API path or URL based)
- Service is only used for internal or simple external tasks, but Ingress is used for production-level HTTP traffic routing

---

## Topic 04: Kubernetes ConfigMap

- ConfigMap is used to store **non-sensitive** configuration data in key-value pairs; it allows us to decouple configuration from application code and manage it separately, so we can easily update the configuration without redeploying the application

- In simpler terms: if the application deployment requires some environment variables to be created before container creation, hardcoding those environment variables in `deployment.yaml` is not best practice and is not recommended — we cannot reuse the same `deployment.yaml` for another prod/dev/test environment. By using ConfigMap we can define the env variables in it and reference them in `deployment.yaml` dynamically

```yaml
containers:
  - name: catalog
    envFrom:
      - configMapRef:
          name: catalog
```

---

## Lab Implementation

### 1. Provision EKS Cluster (Terraform)

First I created the EKS cluster using Terraform by running the below commands:

```bash
terraform init
terraform validate
terraform plan
terraform apply -auto-approve
terraform output
```

After that I used the below command to update the kube-config and get access to the EKS cluster:

```bash
aws eks update-kubeconfig --region ap-south-1 --name chirag-eks-cluster
```

I validated the access to the EKS cluster by running:

```bash
kubectl get nodes
```

### 2. Deploy & Explore

Once I got access to the cluster, I deployed the `deployment.yaml` manifest file and created the ReplicaSet, Pods and Deployment in the default namespace. I also used the below commands for learning and troubleshooting the components that were created:

```bash
kubectl apply -f deployment.yaml
kubectl get all -o wide
kubectl rollout status deploy catalog
kubectl describe pod <pod-name>
```

### 3. Port-Forward & Test APIs

Then I tried to access the application via port-forwarding:

```bash
kubectl port-forward deploy/catalog 3000:8080
```

And tried to access the application using the below API calls:

```
http://localhost:3000/topology
http://localhost:3000/health
http://localhost:3000/catalog/products
http://localhost:3000/catalog/tags
```

### 4. Scaling

Later I tried scaling the replicas and checked the behaviour of the deployment and pods:

```bash
kubectl scale deployment catalog --replicas=5
kubectl get pods -o wide

# Scale back down
kubectl scale deployment catalog --replicas=2
```

### 5. Rolling Update & Rollback

Once that was completed, I tried to understand how deployment rolls out changes by updating the image of the catalog service and rolling out the update to check the behaviour:

```bash
kubectl rollout history deploy catalog
kubectl set image deployment/catalog catalog=public.ecr.aws/aws-containers/retail-store-sample-catalog:1.3.0
kubectl rollout history deploy catalog
kubectl rollout status deploy catalog

kubectl get pods -o wide
kubectl describe pod <pod-name> | grep Image
```

Lastly I rolled back to the previous revision version using the `kubectl rollout undo` command:

```bash
kubectl rollout undo deploy catalog --to-revision=1
kubectl rollout history deploy catalog
kubectl get all
kubectl describe pod <pod-name> | grep Image
```

### 6. Service

Once the deployment lab was completed, I started the implementation for Service. First I created the service using the `service.yaml` manifest file and then described it to check the details and metadata:

```bash
kubectl apply -f service.yaml
kubectl get svc
kubectl describe svc catalog-service
```

After that I learned about EndpointSlices and pod matching:

```bash
kubectl get pods -o wide
kubectl get endpointslices -l kubernetes.io/service-name=catalog-service
```

To test the Kubernetes Service, I ran a test curl container and validated the application API:

```bash
kubectl run test --image=curlimages/curl -it --rm -- sh
curl catalog-service:8080/health
```

Also checked the DNS resolution of the service:

```bash
kubectl run dns-test --image=busybox:1.28 -it --rm
nslookup catalog-service
```

### 7. ConfigMap

First I created the ConfigMap using the `configmap.yaml` manifest file and then described it to check the details and metadata:

```bash
kubectl apply -f configmap.yaml
kubectl get configmap
kubectl describe configmap catalog-configmap
```

As my deployment manifest was currently deployed without using the ConfigMap, I updated the deployment manifest file first and then re-applied it:

```bash
kubectl apply -f deployment.yaml
kubectl get all -o wide
kubectl exec -it <pod-name> -- env | grep RETAIL
```

I validated the changes by checking the env variables in one of the pods.

### 8. Cleanup

Finally, to clean up I deleted the deployment, service and configmap, and lastly ran `terraform destroy` to destroy the EKS cluster and other resources:

```bash
kubectl delete -f deployment.yaml
kubectl delete -f service.yaml
kubectl delete -f configmap.yaml
terraform destroy -auto-approve
```

---

## Summary

Day 06 focused on understanding and hands-on implementation of core Kubernetes workload and configuration primitives — Pods, Deployments, Services, and ConfigMaps.

- Understood **Pods** as the smallest deployable unit in Kubernetes — why one container per pod is best practice, how multi-container patterns (Sidecar, Init, Ambassador) work, and how containers within a pod share network and storage
- Learned why **Deployments** are needed over manual pod management — how the Deployment Controller handles node drain events, high traffic scaling via HPA, and zero-downtime rolling updates by managing ReplicaSets
- Practiced **rollouts and rollbacks** — updating a container image triggers a new ReplicaSet, old ReplicaSets are retained but their pods are removed, and every rollout/rollback increments the revision number
- Understood **Services** as stable endpoints that abstract away ephemeral pod IPs using Label Selectors — explored all 5 service types (ClusterIP, NodePort, LoadBalancer, ExternalName, Headless) and the key difference between Service (L4) and Ingress (L7)
- Learned how **ConfigMaps** decouple environment-specific configuration from the deployment manifest, making the same `deployment.yaml` reusable across dev/staging/prod environments
- Validated everything hands-on — port-forwarding, scaling, rolling updates, rollbacks, EndpointSlice inspection, DNS resolution via busybox, and env variable verification inside a running pod
