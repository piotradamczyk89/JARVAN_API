resource "aws_api_gateway_rest_api" "jarvan" {
  name = "${terraform.workspace}-jarvan"
}

resource "aws_api_gateway_resource" "slack" {
  parent_id   = aws_api_gateway_rest_api.jarvan.root_resource_id
  path_part   = "slack"
  rest_api_id = aws_api_gateway_rest_api.jarvan.id
}

resource "aws_api_gateway_method" "slack_method" {
  authorization = "NONE"
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.slack.id
  rest_api_id   = aws_api_gateway_rest_api.jarvan.id
}

resource "aws_lambda_permission" "slack_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda["slack"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.myRegion}:${var.accountID}:${aws_api_gateway_rest_api.jarvan.id}/*/${aws_api_gateway_method.slack_method.http_method}${aws_api_gateway_resource.slack.path}"
}

resource "aws_api_gateway_integration" "slack_integration" {
  http_method             = aws_api_gateway_method.slack_method.http_method
  resource_id             = aws_api_gateway_resource.slack.id
  rest_api_id             = aws_api_gateway_rest_api.jarvan.id
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda["slack"].invoke_arn
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.jarvan.id
  lifecycle {
    create_before_destroy = true
  }
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_rest_api.jarvan.body, aws_api_gateway_resource.slack.id,
      aws_api_gateway_integration.slack_integration.id, aws_api_gateway_method.slack_method.id
    ]))
  }
  depends_on = [
    aws_api_gateway_resource.slack,
    aws_api_gateway_integration.slack_integration,
    aws_api_gateway_method.slack_method
  ]
}

resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.jarvan.id
  stage_name    = terraform.workspace
  depends_on    = [aws_cloudwatch_log_group.api_gw_logs]
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw_logs.arn
    format          = "{'requestId':'$context.requestId', 'ip': '$context.identity.sourceIp', 'caller':'$context.identity.caller', 'user':'$context.identity.user', 'requestTime':'$context.requestTime', 'httpMethod':'$context.httpMethod', 'resourcePath':'$context.resourcePath', 'status':'$context.status', 'protocol':'$context.protocol', 'responseLength':'$context.responseLength'}"
  }

  xray_tracing_enabled = true
}

#log

resource "aws_api_gateway_account" "api_account" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch_role.arn

  depends_on = [
    aws_iam_role_policy.api_gateway_cloudwatch_policy
  ]
}

resource "aws_cloudwatch_log_group" "api_gw_logs" {
  name              = "${terraform.workspace}-/aws/api-gateway/my-api-logs"
  retention_in_days = 7
}

resource "aws_iam_role" "api_gateway_cloudwatch_role" {
  name = "${terraform.workspace}-api_gateway_cloudwatch_role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      },
    ]
  })
}
resource "aws_iam_role_policy" "api_gateway_cloudwatch_policy" {
  name = "${terraform.workspace}-api_gateway_cloudwatch_policy"
  role = aws_iam_role.api_gateway_cloudwatch_role.id

  policy = jsonencode({
    Version   = "2012-10-17"
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



