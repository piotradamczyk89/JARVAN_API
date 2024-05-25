resource "aws_sqs_queue" "queue" {
  name = "queue.fifo"
  fifo_queue = true
  content_based_deduplication = true
  receive_wait_time_seconds = 10
  visibility_timeout_seconds = 60
}


resource "aws_lambda_event_source_mapping" "lambda_trigger" {
  event_source_arn = aws_sqs_queue.queue.arn
  function_name    = aws_lambda_function.lambda["proxy_intention"].arn
  batch_size = 1
}
