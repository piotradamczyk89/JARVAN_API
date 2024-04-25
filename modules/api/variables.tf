variable "lambda_functions" {
  type = map(object({ extension = string, runtime = string, endpoint_path = string, http_method = string }))
}

variable "accountID" {
  type = string
}
variable "myregion" {
  type = string
}
variable "openAIKey" {
  type = string
  sensitive = true
}
