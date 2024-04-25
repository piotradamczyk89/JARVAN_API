output "endpoints_url" {
  value = {for key, name in var.lambda_functions : key => "${aws_api_gateway_stage.stage.invoke_url}/${name.endpoint_path}"}
}
