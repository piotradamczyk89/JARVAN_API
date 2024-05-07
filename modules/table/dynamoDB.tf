resource "aws_dynamodb_table" "conversation" {
  name           = "conversation"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "id"
  range_key = "timestamp"

  attribute {
    name = "id"
    type = "S"
  }
  attribute {
    name = "timestamp"
    type = "N"
  }

}

data "aws_iam_policy_document" "dynamodb-access" {
  statement {
    sid = "1"

    actions = [
      "dynamodb:GetShardIterator",
      "dynamodb:Scan",
      "dynamodb:Query",
      "dynamodb:DescribeStream",
      "dynamodb:GetRecords",
      "dynamodb:ListStreams",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:ConditionCheckItem",
      "dynamodb:PutItem",
      "dynamodb:DescribeTable",
      "dynamodb:DeleteItem",
      "dynamodb:GetItem",
      "dynamodb:Scan",
      "dynamodb:Query",
      "dynamodb:UpdateItem"
    ]

    resources = [aws_dynamodb_table.conversation.arn]
  }
}

resource "aws_iam_policy" "conversation_table_access" {
  name   = "conversation_table_access"
  policy = data.aws_iam_policy_document.dynamodb-access.json
}

output "policy_arn" {
  value = aws_iam_policy.conversation_table_access.arn
}
