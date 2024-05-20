variable "lambda_functions" {
  type = map(object({ extension = string, runtime = string}))
}

variable "dynamodb_access_policy_arn" {
  type = string
}

variable "accountID" {
  type = string
}
variable "myRegion" {
  type = string
}
variable "openAIKey" {
  type = string
  sensitive = true
}

variable "serpAPIKey" {
  type = string
  sensitive = true
}

variable "slackSigningSecret" {
  type = string
  sensitive = true
}
