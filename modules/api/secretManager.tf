resource "aws_secretsmanager_secret" "AIKey" {
  name        = "AIKey"
  description = "Open AI key"
}

#resource "aws_secretsmanager_secret_version" "example" {
#  secret_id     = aws_secretsmanager_secret.AIKey.id
#  secret_string = jsonencode({ key = var.openAIKey })
#}

resource "aws_secretsmanager_secret" "SerpAPI" {
  name        = "SerpAPI"
  description = "SerpAPI key"
}

#resource "aws_secretsmanager_secret_version" "SerpAPIKey" {
#  secret_id     = aws_secretsmanager_secret.SerpAPI.id
#  secret_string = jsonencode({ key = var.serpAPIKey })
#}

resource "aws_secretsmanager_secret" "SlackSigningSecret" {
  name        = "SlackSigningSecret"
  description = "SlackSigningSecret key"
}

#resource "aws_secretsmanager_secret_version" "SlackSigningSecret" {
#  secret_id     = aws_secretsmanager_secret.SlackSigningSecret.id
#  secret_string = jsonencode({ key = var.slackSigningSecret })
#}
