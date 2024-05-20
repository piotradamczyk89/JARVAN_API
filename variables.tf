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
