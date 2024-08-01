// lambda layer
locals {
  layers = toset(flatten(concat([for el in var.lambda_functions : el.desired_layers])))
  environments = {
    "MY_AWS_REGION" = var.myRegion,
    "WORKSPACE" = terraform.workspace
  }
}

// lambda

data "archive_file" "lambda" {
  for_each    = var.lambda_functions
  type        = "zip"
  source_file = "${path.module}/src/${each.key}.${each.value.extension}"
  output_path = "${path.module}/src/${each.key}.zip"
}


#TODO definition of memory size should be moved to main

resource "aws_lambda_function" "lambda" {
  for_each         = var.lambda_functions
  filename         = "${path.module}/src/${each.key}.zip"
  function_name    = "${terraform.workspace}-${each.key}"
  role             = each.value.role
  handler          = "${each.key}.handler"
  source_code_hash = data.archive_file.lambda[each.key].output_base64sha256
  runtime          = each.value.runtime
  timeout          = 60
  architectures = ["x86_64"]
  memory_size = 256
  layers = [for layer in var.lambda_layers : layer.arn if contains(each.value.desired_layers,layer.layer_name )]

  environment {
    variables = { for key, value in local.environments : key => value if contains(each.value.environment, key) }
  }
}








