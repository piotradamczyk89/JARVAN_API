
resource "aws_ssm_parameter" "slack_bot_oAuth_token" {
  name  = "${terraform.workspace}-slack_bot_oAuth_token"
  type  = "String"
  value = " "   # go directly to AWS and paste needed value

  lifecycle {
    ignore_changes = [
      value
    ]
  }
}

resource "aws_ssm_parameter" "slack_signing_secret" {
  name  = "${terraform.workspace}-slack_signing_secret"
  type  = "String"
  value = " "   # go directly to AWS and paste needed value

  lifecycle {
    ignore_changes = [
      value
    ]
  }
}
