variable "lambda_functions" {
  type = map(object({ extension = string, runtime = string, desired_layers=list(string), role= string, environment=set(string)}))
}

variable "accountID" {
  type = string
}
variable "myRegion" {
  type = string
}
