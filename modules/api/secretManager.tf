resource "aws_secretsmanager_secret" "AIKey" {
  name        = "AIKey"
  description = "Open AI key"
}

resource "aws_secretsmanager_secret" "SerpAPI" {
  name        = "SerpAPI"
  description = "SerpAPI key"
}

resource "aws_secretsmanager_secret" "SlackSigningSecret" {
  name        = "SlackSigningSecret"
  description = "SlackSigningSecret key"
}

resource "aws_ssm_parameter" "slack_bot_oAuth_token" {
  name  = "slack_bot_oAuth_token"
  type  = "String"
  value = " "  # This tells Terraform to ignore changes to the value attribute

  lifecycle {
    ignore_changes = [
      value
    ]
  }
}
