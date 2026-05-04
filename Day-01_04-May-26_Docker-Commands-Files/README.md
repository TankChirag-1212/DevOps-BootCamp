# Day 01 — Docker Commands & AWS Setup

## Section 02_01: Setup AWS Environment & Provision EC2 with Terraform

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

## Section 02_02: Pull & Run Docker Image from Docker Hub

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

## Section 02_03: Build Docker Image & Push to Docker Hub

Logged into Docker Hub on the EC2 instance using a PAT (Personal Access Token) for authentication:

```bash
docker login -u chirag1212
```

Fetched the retail store sample app source code at release `v1.5.0` from GitHub:

```bash
wget https://github.com/aws-containers/retail-store-sample-app/archive/refs/tags/v1.5.0.zip
unzip v1.5.0.zip
```

Made changes to the UI in:
```bash
vim retail-store-sample-app-1.5.0/src/ui/src/main/resources/templates/home.html
```

Built the new Docker image from `./src/ui` (which contains the Dockerfile):

```bash
cd retail-store-sample-app-1.5.0/src/ui
docker build -t chirag1212/devops-bootcamp:retail-store-v3_Day_01 .
```

![Docker Login](images/Screenshot%202026-05-04%20210931.png)

Pushed the image to Docker Hub:

```bash
docker push chirag1212/devops-bootcamp:retail-store-v3_Day_01
```

![Code Changes & Build](images/Screenshot%202026-05-04%20211126.png)

Ran a container from the newly pushed image to validate the changes:

```bash
docker run --name retail-store-v3 -p 3000:8080 -d chirag1212/devops-bootcamp:retail-store-v3_Day_01
```

Accessed `http://<ec2-public-ip>:3000` — the changes made in `home.html` were reflecting as expected.

![Docker Push](images/Screenshot%202026-05-04%20211334.png)

**Cleanup:**

```bash
docker ps -a
docker images
docker rm -f $(docker ps -qa)
docker rmi $(docker images -q)
```

![Web App with Changes](images/Screenshot%202026-05-04%20211622.png)

---

## Summary

On Day 01, the focus was on setting up a cloud environment and getting hands-on with Docker from scratch.

- Provisioned an **EC2 instance on AWS** (ap-south-1) using **Terraform** — wrote reusable config files with variables, security groups, and auto-install scripts for Docker via `user_data`
- **SSH'd into the instance**, verified connectivity, and manually installed Docker, then added the user to the docker group for passwordless access
- Pulled a pre-built **retail store web app** image from Docker Hub, ran it as a container on port 3000, accessed it via browser, exec'd into it, and practiced stop/start/cleanup commands
- **Built a custom Docker image** by cloning the retail store app source (v1.5.0), modifying the `home.html` UI file, building the image locally, pushing it to Docker Hub, and validating the changes live in the browser