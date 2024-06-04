resource "aws_secretsmanager_secret" "AIKey" {
  name        = "AIKey"
  description = "Open AI key"
}

resource "aws_secretsmanager_secret" "SlackSigningSecret" {
  name        = "SlackSigningSecret"
  description = "SlackSigningSecret key"
}

resource "aws_secretsmanager_secret" "PineConeApiKey" {
  name        = "PineConeApiKey"
  description = "PineConeApiKey key"
}

resource "aws_secretsmanager_secret_version" "PineConeApiKey" {
  secret_id     = aws_secretsmanager_secret.PineConeApiKey.id
  secret_string = jsonencode({ key = " " })
  lifecycle {
    ignore_changes = [
      secret_string
    ]
  }
}

resource "aws_ssm_parameter" "slack_bot_oAuth_token" {
  name  = "slack_bot_oAuth_token"
  type  = "String"
  value = " "   # go directly to AWS and paste needed value

  lifecycle {
    ignore_changes = [
      value
    ]
  }
}
