// lambda layer
locals {
  layers = toset(flatten(concat([for el in var.lambda_functions : el.desired_layers])))
  environments = {
    "my_aws_region" = var.myRegion
    "sqsUrl" = aws_sqs_queue.queue.url
  }
}

data "archive_file" "layer_zip" {
  for_each = local.layers
  type        = "zip"
  source_dir = "${path.module}/src/${each.value}/layer"
  output_path = "${path.module}/src/${each.value}/${each.value}.zip"
}

resource "aws_lambda_layer_version" "lambda_layer" {
  for_each = toset(local.layers)
  filename                 = data.archive_file.layer_zip[each.key].output_path
  source_code_hash         = filebase64sha256(data.archive_file.layer_zip[each.key].output_path)
  layer_name               = each.value
  compatible_architectures = ["x86_64"]

  compatible_runtimes = ["python3.8", "python3.9", "python3.10", "python3.11", "python3.12"]
}

// lambda

data "archive_file" "lambda" {
  for_each    = var.lambda_functions
  type        = "zip"
  source_file = "${path.module}/src/${each.key}.${each.value.extension}"
  output_path = "${path.module}/src/${each.key}.zip"
}

resource "aws_lambda_function" "lambda" {
  for_each         = var.lambda_functions
  filename         = "${path.module}/src/${each.key}.zip"
  function_name    = each.key
  role             = each.value.role
  handler          = "${each.key}.handler"
  source_code_hash = data.archive_file.lambda[each.key].output_base64sha256
  runtime          = each.value.runtime
  timeout          = 60
  architectures = ["x86_64"]

  layers = [for layer in aws_lambda_layer_version.lambda_layer : layer.arn if contains(each.value.desired_layers,layer.layer_name )]

  environment {
    variables = { for key, value in local.environments : key => value if contains(each.value.environment, key) }
  }
}

// cloud watch

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  for_each          = var.lambda_functions
  name              = "/aws/lambda/${aws_lambda_function.lambda[each.key].function_name}"
  retention_in_days = 3
}





