output "endpoints_url" {
  value = "${aws_api_gateway_stage.stage.invoke_url}/question"
}
