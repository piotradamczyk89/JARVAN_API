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

module "api" {
  source = "./modules/api"

  lambda_functions = {
    ai_question = {
      runtime ="python3.12"
      extension = "py"
      endpoint_path = "question"
      http_method = "POST"
    }
  }
  accountID = var.accountID
  myregion = var.myregion
  openAIKey = var.openAIKey
}

