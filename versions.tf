terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.46.0"
    }
  }

  backend "s3" {
    bucket         = "jarvan-terraform-state"
    key            = "jarvan/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "jarvan-terraform-state"
    encrypt        = true
  }
}

provider "aws" {
  region = var.myRegion
}

