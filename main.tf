terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.46.0"
    }
  }
}

provider "aws" {
  region = var.myregion
}

module "table" {
  source = "./modules/table"
}

module "api" {
  source = "./modules/api"

  lambda_functions = {
    intention = {
      runtime ="python3.12"
      extension = "py"
    },
    memory = {
      runtime ="python3.12"
      extension = "py"
    },
    answer = {
      runtime ="python3.12"
      extension = "py"
    },
  }
  accountID = var.accountID
  myregion = var.myregion
  openAIKey = var.openAIKey
  dynamodb_access_policy_arn = module.table.policy_arn

}

