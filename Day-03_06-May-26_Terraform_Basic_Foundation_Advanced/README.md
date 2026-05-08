# Day 03 — Terraform Basics, Foundation & Advanced

## Section 01: Terraform Basics

### 1. Terraform Block

The `terraform` block is the most important block in any Terraform configuration. It defines:
- Which **Terraform CLI version** to use via `required_version`
- Which **providers** to download via `required_providers`

When `terraform init` is run, Terraform fetches all the providers listed here from their respective sources at the specified versions.

```hcl
terraform {
  required_version = "~> 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.44.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.5.0"
    }
  }
}
```

---

### 2. Provider Block

The `provider` block configures a specific provider declared in the `terraform` block. Since providers make the actual API calls to cloud platforms, they require authentication credentials.

```hcl
provider "aws" {
  region = "us-east-1"

  # Optional: for authentication using config/credential files
  shared_config_files      = ["/Users/tf_user/.aws/conf"]
  shared_credentials_files = ["/Users/tf_user/.aws/creds"]
  profile                  = "customprofile"
}

# Multiple providers using alias (e.g. multi-region)
provider "aws" {
  alias  = "west"
  region = "us-west-2"
}
```

To use an aliased provider in a resource block:
```hcl
resource "aws_instance" "example" {
  provider = aws.west
  ...
}
```

---

### 3. Writing Basic Terraform Code

**File structure:**
```
providers.tf
s3.tf
outputs.tf
```

- `providers.tf` — terraform block + provider block (AWS and random providers)
- `s3.tf` — resource blocks for S3 bucket using a random suffix for unique naming
- `outputs.tf` — output block to display the bucket name after creation

```hcl
# Random string for unique S3 bucket name
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# S3 Bucket
resource "aws_s3_bucket" "demo_bucket" {
  bucket = "chirag-devops-bootcamp-${random_string.suffix.result}"

  tags = {
    Name        = "DevOps Bootcamp Bucket"
    Owner       = "chirag.tank@einfochips.com"
    Environment = "Dev"
  }
}
```

```hcl
# outputs.tf
output "s3_bucket_name" {
  value = aws_s3_bucket.demo_bucket.bucket
}
```

---

### 4. Terraform Commands

Configured AWS credentials as temporary environment variables, then ran the following:

```bash
# Initialize — downloads provider plugins
terraform init

# Validate configuration syntax
terraform validate

# Preview changes
terraform plan

# Create resources
terraform apply -auto-approve

# Verify created bucket
aws s3 ls | grep chirag-devops-bootcamp

# Destroy all resources
terraform destroy -auto-approve
```

---

## Section 02: Terraform Foundation

Built a complete network infrastructure in AWS using Terraform — VPC, public/private subnets, route tables, security groups, and EC2 instances.

**File structure:**
```
providers.tf
vpc.tf
ec2.tf
variables.tf
terraform.tfvars
outputs.tf
```

### providers.tf

Includes the terraform block with the AWS provider and specific version:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  required_version = "~> 1.0"
}

provider "aws" {
  region = var.aws_region
}
```

### vpc.tf

Used `data` blocks to fetch existing VPC, IGW, NGW, and route table. Created public/private subnets with their respective route table associations:

```hcl
data "aws_vpc" "vpc" {
  tags = { Name = "Bootcamp-vpc-do-not-delete-vpc" }
}

data "aws_nat_gateway" "nat" {
  vpc_id = data.aws_vpc.vpc.id
}

data "aws_internet_gateway" "igw" {
  tags = { Name = "Bootcamp-vpc-do-not-delete-igw" }
}

data "aws_route_table" "rtb-pub" {
  route_table_id = "route-table-id"
}

# Public Subnet
resource "aws_subnet" "subnet-pub" {
  vpc_id                  = data.aws_vpc.vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.subnet_az
  map_public_ip_on_launch = true
  tags                    = merge(var.tags, { Name = "Chirag-Tank-pub-subnet" })
}

resource "aws_route_table_association" "rtb-pub-assoc" {
  subnet_id      = aws_subnet.subnet-pub.id
  route_table_id = data.aws_route_table.rtb-pub.id
}

