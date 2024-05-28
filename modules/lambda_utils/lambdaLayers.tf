locals {
  layers = ["langchain_layer", "custom_layer"]
}

data "archive_file" "layer_zip" {
  for_each = toset(local.layers)
  type        = "zip"
  source_dir = "${path.module}/${each.value}/layer"
  output_path = "${path.module}/${each.value}/${each.value}.zip"
}

resource "aws_lambda_layer_version" "lambda_layer" {
  for_each = toset(local.layers)
  filename                 = data.archive_file.layer_zip[each.key].output_path
  source_code_hash         = filebase64sha256(data.archive_file.layer_zip[each.key].output_path)
  layer_name               = each.value
  compatible_architectures = ["x86_64"]

  compatible_runtimes = ["python3.8", "python3.9", "python3.10", "python3.11", "python3.12"]
}
