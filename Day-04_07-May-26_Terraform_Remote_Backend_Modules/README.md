# Day 04 — Terraform Remote Backend & Modules


## Section 01: Terraform Remote Backend

### Question: Why Remote Backend is required?

By default Terraform stores the state file (`terraform.tfstate`) locally. This works fine for solo use but causes problems in teams — two people running `terraform apply` simultaneously can corrupt the state.

A **remote backend** solves this by:
- Storing state in a shared location (S3)
- Enabling **state locking** to prevent concurrent modifications
- Keeping sensitive state data off local machines

### S3 Backend Configuration

```hcl
backend "s3" {
  bucket       = "chirag-tank-bootcamp-454143665149-ap-south-1-an"
  key          = "dev/vpc/terraform.tfstate"
  region       = "ap-south-1"
  use_lockfile = true  # enables state locking using S3 native locking
}
```

| Field | Purpose |
|-------|---------|
| `bucket` | S3 bucket where state file is stored |
| `key` | Path/filename of the state file inside the bucket |
| `region` | Region where the S3 bucket exists |
| `use_lockfile` | Enables state locking to prevent concurrent applies |

> After adding the backend block, run `terraform init -migrate-state` to migrate the state from local backend to S3 backend.

---

## Section 02: Terraform Modules

### Question: What are Modules?

A module is a **reusable and structured collection of Terraform files**. Instead of writing all resources in a single flat file, modules let us group related resources together and call them from a root file.

### Module Storage Options

| Type | Description |
|------|-------------|
| Local file system | `./modules/vpc` — stored within the same repo |
| Public Registry | `registry.terraform.io` — community modules |
| Private Registry | HCP Terraform (Cloud) — organisation-scoped private modules |
| Public + Private : Git (GitHub/GitLab) | `git::https://github.com/org/repo.git` |

### Question: Why Use Modules?

- **Reusability** — write once, use in multiple environments (dev/staging/prod)
- **Separation of concerns** — VPC logic stays in the VPC module, EC2 logic in the EC2 module
- **Cleaner root config** — root `main.tf` just calls modules with inputs
- **Easier maintenance** — changes to a module propagate everywhere it's used

---

## Section 03: Modularising Day-03 Code

Below is the modularised structure of the previous basic network infrastrcture creation code from previous Day

**File structure:**
```
Terraform-files/
├── main.tf           # calls vpc and ec2 modules
├── providers.tf      # terraform block + S3 backend + provider
├── variables.tf      # root input variables
├── outputs.tf        # root outputs from modules
├── terraform.tfvars  # variable values
└── modules/
    ├── vpc/
    │   ├── main.tf       # VPC data sources, subnets, route tables
    │   ├── variables.tf  # module input variables
    │   └── outputs.tf    # module outputs passed to root/ec2 module
    └── ec2/
        ├── main.tf       # EC2 instances, security groups, key pair
        ├── variables.tf  # module input variables
        └── outputs.tf    # module outputs passed to root
```

### Root main.tf — Calling Modules

The root `main.tf` only calls the two modules and passes inputs. All resource logic lives inside the modules:

```hcl
module "vpc" {
  source = "./modules/vpc"

  tags                = var.tags
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  subnet_az           = var.subnet_az
}

module "ec2" {
  source = "./modules/ec2"

  tags                 = var.tags
  public_subnet_id     = module.vpc.public_subnet_id
  private_subnet_id    = module.vpc.private_subnet_id
  vpc_id               = module.vpc.vpc_id
  sg_pub_ingress_cidrs = var.sg_pub_ingress_cidrs
}
```

### VPC Module

Fetches existing VPC, IGW, NAT Gateway and public route table using `data` blocks. Creates public/private subnets and a private route table:

```hcl
# modules/vpc/main.tf (key resources)

data "aws_vpc" "vpc" {
  tags = { Name = "Bootcamp-vpc-do-not-delete-vpc" }
}

resource "aws_subnet" "subnet-pub" {
  vpc_id                  = data.aws_vpc.vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.subnet_az
  map_public_ip_on_launch = true
  tags                    = merge(var.tags, { Name = "Chirag-Tank-pub-subnet" })
}

resource "aws_subnet" "subnet-priv" {
  vpc_id            = data.aws_vpc.vpc.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.subnet_az
  tags              = merge(var.tags, { Name = "Chirag-Tank-priv-subnet" })
}
```

Outputs from the VPC module are used by the EC2 module:

```hcl
# modules/vpc/outputs.tf
output "vpc_id"           { value = data.aws_vpc.vpc.id }
output "public_subnet_id" { value = aws_subnet.subnet-pub.id }
output "private_subnet_id"{ value = aws_subnet.subnet-priv.id }
```

### EC2 Module

Creates public/private EC2 instances and their security groups. The private SG only allows SSH from the public SG (bastion pattern):

```hcl
# modules/ec2/main.tf (key resources)

resource "aws_instance" "ec2-public" {
  ami                    = "ami-04eb7809a4ed8a62d"
  instance_type          = "t2.micro"
  subnet_id              = var.public_subnet_id
  key_name               = data.aws_key_pair.key.key_name
  vpc_security_group_ids = [aws_security_group.sg-pub.id]
  tags                   = merge(var.tags, { Name = "Chirag-Tank-Pub-EC2" })
}

resource "aws_instance" "ec2-private" {
  ami                    = "ami-04eb7809a4ed8a62d"
  instance_type          = "t2.micro"
  subnet_id              = var.private_subnet_id
  key_name               = data.aws_key_pair.key.key_name
  vpc_security_group_ids = [aws_security_group.sg-priv.id]
  tags                   = merge(var.tags, { Name = "Chirag-Tank-Priv-EC2" })
}
```

### Provisioning Commands

```bash
# Initialize — required after adding modules or changing backend
terraform init

terraform validate
terraform plan
terraform apply -auto-approve

# List all resources including module resources
terraform state list

# Reference of module resource in state
# module.<module_name>.<resource_type>.<resource_name>
# e.g:
module.vpc.aws_subnet.subnet-pub
module.ec2.aws_instance.ec2-public

# Move existing resource into a module (if refactoring existing state)
terraform state mv aws_instance.ec2-public module.ec2.aws_instance.ec2-public

# Destroy all resources
terraform destroy -auto-approve
```

---

## Extra: How Module Outputs Flow

```
modules/vpc/outputs.tf
        │
        ▼
root main.tf  →  module.vpc.public_subnet_id
        │
        ▼
modules/ec2/variables.tf  →  var.public_subnet_id
```

Data flows **upward** via `outputs.tf` and **downward** via `variables.tf`. Modules cannot directly reference each other — all cross-module communication goes through the root.

---

## Summary

Day 04 focused on two key Terraform concepts that make infrastructure code production-ready and maintainable.

- Configured an **S3 remote backend** to store Terraform state centrally with state locking enabled — essential for team collaboration and preventing state corruption
- Learned about **Terraform modules** — what they are, why they're used, and the different storage options (local, public registry, private registry, Git)
- Refactored the Day-03 flat Terraform code into two reusable modules — `vpc` and `ec2` — each with their own `main.tf`, `variables.tf`, and `outputs.tf`
- Understood how modules communicate through the root — outputs from the `vpc` module are passed as inputs to the `ec2` module via the root `main.tf`
- Learned `terraform state mv` for migrating existing resources into modules without destroying and recreating them
