resource "aws_api_gateway_rest_api" "own_api" {
  name = "own_api"
}

resource "aws_api_gateway_resource" "resource" {
  parent_id   = aws_api_gateway_rest_api.own_api.root_resource_id
  path_part   = "question"
  rest_api_id = aws_api_gateway_rest_api.own_api.id
}

resource "aws_api_gateway_method" "method" {
  authorization = "NONE"
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.resource.id
  rest_api_id   = aws_api_gateway_rest_api.own_api.id
}

resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.MyDemoAPI.id
  resource_id = aws_api_gateway_resource.MyDemoResource.id
  http_method = aws_api_gateway_method.MyDemoMethod.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration" "integration" {
  http_method             = aws_api_gateway_method.method.http_method
  resource_id             = aws_api_gateway_resource.resource.id
  rest_api_id             = aws_api_gateway_rest_api.own_api.id
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${var.myregion}:states:action/StartExecution"
  credentials             = aws_iam_role.api_gw_role.arn

  request_templates = {
    "application/json" = jsonencode({
      input            = "$util.escapeJavaScript($input.json('$'))",
      stateMachineArn  = "arn:aws:states:${var.myregion}:${var.accountID}:stateMachine:${aws_sfn_state_machine.stepFunction.name}"
    })
  }
}

resource "aws_api_gateway_integration_response" "MyDemoIntegrationResponse" {
  rest_api_id = aws_api_gateway_rest_api.MyDemoAPI.id
  resource_id = aws_api_gateway_resource.MyDemoResource.id
  http_method = aws_api_gateway_method.MyDemoMethod.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code

  # Transforms the backend JSON response to XML
  response_templates = {
    "application/xml" = <<EOF
#set($inputRoot = $input.path('$'))
<?xml version="1.0" encoding="UTF-8"?>
<message>
    $inputRoot.body
</message>
EOF
  }
}


resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.own_api.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.own_api.body))
  }
  depends_on = [aws_api_gateway_method.method, aws_api_gateway_integration.integration]
}

resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.own_api.id
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
  cloudwatch_role_arn = aws_iam_role.api_gw_role.arn

  depends_on = [
    aws_iam_role_policy.api_gateway_policy
  ]
}

resource "aws_cloudwatch_log_group" "api_gw_logs" {
  name              = "/aws/api-gateway/my-api-logs"
  retention_in_days = 7
}

resource "aws_iam_role" "api_gw_role" {
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


// TODO split this api gatway policy make it two
resource "aws_iam_role_policy" "api_gateway_policy" {
  name = "api_gw_logging_policy"
  role = aws_iam_role.api_gw_role.id

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
          "apigateway:*"
        ]
        Resource = ["*"]
      },
      {
        Action   = "states:StartExecution",
        Resource  = "arn:aws:states:${var.myregion}:${var.accountID}:stateMachine:${aws_sfn_state_machine.stepFunction.name}"
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

resource "aws_sfn_state_machine" "stepFunction" {
  name     = "stepFunction"
  role_arn = aws_iam_role.stepFunctionRole.arn
#  depends_on = [var.lambda_function_arns]

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
          "StringEquals": "answerQuestion",
          "Next": "answer"
        }
      ],
      "Default": "answer"
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
    "answer": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.lambda["answer"].arn}",
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
