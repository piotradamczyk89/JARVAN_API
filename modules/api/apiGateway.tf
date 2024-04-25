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
  for_each      = var.lambda_functions
  authorization = "NONE"
  http_method   = each.value.http_method
  resource_id   = aws_api_gateway_resource.resource[each.key].id
  rest_api_id   = aws_api_gateway_rest_api.own_api.id
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
  depends_on = [aws_api_gateway_method.methods,aws_api_gateway_integration.integration]
}

resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.own_api.id
  stage_name    = "dev"
}
