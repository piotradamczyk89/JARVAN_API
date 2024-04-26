resource "aws_api_gateway_rest_api" "own_api" {
  name = "own_api"
}

resource "aws_api_gateway_resource" "resource" {
  for_each    = var.lambda_functions
  parent_id   = aws_api_gateway_rest_api.own_api.root_resource_id
  path_part   = each.value.endpoint_path
  rest_api_id = aws_api_gateway_rest_api.own_api.id
}

resource "aws_api_gateway_method" "methods" {
  for_each       = var.lambda_functions
  authorization  = "NONE"
  http_method    = each.value.http_method
  resource_id    = aws_api_gateway_resource.resource[each.key].id
  rest_api_id    = aws_api_gateway_rest_api.own_api.id
}

resource "aws_api_gateway_integration" "integration" {
  for_each                = var.lambda_functions
  http_method             = aws_api_gateway_method.methods[each.key].http_method
  resource_id             = aws_api_gateway_resource.resource[each.key].id
  rest_api_id             = aws_api_gateway_rest_api.own_api.id
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda[each.key].invoke_arn
}

resource "aws_lambda_permission" "apigw_lambda" {
  for_each      = var.lambda_functions
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda[each.key].function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "arn:aws:execute-api:${var.myregion}:${var.accountID}:${aws_api_gateway_rest_api.own_api.id}/*/${aws_api_gateway_method.methods[each.key].http_method}${aws_api_gateway_resource.resource[each.key].path}"

}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.own_api.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.own_api.body))
  }

  lifecycle {
    create_before_destroy = true
  }
  depends_on = [aws_api_gateway_method.methods, aws_api_gateway_integration.integration]
}

resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.own_api.id
  stage_name    = "dev"
  depends_on = [aws_cloudwatch_log_group.api_gw_logs]
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw_logs.arn
    format          = "{'requestId':'$context.requestId', 'ip': '$context.identity.sourceIp', 'caller':'$context.identity.caller', 'user':'$context.identity.user', 'requestTime':'$context.requestTime', 'httpMethod':'$context.httpMethod', 'resourcePath':'$context.resourcePath', 'status':'$context.status', 'protocol':'$context.protocol', 'responseLength':'$context.responseLength'}"
  }

  xray_tracing_enabled = true
}

#log

resource "aws_api_gateway_account" "api_account" {
  cloudwatch_role_arn = aws_iam_role.api_gw_logging_role.arn

  depends_on = [
    aws_iam_role_policy.api_gw_logging_policy
  ]
}
resource "aws_cloudwatch_log_group" "api_gw_logs" {
  name = "/aws/api-gateway/my-api-logs"
  retention_in_days = 7
}

resource "aws_iam_role" "api_gw_logging_role" {
  name = "api_gateway_cloudwatch_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "api_gw_logging_policy" {
  name = "api_gw_logging_policy"
  role = aws_iam_role.api_gw_logging_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
        ]
        Resource = ["*"]
      }
    ]
  })
}

