data "aws_iam_policy_document" "lambda_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

#policy

data "aws_iam_policy_document" "logs_policy_doc" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "secretmanager_policy_doc" {
  statement {
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "send_message_policy_doc" {
  statement {
    actions = [
      "sqs:SendMessage"
    ]
    resources = [var.sqs_arn]
  }
}

data "aws_iam_policy_document" "receive_message_policy_doc" {
  statement {
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [var.sqs_arn]
  }
}

data "aws_iam_policy_document" "start_step_function_policy_doc" {
  statement {
    actions = [
      "states:StartExecution"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "kms_decrypt_policy_doc" {
  statement {
    actions = [
      "kms:Decrypt"
    ]
    resources = ["*"]
  }
}





resource "aws_iam_policy" "logs_policy" {
  policy = data.aws_iam_policy_document.logs_policy_doc.json
}
resource "aws_iam_policy" "secretmanager_policy" {
  policy = data.aws_iam_policy_document.secretmanager_policy_doc.json
}
resource "aws_iam_policy" "send_message_policy" {
  policy = data.aws_iam_policy_document.send_message_policy_doc.json
}
resource "aws_iam_policy" "receive_message_policy" {
  policy = data.aws_iam_policy_document.receive_message_policy_doc.json
}
resource "aws_iam_policy" "start_step_function_policy" {
  policy = data.aws_iam_policy_document.start_step_function_policy_doc.json
}
resource "aws_iam_policy" "kms_decrypt_policy" {
  policy = data.aws_iam_policy_document.kms_decrypt_policy_doc.json
}





resource "aws_iam_role" "slack_lambda" {
  name                = "slack_lambda"
  assume_role_policy  = data.aws_iam_policy_document.lambda_role.json
  managed_policy_arns = [
    var.conversation_table_access,
    aws_iam_policy.logs_policy.arn,
    aws_iam_policy.secretmanager_policy.arn,
    aws_iam_policy.send_message_policy.arn,
    aws_iam_policy.kms_decrypt_policy.arn
  ]
}
resource "aws_iam_role" "proxy_intention_lambda" {
  name                = "proxy_intention_lambda"
  assume_role_policy  = data.aws_iam_policy_document.lambda_role.json
  managed_policy_arns = [
    aws_iam_policy.logs_policy.arn,
    aws_iam_policy.secretmanager_policy.arn,
    aws_iam_policy.receive_message_policy.arn,
    aws_iam_policy.start_step_function_policy.arn,
    aws_iam_policy.kms_decrypt_policy.arn
  ]
}