# Private Subnet
resource "aws_subnet" "subnet-priv" {
  vpc_id            = data.aws_vpc.vpc.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.subnet_az
  tags              = merge(var.tags, { Name = "Chirag-Tank-priv-subnet" })
}

resource "aws_route_table" "rtb-priv" {
  vpc_id = data.aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = data.aws_nat_gateway.nat.id
  }

  tags = merge(var.tags, { Name = "Chirag-Tank-private-rt" })
}

resource "aws_route_table_association" "rtb-priv-assoc" {
  subnet_id      = aws_subnet.subnet-priv.id
  route_table_id = aws_route_table.rtb-priv.id
}
```

### ec2.tf

Created public and private EC2 instances with their respective security groups. The private SG only allows SSH from the public SG (bastion pattern):

```hcl
data "aws_key_pair" "key" {
  filter {
    name   = "tag:Owner"
    values = ["owner-name"]
  }
}

# Public EC2
resource "aws_instance" "ec2-public" {
  ami                    = "ami-04eb7809a4ed8a62d"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.subnet-pub.id
  key_name               = data.aws_key_pair.key.key_name
  vpc_security_group_ids = [aws_security_group.sg-pub.id]
  tags                   = merge(var.tags, { Name = "Chirag-Tank-Pub-EC2" })
}

# Private EC2
resource "aws_instance" "ec2-private" {
  ami                    = "ami-04eb7809a4ed8a62d"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.subnet-priv.id
  key_name               = data.aws_key_pair.key.key_name
  vpc_security_group_ids = [aws_security_group.sg-priv.id]
  tags                   = merge(var.tags, { Name = "Chirag-Tank-Priv-EC2" })
}

# Public Security Group — allows SSH from specified CIDRs
resource "aws_security_group" "sg-pub" {
  name        = "Chirag-Tank-Pub-SG"
  description = "Security group for public EC2 instance"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.sg-pub-ingress-cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "Chirag-Tank-Pub-SG" })
}

# Private Security Group — allows SSH only from public SG (bastion)
resource "aws_security_group" "sg-priv" {
  name        = "Chirag-Tank-Priv-SG"
  description = "Security group for private EC2 instance"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.sg-pub.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "Chirag-Tank-Priv-SG" })
}
```

### variables.tf

All values are parameterized using variables — best practice for reusable and environment-agnostic code:

```hcl
variable "aws_region" {
  description = "The AWS region to create resources in."
  type        = string
  default     = "ap-south-1"
}

variable "tags" {
  description = "A map of tags to apply to resources."
  type        = map(string)
  default     = { Owner = "owner-name" }
}

variable "public_subnet_cidr" {
  description = "The CIDR block for the public subnet."
  type        = string
}

variable "subnet_az" {
  description = "The availability zone for the subnets."
  type        = string
}

variable "private_subnet_cidr" {
  description = "The CIDR block for the private subnet."
  type        = string
}

variable "sg-pub-ingress-cidrs" {
  description = "A list of CIDR blocks allowed to access the public security group."
  type        = list(string)
}
```

Values for these variables are passed via `terraform.tfvars` — Terraform automatically picks this file up during `terraform plan`.

### outputs.tf

```hcl
output "vpc_id"                  { value = data.aws_vpc.vpc.id }
output "nat_gateway_id"          { value = data.aws_nat_gateway.nat.id }
output "internet_gateway_id"     { value = data.aws_internet_gateway.igw.id }
output "public_route_table_id"   { value = data.aws_route_table.rtb-pub.id }
output "private_route_table_id"  { value = aws_route_table.rtb-priv.id }
output "public_subnet_id"        { value = aws_subnet.subnet-pub.id }
output "private_subnet_id"       { value = aws_subnet.subnet-priv.id }
output "public_ec2_id"           { value = aws_instance.ec2-public.id }
output "private_ec2_id"          { value = aws_instance.ec2-private.id }
output "key_pair_name"           { value = data.aws_key_pair.key.key_name }
```

### Provisioning & State Commands

```bash
terraform init
terraform validate
terraform plan
terraform apply -auto-approve

