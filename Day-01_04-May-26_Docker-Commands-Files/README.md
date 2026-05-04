# Day 01 — Docker Commands & AWS Setup

## Section 02-01: Setup AWS Environment & Provision EC2 with Terraform

Provisioned an EC2 instance using Terraform with the following configuration:

| Setting        | Value                                      |
|----------------|--------------------------------------------|
| AMI            | Ubuntu Server Pro 22.04 LTS (amd64 jammy)  |
| Instance Type  | t2.medium                                  |
| Storage        | 30 GB                                      |
| Key Pair       | BootCamp_Chirag_Tank_key                   |
| Security Group | Allow SSH (port 22) and port 3000 for My IP|
| Region         | ap-south-1                                 |

Created Terraform files: `main.tf`, `variables.tf`, `outputs.tf`, `terraform.tfvars`

**Steps to provision:**

```bash
terraform init
terraform validate
terraform fmt
terraform plan
terraform apply --auto-approve
```

![Docker Installed](images/Screenshot%202026-05-04%20155028.png)
![SSH Connection](images/Screenshot%202026-05-04%20155001.png)

---

## Section 02-01: SSH into EC2 & Install Docker

After provisioning, tested SSH connectivity and internet access via `ping google.com`.

```bash
ssh -i BootCamp_Chirag_Tank_key.pem ubuntu@<public-ip>
ping google.com
```



**Docker Installation:**

```bash
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
sudo apt update
sudo docker version
sudo systemctl status docker
```

![Terraform Apply](images/Screenshot%202026-05-04%20154816.png)


Added current user to the docker group to run Docker without `sudo`:

```bash
sudo usermod -aG docker $USER
docker run hello-world
docker ps -a
```

![Terraform Init](images/Screenshot%202026-05-04%20154719.png)
![Terraform Plan](images/Screenshot%202026-05-04%20154753.png)

---

## Section 02-02: Pull & Run Docker Image from Docker Hub

Pulled a sample retail store web application from Docker Hub:

```bash
docker pull stacksimplify/retail-store-sample-ui:1.0.0
docker run --name retail-store -p 3000:8080 -d stacksimplify/retail-store-sample-ui:1.0.0
```

![Docker Hello World](images/Screenshot%202026-05-04%20155619.png)
![Docker Pull & Run](images/Screenshot%202026-05-04%20155825.png)

Validated by accessing `http://<ec2-public-ip>:3000` in the browser — the retail store web app was accessible.

![Web App Accessible](images/Screenshot%202026-05-04%20160001.png)

**Access container terminal:**

```bash
docker exec -it retail-store /bin/bash
```

![Exec into Container](images/Screenshot%202026-05-04%20160324.png)

**Stop & Start container:**

```bash
docker stop retail-store
docker start retail-store
```

After stopping, the web app was inaccessible, and it became accessible again after restarting.

![Container Stopped - App Down](images/Screenshot%202026-05-04%20160840.png)
![Container Started - App Up](images/Screenshot%202026-05-04%20160957.png)

**Cleanup — remove containers and images:**

```bash
docker rm -f retail-store                    # stop and remove container
docker rm -f $(docker ps -aq)               # remove all containers
docker rmi stacksimplify/retail-store-sample-ui:1.0.0
```

![Cleanup Containers](images/Screenshot%202026-05-04%20161040.png)
![Cleanup Images](images/Screenshot%202026-05-04%20161116.png)
![Final State](images/Screenshot%202026-05-04%20161158.png)

---

## Section 02-03: Build Docker Image & Push to Docker Hub

> *(Coming soon)*
