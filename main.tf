terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.46.0"
    }
  }
}

provider "aws" {
  region = var.myRegion
}

module "table" {
  source = "./modules/table"
  tables = {
    conversation = {
      hash_key = {
        name = "timestamp"
        type = "N"
      }
      range_key = [
        {
          name = "userID"
          type = "S"
        }
      ]
    }
  }
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
    answerMemory = {
      runtime ="python3.12"
      extension = "py"
    },
    answerInternet = {
      runtime ="python3.12"
      extension = "py"
    },
    slack = {
      runtime ="python3.12"
      extension = "py"
    },
  }
  accountID = var.accountID
  myRegion = var.myRegion
  dynamodb_access_policy_arn = module.table.table_policy_arn

}

