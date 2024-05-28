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

