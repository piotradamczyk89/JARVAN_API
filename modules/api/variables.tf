variable "lambda_functions" {
  type = map(object({ extension = string, runtime = string, desired_layers=list(string), role= string, environment=set(string)}))
}

variable "accountID" {
  type = string
}
variable "myRegion" {
  type = string
}

variable "lambda_layers" {
  description = "Map of Lambda layers created"
  type        = map(object({
    id                         = string
    arn                  = string
    layer_name                 = string
    version                    = string
    compatible_architectures   = list(string)
    compatible_runtimes        = list(string)
  }))
}

variable "step_function_arn" {
  type        = string
}
