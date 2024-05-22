locals {
  layer = ["langchain_layer", "custom_layer"]
}


//Lambda role

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "get_secret_policy" {
  statement {
    actions = [
      "secretsmanager:GetSecretValue",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "lambda_role" {
  name                = "lambda_role"
  assume_role_policy  = data.aws_iam_policy_document.assume_role.json
  managed_policy_arns = [var.dynamodb_access_policy_arn]

  inline_policy {
    name   = "GetSecretPolicy"
    policy = data.aws_iam_policy_document.get_secret_policy.json
  }
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
  role             = aws_iam_role.lambda_role.arn
  handler          = "${each.key}.handler"
  source_code_hash = data.archive_file.lambda[each.key].output_base64sha256
  runtime          = each.value.runtime
  timeout          = 60
  architectures = ["x86_64"]
  layers = contains(["python3.12", "python3.11", "python3.10", "python3.8", "python3.9"], each.value.runtime) ? [
    aws_lambda_layer_version.lambda_layer_langchain.arn, aws_lambda_layer_version.lambda_layer_custom.arn
  ] : []
  environment {
    variables = {
      my_aws_region = var.myRegion
    }
  }
}

// lambda layer
#data "archive_file" "layer_zip" {
#  for_each = local.layer
#  type        = "zip"
#  source_dir = "${path.module}/src/${each.value}/layer"
#  output_path = "${path.module}/src/${each.value}/python.zip"
#}

data "archive_file" "langchain" {
  type        = "zip"
  source_dir = "${path.module}/src/langchain_layer/layer"
  output_path = "${path.module}/src/langchain_layer/python.zip"
}

resource "aws_lambda_layer_version" "lambda_layer_langchain" {
  depends_on               = [data.archive_file.langchain]
  filename                 = data.archive_file.langchain.output_path
  source_code_hash         = filebase64sha256(data.archive_file.langchain.output_path)
  layer_name               = "langchain_layer"
  compatible_architectures = ["x86_64"]

  compatible_runtimes = ["python3.8", "python3.9", "python3.10", "python3.11", "python3.12"]
}

data "archive_file" "custom_layer" {
  type        = "zip"
  source_dir = "${path.module}/src/custom_layer/layer"
  output_path = "${path.module}/src/custom_layer/custom_layer.zip"
}
resource "aws_lambda_layer_version" "lambda_layer_custom" {
  depends_on               = [data.archive_file.custom_layer]
  filename                 = data.archive_file.custom_layer.output_path
  source_code_hash         = filebase64sha256(data.archive_file.custom_layer.output_path)
  layer_name               = "custom_methods"
  compatible_architectures = ["x86_64"]

  compatible_runtimes = ["python3.8", "python3.9", "python3.10", "python3.11", "python3.12"]
}


// cloud watch

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  for_each          = var.lambda_functions
  name              = "/aws/lambda/${aws_lambda_function.lambda[each.key].function_name}"
  retention_in_days = 14
}





