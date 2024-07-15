terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
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
        type = "S"
      }
      range_key = [
        {
          name = "userID"
          type = "S"
        }
      ]
    },
    memory = {
      hash_key = {
        name = "id"
        type = "S"
      }
    }
  }
}

module "lambda_utils" {
  source = "./modules/lambda_utils"
  conversation_table_access = module.table.table_policy_arn
  sqs_arn = module.api.sqs_arn
}

module "step_function" {
  source           = "./modules/stepFunction"
  lambda_layers        = module.lambda_utils.lambda_layers
  accountID = var.accountID
  myRegion  = var.myRegion

  lambda_functions = {
    memory = {
      runtime        = "python3.12"
      extension      = "py"
      desired_layers = ["custom_layer","langchain_layer","pinecone_layer"]
      role           = module.lambda_utils.memory_lambda_role
      environment    = ["MY_AWS_REGION"]
    },
    answerMemory = {
      runtime        = "python3.12"
      extension      = "py"
      desired_layers = ["custom_layer","langchain_layer","pinecone_layer"]
      role           = module.lambda_utils.answer_memory_lambda_role
      environment    = ["MY_AWS_REGION"]
    },
    answerInternet = {
      runtime        = "python3.12"
      extension      = "py"
      desired_layers = []
      role           = module.lambda_utils.slack_lambda_role
      environment    = []
    },
    no_intention_defined= {
      runtime        = "python3.12"
      extension      = "py"
      desired_layers = ["custom_layer"]
      role           = module.lambda_utils.no_intention_defined_lambda
      environment    = []
    }
  }

}

module "api" {
  source               = "./modules/api"
  lambda_layers        = module.lambda_utils.lambda_layers
  step_function_arn = module.step_function.step_function_arn
  accountID = var.accountID
  myRegion  = var.myRegion

  lambda_functions = {
    proxy_intention = {
      runtime        = "python3.12"
      extension      = "py"
      desired_layers = ["langchain_layer", "custom_layer"]
      role           = module.lambda_utils.proxy_intention_lambda_role
      environment    = ["MY_AWS_REGION","STEP_FUNCTION_ARN"]
    },
    slack = {
      runtime        = "python3.12"
      extension      = "py"
      desired_layers = ["custom_layer"]
      role           = module.lambda_utils.slack_lambda_role
      environment    = ["SQS_URL", "MY_AWS_REGION"]
    },
  }
}

