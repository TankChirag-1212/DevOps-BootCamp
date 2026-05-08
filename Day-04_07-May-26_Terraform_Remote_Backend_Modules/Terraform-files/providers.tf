terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  required_version = "~> 1.0"

  backend "s3" {
    bucket       = "chirag-tank-bootcamp-454143665149-ap-south-1-an"
    key          = "dev/vpc/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}
