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
    proxy_intention = {
      runtime ="python3.12"
      extension = "py"
      desired_layers = ["langchain_layer", "custom_layer"]
      role = aws_iam_role.proxy_intention_lambda.arn
      environment = ["my_aws_region"]
    },
    memory = {
      runtime ="python3.12"
      extension = "py"
      desired_layers = []
      role = aws_iam_role.slack_lambda.arn
      environment = []
    },
    answerMemory = {
      runtime ="python3.12"
      extension = "py"
      desired_layers = []
      role = aws_iam_role.slack_lambda.arn
      environment = []
    },
    answerInternet = {
      runtime ="python3.12"
      extension = "py"
      desired_layers = []
      role = aws_iam_role.slack_lambda.arn
      environment = []
    },
    slack = {
      runtime ="python3.12"
      extension = "py"
      desired_layers = ["custom_layer"]
      role = aws_iam_role.slack_lambda.arn
      environment = ["sqsUrl","my_aws_region"]
    },
  }
  accountID = var.accountID
  myRegion = var.myRegion

}

