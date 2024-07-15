resource "aws_iam_role" "stepFunctionRole" {
  name = "sfn-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
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
      {
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups",
        ],
        Effect   = "Allow",
        Resource = ["*"],
      }
    ]
  })
}


resource "aws_cloudwatch_log_group" "step_function_log_group" {
  name              = "step-functions-log-group"
  retention_in_days = 7
}

//TODO create .tftpl file to move stepfunction definition to the template file follow: https://awstip.com/invoke-your-step-function-with-api-gateway-8a9c060026ce
resource "aws_sfn_state_machine" "stepFunction" {
  name     = "stepFunction"
  role_arn = aws_iam_role.stepFunctionRole.arn
  type     = "STANDARD"
  logging_configuration {
    level = "ALL"
    include_execution_data = true
    log_destination = "${aws_cloudwatch_log_group.step_function_log_group.arn}:*"
  }

  definition = <<EOF
{
"Comment": "A description of my state machine",
  "StartAt": "Choice",
  "States": {
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
        },
        {
          "Variable": "$.name",
          "StringEquals": "dontKnowHowToRespondToThat",
          "Next": "dontKnow"
        }
      ],
      "Default": "memory"
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
    "dontKnow": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.lambda["no_intention_defined"].arn}",
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



