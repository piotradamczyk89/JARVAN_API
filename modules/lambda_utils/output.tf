output "lambda_layers" {
  value = aws_lambda_layer_version.lambda_layer
}

output "slack_lambda_role" {
  value = aws_iam_role.slack_lambda.arn
}

output "proxy_intention_lambda_role" {
  value = aws_iam_role.proxy_intention_lambda.arn
}

output "memory_lambda_role" {
  value = aws_iam_role.memory_lambda.arn
}
output "answer_memory_lambda_role" {
  value = aws_iam_role.answer_memory_lambda.arn
}
