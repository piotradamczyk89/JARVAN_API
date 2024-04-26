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
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "lambda_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

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

  layers = contains(["python3.12", "python3.11", "python3.10", "python3.8", "python3.9"], each.value.runtime) ? [
    aws_lambda_layer_version.lambda_layer.arn
  ] : []
}

// lambda layer

resource "aws_lambda_layer_version" "lambda_layer" {
  filename                 = "${path.module}/src/lambda_layer_dependencies/python.zip"
  source_code_hash         = filebase64sha256("${path.module}/src/lambda_layer_dependencies/python.zip")
  layer_name               = "langchain_openai_AND_langchain_core"
  compatible_architectures = ["x86_64"]

  compatible_runtimes = ["python3.8", "python3.9", "python3.10", "python3.11", "python3.12"]
}

// secret manager

resource "aws_secretsmanager_secret" "openAIKey" {
  name        = "openAIKey"
  description = "Open AI key"
}

resource "aws_secretsmanager_secret_version" "example" {
  secret_id     = aws_secretsmanager_secret.openAIKey.id
  secret_string = jsonencode({key = var.openAIKey})
}



