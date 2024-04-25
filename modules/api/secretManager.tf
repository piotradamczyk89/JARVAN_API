resource "aws_secretsmanager_secret" "openAIKey" {
  name        = "openAIKey"
  description = "Open AI key"
}

resource "aws_secretsmanager_secret_version" "example" {
  secret_id     = aws_secretsmanager_secret.openAIKey.id
  secret_string = jsonencode({key = var.openAIKey})
}
