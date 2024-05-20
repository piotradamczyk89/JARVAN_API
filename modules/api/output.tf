locals {
  resources = [
    {
      path = "interaction"
      type = "POST"
    },
    {
      path = "slack"
      type = "POST"
    }
  ]
}


output "endpoints_url" {
  value = [for res in local.resources : "${res.type} ${aws_api_gateway_stage.stage.invoke_url}/${res.path}"]
}