# Inspect state in human-readable format
terraform show

# Re-display outputs from last apply
terraform output

# List all resources tracked in state
terraform state list

# Destroy all resources
terraform destroy -auto-approve
```

---

## Section 03: Terraform Variables — Precedence Order

Multiple ways to pass variable values in Terraform, listed from **lowest to highest precedence**:

| Priority | Method | Description |
|----------|--------|-------------|
| 1 (lowest) | `default` in `variables.tf` | Fallback value defined in the variable block |
| 2 | Environment variables | `export TF_VAR_variable_name=value` in shell |
| 3 | `terraform.tfvars` | Auto-loaded file with variable values |
| 4 | `*.auto.tfvars` | Auto-loaded, higher priority than `terraform.tfvars`. Can use custom names like `prod.auto.tfvars` |
| 5 (highest) | `-var` or `--var-file` flag | Passed directly during `terraform plan` or `terraform apply` |

> If both `-var` and `--var-file` are used together, whichever comes **last** in the command takes precedence.

```bash
terraform plan --var-file=prod.tfvars
terraform plan -var="aws_region=us-east-1"
```

---

## Extra: Terraform Plan for Destroy with Manual Approval

Useful for CI/CD pipelines (e.g. GitHub Actions) where you want a manual approval step before destroying resources:

```bash
# Generate a destroy plan and save it
terraform plan -destroy -out=destroy.tfplan

# Review the plan (converts binary to readable format)
terraform show destroy.tfplan

# Apply the destroy plan after approval
terraform apply destroy.tfplan
```

---

## Extra: Version Constraint Operators

| Operator | Meaning | Example |
|----------|---------|---------|
| `>=` | Greater than or equal, no upper limit | `>= 1.5.0` |
| `~>` | Locks minor version, allows patches only | `~> 1.5.0` means `>= 1.5.0, < 1.6.0` |
| `~>` | Locks major version, allows minor + patches | `~> 1.5` means `>= 1.5.0, < 2.0.0` |

Key difference — `>=` has no upper limit, `~>` is pessimistic and adds an upper limit based on the precision of the version specified.

---

## Extra: Argument References vs Attribute References

- **Argument references** — inputs passed into a resource block (e.g. `ami`, `instance_type`, `region`)
- **Attribute references** — metadata values exported by a resource after it is created, used to reference one resource in another (e.g. `aws_instance.web.id`, `aws_vpc.main.cidr_block`). Mostly used in `output` blocks and other resource/data blocks

---

## Extra: Terraform Advanced Concepts

**`locals` block** — similar to variables but used for computed/derived values within the configuration. Not exposed as external inputs. Useful for avoiding repetition and doing dynamic calculations:

```hcl
locals {
  name_prefix = "${var.project}-${var.environment}"
}
```

**`data` block** — reads existing resources from AWS without managing them. Useful for referencing pre-existing infrastructure like VPCs, key pairs, AMIs, etc. Data blocks are scoped to their module — use `output` blocks to pass fetched values to parent or sibling modules:

```hcl
data "aws_vpc" "existing" {
  tags = { Name = "my-vpc" }
}
```

---

## Summary

Day 03 covered Terraform from basics to advanced concepts with hands-on infrastructure provisioning.

- Learned the core Terraform blocks — `terraform`, `provider`, `resource`, `data`, `output`, `locals` — and how they work together
- Built a basic S3 bucket using the `random` provider for unique naming and practiced the full `init → validate → plan → apply → destroy` workflow
- Provisioned a complete AWS network setup — fetched existing VPC using `data` blocks, created public/private subnets, route tables, security groups, and EC2 instances with a bastion-style SSH access pattern
- Understood variable precedence order (default → env vars → tfvars → auto.tfvars → `-var` flag) and best practices for parameterizing Terraform code
- Learned advanced concepts: `locals` for computed values, `data` blocks for reading existing infrastructure, version constraint operators (`>=` vs `~>`), and safe destroy workflows using `terraform plan -destroy`
