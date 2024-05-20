resource "aws_api_gateway_rest_api" "jarvan" {
  name = "jarvan"
}

resource "aws_api_gateway_resource" "interaction" {
  parent_id   = aws_api_gateway_rest_api.jarvan.root_resource_id
  path_part   = "interaction"
  rest_api_id = aws_api_gateway_rest_api.jarvan.id
}

resource "aws_api_gateway_method" "jarvan_interaction" {
  authorization = "NONE"
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.interaction.id
  rest_api_id   = aws_api_gateway_rest_api.jarvan.id
}


resource "aws_api_gateway_model" "responseModel" {
  rest_api_id  = aws_api_gateway_rest_api.jarvan.id
  name         = "responseModel"
  description  = "API response for JARVAN interaction"
  content_type = "application/json"
  schema       = jsonencode({
    "$schema"  = "https://json-schema.org/draft/2020-12/schema"
    title      = "api gateway response model"
    type       = "object"
    required   = ["reply"]
    properties = {
      reply = {
        type = "string"
      }
    }
  })
}

resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id     = aws_api_gateway_rest_api.jarvan.id
  resource_id     = aws_api_gateway_resource.interaction.id
  http_method     = aws_api_gateway_method.jarvan_interaction.http_method
  status_code     = "200"
  response_models = {
    "application/json" = aws_api_gateway_model.responseModel.name
  }
  response_parameters = {
    "method.response.header.Content-Type" = true
  }
}

resource "aws_api_gateway_integration" "integration" {
  http_method             = aws_api_gateway_method.jarvan_interaction.http_method
  resource_id             = aws_api_gateway_resource.interaction.id
  rest_api_id             = aws_api_gateway_rest_api.jarvan.id
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${var.myRegion}:states:action/StartSyncExecution"
  credentials             = aws_iam_role.api_gateway_step_function_role.arn

  request_templates = {
    "application/json" = jsonencode({
      input           = "$util.escapeJavaScript($input.json('$'))",
      stateMachineArn = "arn:aws:states:${var.myRegion}:${var.accountID}:stateMachine:${aws_sfn_state_machine.stepFunction.name}"
    })
  }
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

resource "aws_api_gateway_integration_response" "MyDemoIntegrationResponse" {
  rest_api_id = aws_api_gateway_rest_api.jarvan.id
  resource_id = aws_api_gateway_resource.interaction.id
  http_method = aws_api_gateway_method.jarvan_interaction.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code
  depends_on  = [aws_api_gateway_integration.integration]

  response_templates = {
    "application/json" = "$util.parseJson($input.json('$.output'))"
  }
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.jarvan.id
  lifecycle {
    create_before_destroy = true
  }
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_rest_api.jarvan.body, aws_api_gateway_resource.interaction.id, aws_api_gateway_resource.slack.id,
      aws_api_gateway_method.jarvan_interaction.id, aws_api_gateway_integration.integration.id,
      aws_api_gateway_integration.slack_integration.id, aws_api_gateway_method.slack_method.id
    ]))
  }
  depends_on = [
    aws_api_gateway_resource.interaction, aws_api_gateway_resource.slack,
    aws_api_gateway_method.jarvan_interaction, aws_api_gateway_integration.integration,
    aws_api_gateway_integration.slack_integration, aws_api_gateway_method.slack_method
  ]
}

resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.jarvan.id
  stage_name    = "dev"
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
  name              = "/aws/api-gateway/my-api-logs"
  retention_in_days = 7
}

resource "aws_iam_role" "api_gateway_cloudwatch_role" {
  name = "api_gateway_cloudwatch_role"

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
  name = "api_gateway_cloudwatch_policy"
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
resource "aws_iam_role" "api_gateway_step_function_role" {
  name = "api_gateway_step_function_role"

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

resource "aws_iam_role_policy" "api_gateway_step_function_policy" {
  name = "api_gateway_step_function_policy"
  role = aws_iam_role.api_gateway_step_function_role.id

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action   = "states:StartSyncExecution",
        Resource = "arn:aws:states:${var.myRegion}:${var.accountID}:stateMachine:${aws_sfn_state_machine.stepFunction.name}"
        Effect   = "Allow"
      }
    ]
  })
}


//step function

resource "aws_iam_role" "stepFunctionRole" {
  name = "example-sfn-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "lambda_invoke_policy" {
  name = "LambdaInvokePolicy"
  role = aws_iam_role.stepFunctionRole.id

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = ["*"]
      },
    ]
  })
}


//TODO create .tftpl file to move stepfunction definition to the template file follow: https://awstip.com/invoke-your-step-function-with-api-gateway-8a9c060026ce
resource "aws_sfn_state_machine" "stepFunction" {
  name     = "stepFunction"
  role_arn = aws_iam_role.stepFunctionRole.arn
  type     = "EXPRESS"

  definition = <<EOF
{
"Comment": "A description of my state machine",
  "StartAt": "Intention",
  "States": {
    "Intention": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.lambda["intention"].arn}",
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException"
          ],
          "IntervalSeconds": 1,
          "MaxAttempts": 3,
          "BackoffRate": 2
        }
      ],
      "Next": "Choice"
    },
    "Choice": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.name",
          "StringEquals": "saveMemory",
          "Next": "memory"
        },
        {
          "Variable": "$.name",
          "StringEquals": "answerMemoryQuestion",
          "Next": "answerMemory"
        },
        {
          "Variable": "$.name",
          "StringEquals": "answerInternetQuestion",
          "Next": "answerInternet"
        }
      ],
      "Default": "answerInternet"
    },
    "memory": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.lambda["memory"].arn}",
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException"
          ],
          "IntervalSeconds": 1,
          "MaxAttempts": 3,
          "BackoffRate": 2
        }
      ],
      "End": true
    },
    "answerMemory": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.lambda["answerMemory"].arn}",
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException"
          ],
          "IntervalSeconds": 1,
          "MaxAttempts": 3,
          "BackoffRate": 2
        }
      ],
      "End": true
    },
    "answerInternet": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.lambda["answerInternet"].arn}",
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException"
          ],
          "IntervalSeconds": 1,
          "MaxAttempts": 3,
          "BackoffRate": 2
        }
      ],
      "End": true
    }
  }
}
EOF
}
