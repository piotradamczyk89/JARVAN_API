resource "aws_dynamodb_table" "tables" {
  for_each       = var.tables
  name           = each.key
  read_capacity  = 1
  write_capacity = 1
  hash_key       = each.value.hash_key.name
  range_key      = length(each.value.range_key) == 0 ? null : each.value.range_key[0].name

  attribute {
    name = each.value.hash_key.name
    type = each.value.hash_key.type
  }

  dynamic "attribute" {
    for_each = each.value.range_key
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
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
    resources = [for key, table in aws_dynamodb_table.tables : table.arn]
  }
}

resource "aws_iam_policy" "conversation_table_access" {
  name   = "conversation_table_access"
  policy = data.aws_iam_policy_document.dynamodb-access.json
}

