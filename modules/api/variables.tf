variable "lambda_functions" {
  type = map(object({ extension = string, runtime = string, desired_layers=set(string)}))
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
