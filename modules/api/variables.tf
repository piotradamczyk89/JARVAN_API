variable "lambda_functions" {
  type = map(object({ extension = string, runtime = string}))
}

variable "dynamodb_access_policy_arn" {
  type = string
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
